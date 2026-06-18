import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_data.dart';
import '../services/firebase_bus_service.dart';
import '../services/open_route_service.dart';
import '../widgets/bus_marker.dart';
import '../utils/map_utils.dart';

class PassengerPickupStatusPage extends StatefulWidget {
  final String busId;
  final String pickupId;
  final String passengerId;
  final LatLng pickupLocation;
  final BusData initialBusData;
  final double? initialDistance;

  const PassengerPickupStatusPage({
    super.key,
    required this.busId,
    required this.pickupId,
    required this.passengerId,
    required this.pickupLocation,
    required this.initialBusData,
    this.initialDistance,
  });

  @override
  State<PassengerPickupStatusPage> createState() => _PassengerPickupStatusPageState();
}

class _PassengerPickupStatusPageState extends State<PassengerPickupStatusPage> {
  late BusData _currentBusData;
  RouteEstimate? _routeEstimate;
  List<LatLng> _routePoints = [];
  bool _isFetchingEstimate = false;
  String? _estimateMessage;
  bool _isApproximateEstimate = false;
  double? _initialDistance;
  Map<String, BusData> _allBuses = {};
  final Map<String, double> _busBearings = {};

  final MapController _mapController = MapController();
  final FirebaseBusService _busService = FirebaseBusService();
  final OpenRouteService _openRouteService = OpenRouteService();
  StreamSubscription<Map<String, BusData>>? _busSubscription;
  Timer? _etaDebounceTimer;
  Timer? _timeRefreshTimer;

  bool _isCancelling = false;
  bool _mapReady = false;
  bool _showNormalBanner = false;
  Timer? _normalBannerTimer;
  String? _busDirection;

  @override
  void initState() {
    super.initState();
    _currentBusData = widget.initialBusData;
    _initialDistance = widget.initialDistance;
    _allBuses = {widget.busId: widget.initialBusData};

    _listenToBusUpdates();
    _fetchRouteEstimate(immediate: true);

    final initialDir = widget.initialBusData.direction;
    if (initialDir != null && initialDir != 'Unknown') {
      _busDirection = initialDir;
    } else {
      _fetchBusDirection();
    }

    // Refresh UI every 10 seconds for the "last updated" timestamp
    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
    _etaDebounceTimer?.cancel();
    _timeRefreshTimer?.cancel();
    _normalBannerTimer?.cancel();
    super.dispose();
  }

  void _fetchBusDirection() {
    _busService.getBusDirection(widget.busId).then((direction) {
      if (mounted && direction != null) {
        setState(() {
          _busDirection = direction;
        });
      }
    });
  }

  void _listenToBusUpdates() {
    _busSubscription = _busService.listenToBusLocations().listen(
      (updatedBusMap) {
        if (!mounted) return;

        for (final entry in updatedBusMap.entries) {
          final busId = entry.key;
          final newBus = entry.value;
          final oldBus = _allBuses[busId];
          if (oldBus != null && oldBus.location != newBus.location) {
            _busBearings[busId] = MapUtils.calculateBearing(oldBus.location, newBus.location);
          }
        }

        final bus = updatedBusMap[widget.busId];
        if (bus == null) {
          // Bus data is temporarily not emitting or driver stopped app
          return;
        }

        final prevLocation = _currentBusData.location;
        final newLocation = bus.location;
        final wasEmergency = _currentBusData.emergency;
        final isEmergency = bus.emergency;

        // Transition from emergency (true) to normal (false)
        if (wasEmergency && !isEmergency) {
          _normalBannerTimer?.cancel();
          setState(() {
            _showNormalBanner = true;
          });
          _normalBannerTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _showNormalBanner = false;
              });
            }
          });
        }

        setState(() {
          _currentBusData = bus;
          _allBuses = updatedBusMap;
        });

        // If the bus moves by >= 12 meters, recalculate ETA
        final movedMeters = const Distance().as(
          LengthUnit.Meter,
          prevLocation,
          newLocation,
        );

        if (movedMeters >= 12.0) {
          _scheduleEstimateRefresh();
        }
      },
      onError: (error) {
        debugPrint('Error updating bus coordinates: $error');
      },
    );
  }

  void _scheduleEstimateRefresh() {
    _etaDebounceTimer?.cancel();
    _etaDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _fetchRouteEstimate();
    });
  }

  Future<void> _fetchRouteEstimate({bool immediate = false}) async {
    if (!mounted) return;

    setState(() {
      _isFetchingEstimate = true;
    });

    try {
      final estimate = await _openRouteService.fetchEtaAndDistance(
        from: widget.pickupLocation,
        to: _currentBusData.location,
      );

      if (!mounted) return;

      setState(() {
        final isFirstFetch = _routeEstimate == null;
        _routeEstimate = estimate;
        _routePoints = estimate.routePoints;
        _isApproximateEstimate = false;
        _estimateMessage = null;
        _isFetchingEstimate = false;

        // Keep track of the initial booking distance
        if ((isFirstFetch && _initialDistance == null) || estimate.distanceKm > _initialDistance!) {
          _initialDistance = estimate.distanceKm;
          _saveInitialDistanceToPrefs(estimate.distanceKm);
        }
      });

      _fitMapToPoints();
    } catch (e) {
      if (!mounted) return;

      final fallbackEstimate = _buildFallbackEstimate(
        from: widget.pickupLocation,
        to: _currentBusData.location,
      );

      setState(() {
        final isFirstFetch = _routeEstimate == null;
        _routeEstimate = fallbackEstimate;
        _routePoints = fallbackEstimate.routePoints;
        _isApproximateEstimate = true;
        _estimateMessage = 'Traffic ETA unavailable. Using approximation.';
        _isFetchingEstimate = false;

        if ((isFirstFetch && _initialDistance == null) || fallbackEstimate.distanceKm > _initialDistance!) {
          _initialDistance = fallbackEstimate.distanceKm;
          _saveInitialDistanceToPrefs(fallbackEstimate.distanceKm);
        }
      });

      _fitMapToPoints();
      debugPrint('OSRM Error, using fallback estimates: $e');
    }
  }

  RouteEstimate _buildFallbackEstimate({
    required LatLng from,
    required LatLng to,
  }) {
    const averageCitySpeedKmPerHour = 28.0;
    final straightLineKm = const Distance().as(LengthUnit.Kilometer, from, to);
    final roadAdjustedDistanceKm = straightLineKm * 1.3;
    final minutes = (roadAdjustedDistanceKm / averageCitySpeedKmPerHour) * 60;

    return RouteEstimate(
      distanceKm: roadAdjustedDistanceKm,
      durationMinutes: minutes.clamp(1, 240).toDouble(),
      routePoints: [from, to],
    );
  }

  LatLngBounds _getBounds(LatLng p1, LatLng p2) {
    double minLat = p1.latitude < p2.latitude ? p1.latitude : p2.latitude;
    double maxLat = p1.latitude > p2.latitude ? p1.latitude : p2.latitude;
    double minLng = p1.longitude < p2.longitude ? p1.longitude : p2.longitude;
    double maxLng = p1.longitude > p2.longitude ? p1.longitude : p2.longitude;

    // Add padding to bounds
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final latPadding = latSpan == 0 ? 0.002 : latSpan * 0.2;
    final lngPadding = lngSpan == 0 ? 0.002 : lngSpan * 0.2;

    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  void _fitMapToPoints() {
    if (!_mapReady || !mounted) return;
    try {
      final bounds = _getBounds(widget.pickupLocation, _currentBusData.location);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 50),
        ),
      );
    } catch (e) {
      debugPrint('Failed to fit camera bounds: $e');
    }
  }

  double get _progressPercentage {
    if (_initialDistance == null) return 0.0;
    final initial = _initialDistance!;
    final current = _routeEstimate?.distanceKm ?? initial;
    if (initial <= 0.0) return 1.0;
    final progress = 1.0 - (current / initial);
    return progress.clamp(0.0, 1.0);
  }

  String _formatLastUpdated() {
    final updatedAt = _currentBusData.updatedAt;
    if (updatedAt == null) return 'just now';
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  Future<void> _cancelPickup() async {
    if (_isCancelling) return;

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Pick Up?'),
        content: const Text('Are you sure you want to cancel your pickup request for this bus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await _busService.cancelPickupRequest(
        pickId: widget.pickupId,
        busId: widget.busId,
        passengerId: widget.passengerId,
      );

      if (mounted) {
        Navigator.pop(context, true); // Pop back to map indicating cancellation
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final etaStr = _routeEstimate != null
        ? _routeEstimate!.durationMinutes.toStringAsFixed(0)
        : '...';
    final distanceStr = _routeEstimate != null
        ? _routeEstimate!.distanceKm.toStringAsFixed(2)
        : '...';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Tracking your bus',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFEC205),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Column(
        children: [
          // Mini map widget
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.pickupLocation,
                    initialZoom: 15,
                    onMapReady: () {
                      _mapReady = true;
                      _fitMapToPoints();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&key=AIzaSyAO5ec1tqP3KkvuVuhs2cm25-geO9PZQA8',
                      userAgentPackageName: 'com.example.bus_tracker',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Passenger marker
                        Marker(
                          point: widget.pickupLocation,
                          width: 35,
                          height: 35,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.blue, width: 2),
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                              size: 22,
                            ),
                          ),
                        ),
                        // Bus markers
                        ..._allBuses.entries.map((entry) {
                          final isSelected = entry.key == widget.busId;
                          return BusMarker.create(
                            entry.key,
                            entry.value,
                            bearing: _busBearings[entry.key],
                            isHighlighted: isSelected,
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton(
                    heroTag: 'fitCameraBtn',
                    mini: true,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00458C),
                    onPressed: _fitMapToPoints,
                    child: const Icon(Icons.center_focus_strong),
                  ),
                ),
              ],
            ),
          ),
          // Details Card Section
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Tracking status badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const PulsingDot(),
                            const SizedBox(width: 8),
                            const Text(
                              'LIVE TRACKING',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        if (_isFetchingEstimate)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    if (_currentBusData.emergency) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Emergency Reported',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Expect delays',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_showNormalBanner) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Back to Normal',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'The bus is operating normally.',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // ETA and distance layout
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (_isApproximateEstimate)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 28,
                            ),
                          ),
                        Text(
                          etaStr,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00458C),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'mins',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$distanceStr km',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'distance away',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_estimateMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _estimateMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Route/Journey line progress animation
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_bus,
                          color: Color(0xFF00458C),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              AnimatedAlign(
                                alignment: Alignment(_progressPercentage * 2.0 - 1.0, 0.0),
                                duration: const Duration(seconds: 1),
                                curve: Curves.easeInOut,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: _currentBusData.occupancyColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _currentBusData.occupancyColor.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Bus operational information details
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _currentBusData.occupancyColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.directions_bus_filled,
                              color: _currentBusData.occupancyColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final String directionDisplay;
                                    final currentDir = _busDirection ?? _currentBusData.direction;
                                    final initialDir = widget.initialBusData.direction;
                                    if (currentDir != null && currentDir != 'Unknown') {
                                      directionDisplay = currentDir;
                                    } else if (initialDir != null && initialDir != 'Unknown') {
                                      directionDisplay = initialDir;
                                    } else {
                                      directionDisplay = _currentBusData.route != 'Unknown'
                                          ? _currentBusData.route
                                          : widget.initialBusData.route;
                                    }
                                    return Text(
                                      'Bus ${widget.busId} • $directionDisplay',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _currentBusData.occupancyColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${_currentBusData.occupancyLevel} Crowd',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Speed: ${_currentBusData.speed?.toStringAsFixed(1) ?? '0.0'} km/h',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatLastUpdated(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                'last updated',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Cancel Pick Up Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isCancelling ? null : _cancelPickup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          side: BorderSide(color: Colors.red.shade200, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                ),
                              )
                            : const Icon(Icons.cancel_outlined, size: 20),
                        label: Text(
                          _isCancelling ? 'Cancelling...' : 'Cancel Pick Up',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInitialDistanceToPrefs(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('picked_initial_distance', value);
    } catch (e) {
      debugPrint('Error saving initial distance: $e');
    }
  }
}

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
