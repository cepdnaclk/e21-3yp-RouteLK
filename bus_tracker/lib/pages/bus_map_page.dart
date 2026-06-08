import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_data.dart';
import '../services/location_service.dart';
import '../services/firebase_bus_service.dart';
import '../services/open_route_service.dart';
import '../widgets/bus_marker.dart';
import '../utils/map_utils.dart';

enum BusMapMode { passenger, driver }

/// Main page displaying the bus tracking map
class BusMapPage extends StatefulWidget {
  /// Optionally start the map with a specific route selected.
  final String? initialRoute;
  final BusMapMode mode;
  final String? driverBusId;
  final int? passengerId;

  const BusMapPage({
    super.key,
    this.initialRoute,
    this.mode = BusMapMode.passenger,
    this.driverBusId,
    this.passengerId,
  });

  @override
  State<BusMapPage> createState() => _BusMapPageState();
}

class _BusMapPageState extends State<BusMapPage> {
  static const double _minBusMovementForApiMeters = 10.0;

  LatLng? myCurrentLocation;
  LatLng _startLocation = LocationService.defaultLocation;
  LatLng? _pendingStartLocation;
  LatLng? _lastApiBusLocation;
  Map<String, BusData> busData = {};
  final MapController mapController = MapController();
  final FirebaseBusService _busService = FirebaseBusService();
  final OpenRouteService _openRouteService = OpenRouteService();

  StreamSubscription<Map<String, BusData>>? _busSubscription;
  StreamSubscription<LatLng>? _userLocationSubscription;
  StreamSubscription<Map<String, LatLng>>? _pickupSubscription;
  String? _pickupSubscriptionBusId;
  Timer? _etaDebounceTimer;

  String? _selectedBusId;
  RouteEstimate? _selectedBusEstimate;
  List<LatLng> _selectedBusRoutePoints = [];
  bool _isFetchingEstimate = false;
  String? _estimateMessage;
  bool _isApproximateEstimate = false;
  int _etaRequestVersion = 0;
  bool _hasConfirmedPickupLocation = false;
  bool _hasAdjustedInitialMapView = false;
  bool _isMapReady = false;
  bool _hasFocusedUserOnLoad = false;

  // Route filtering
  String? selectedRoute;
  List<String> availableRoutes = [];
  Map<String, BusData> _routeBusData = {};
  bool _isLoadingRoutes = true;
  bool _showRouteSelector = false;
  int _routeRequestVersion = 0;
  final TextEditingController _routeSearchController = TextEditingController();
  String _routeSearchQuery = '';

  // Picked bus message state
  bool _showPickedBusMessage = false;
  String? _pickedBusId;
  String? _pickedPickupId;
  String? _pickedBusMessageText;
  bool _pickedBusMessageIsCancellation = false;
  Timer? _pickedBusMessageTimer;
  Map<String, LatLng> _pickupLocations = {};
  bool _isSavingPickupRequest = false;

  @override
  void initState() {
    super.initState();
    // respect any initialRoute passed from previous screen
    selectedRoute = widget.initialRoute;
    if (widget.mode == BusMapMode.driver && widget.driverBusId != null) {
      _selectedBusId = widget.driverBusId;
      _syncPickupSubscription();
    }
    _initializeLocation();
    _loadAvailableRoutes();
    _listenToUserLocation();
    _listenToBusLocations();
    _loadBusesForSelectedRoute(selectedRoute);
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
    _userLocationSubscription?.cancel();
    _pickupSubscription?.cancel();
    _etaDebounceTimer?.cancel();
    _pickedBusMessageTimer?.cancel();
    _routeSearchController.dispose();
    super.dispose();
  }

  bool get _isDriverMode => widget.mode == BusMapMode.driver;

  void _syncPickupSubscription() {
    final selectedBusId = _selectedBusId?.trim();
    if (!_isDriverMode || selectedBusId == null || selectedBusId.isEmpty) {
      _pickupSubscription?.cancel();
      _pickupSubscription = null;
      _pickupSubscriptionBusId = null;
      _pickupLocations = {};
      return;
    }

    if (_pickupSubscriptionBusId == selectedBusId && _pickupSubscription != null) {
      return;
    }

    _pickupSubscription?.cancel();
    _pickupSubscription = _busService
        .listenToPickupRequestsForBus(selectedBusId)
        .listen(
          (pickupData) {
            if (!mounted) {
              return;
            }
            setState(() {
              _pickupLocations = pickupData;
            });
          },
          onError: (error) {
            debugPrint('Error listening to pickup requests: $error');
          },
        );
    _pickupSubscriptionBusId = selectedBusId;
  }

  /// Initialize user's current location
  Future<void> _initializeLocation() async {
    final location = await LocationService.determinePosition();
    if (!mounted) {
      return;
    }

    setState(() {
      myCurrentLocation = location;
      _startLocation = location;
    });

    _focusUserOnLoad();
  }

  void _focusUserOnLoad() {
    if (_hasFocusedUserOnLoad || !_isMapReady || myCurrentLocation == null) {
      return;
    }

    _hasFocusedUserOnLoad = true;
    _hasAdjustedInitialMapView = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || myCurrentLocation == null) {
        return;
      }
      mapController.move(myCurrentLocation!, 17);
    });
  }

  /// Listen to Firebase for bus location updates
  void _listenToBusLocations() {
    _busSubscription = _busService.listenToBusLocations().listen(
      (updatedBusData) {
        final driverBusId = widget.driverBusId;
        final hasSelectedBus = _selectedBusId != null;
        final selectedStillExists =
            hasSelectedBus && updatedBusData.containsKey(_selectedBusId);

        setState(() {
          busData = updatedBusData;

          // If the preselected route is no longer available, fall back to all routes.
          if (!_isLoadingRoutes &&
              selectedRoute != null &&
              !availableRoutes.contains(selectedRoute)) {
            selectedRoute = null;
          }

          if (_isDriverMode && driverBusId != null && driverBusId.isNotEmpty) {
            _selectedBusId = driverBusId;
          }

          if (!_isDriverMode && hasSelectedBus && !selectedStillExists) {
            _selectedBusId = null;
            _selectedBusEstimate = null;
            _estimateMessage = null;
            _isApproximateEstimate = false;
            _isFetchingEstimate = false;
            _hasConfirmedPickupLocation = false;
            _lastApiBusLocation = null;
          }
        });

        if (_isDriverMode) {
          _syncPickupSubscription();
        }

        if (!_isDriverMode && selectedRoute != null) {
          _loadBusesForSelectedRoute(selectedRoute, showLoading: false);
        }

        if (selectedStillExists) {
          _maybeRefreshEstimateOnBusMovement(updatedBusData);
        }

        _maybeAutoFitToBuses();
      },
      onError: (error) {
        debugPrint('Error listening to bus locations: $error');
      },
    );
  }

  Future<void> _loadAvailableRoutes() async {
    try {
      final routes = await _busService.fetchAvailableRoutes();
      if (!mounted) {
        return;
      }

      final routeToLoad = selectedRoute;
      setState(() {
        availableRoutes = routes;
        _isLoadingRoutes = false;

        if (selectedRoute != null && !availableRoutes.contains(selectedRoute)) {
          selectedRoute = null;
        }
      });

      if (routeToLoad != selectedRoute) {
        await _loadBusesForSelectedRoute(selectedRoute);
      }
    } catch (error) {
      debugPrint('Error loading routes from AWS: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        availableRoutes = _busService.getAvailableRoutes(busData);
        _isLoadingRoutes = false;
      });
    }
  }

  Future<void> _loadBusesForSelectedRoute(
    String? route, {
    bool showLoading = true,
  }) async {
    final requestVersion = ++_routeRequestVersion;

    if (route == null || route.trim().isEmpty) {
      if (!mounted || requestVersion != _routeRequestVersion) {
        return;
      }

      setState(() {
        _routeBusData = busData;
      });

      _maybeAutoFitToBuses();
      return;
    }

    try {
      final routeBuses = await _busService.fetchBusesForRoute(route);
      if (!mounted || requestVersion != _routeRequestVersion) {
        return;
      }

      setState(() {
        _routeBusData = routeBuses;
      });

      _maybeAutoFitToBuses();
    } catch (error) {
      debugPrint(
        'Error loading buses for route $route: $error',
      );
      if (!mounted || requestVersion != _routeRequestVersion) {
        return;
      }

      setState(() {
        _routeBusData = busData;
      });
    }
  }

  void _maybeAutoFitToBuses() {
    if (!_isMapReady || _hasAdjustedInitialMapView) {
      return;
    }

    final displayBuses = filteredBusData;
    if (displayBuses.isEmpty) {
      return;
    }

    _hasAdjustedInitialMapView = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      MapUtils.fitToBuses(mapController, displayBuses);
    });
  }

  void _listenToUserLocation() {
    _userLocationSubscription = LocationService.positionStream().listen(
      (location) {
        if (!mounted) {
          return;
        }

        setState(() {
          myCurrentLocation = location;
        });
      },
      onError: (error) {
        debugPrint('Error listening to user location: $error');
      },
    );
  }

  void _onBusTapped(String busId) {
    if (_isDriverMode) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedBusId = busId;
      _selectedBusEstimate = null;
      _selectedBusRoutePoints = [];
      _estimateMessage =
          'Move marker to the required location and tap OK to fetch live traffic ETA.';
      _isApproximateEstimate = false;
      _isFetchingEstimate = false;
      _hasConfirmedPickupLocation = false;
      _lastApiBusLocation = null;
    });
  }

  void _maybeRefreshEstimateOnBusMovement(Map<String, BusData> updatedBusData) {
    final selectedBusId = _selectedBusId;
    if (!_hasConfirmedPickupLocation || selectedBusId == null) {
      return;
    }

    if (_isFetchingEstimate) {
      return;
    }

    final selectedBus = updatedBusData[selectedBusId];
    if (selectedBus == null) {
      return;
    }

    final previousApiLocation = _lastApiBusLocation;
    if (previousApiLocation == null) {
      _scheduleEstimateRefresh(immediate: true);
      return;
    }

    final movedMeters = const Distance().as(
      LengthUnit.Meter,
      previousApiLocation,
      selectedBus.location,
    );

    if (movedMeters >= _minBusMovementForApiMeters) {
      _scheduleEstimateRefresh(immediate: true);
    }
  }

  void _scheduleEstimateRefresh({bool immediate = false}) {
    _etaDebounceTimer?.cancel();

    final delay = immediate
        ? Duration.zero
        : const Duration(milliseconds: 1500);
    _etaDebounceTimer = Timer(delay, _refreshSelectedBusEstimate);
  }

  Future<void> _refreshSelectedBusEstimate() async {
    final selectedBusId = _selectedBusId;
    if (selectedBusId == null) {
      return;
    }

    final selectedBus = busData[selectedBusId];
    if (selectedBus == null) {
      return;
    }

    _lastApiBusLocation = selectedBus.location;
    final requestVersion = ++_etaRequestVersion;
    if (mounted) {
      setState(() {
        _isFetchingEstimate = true;
        _estimateMessage = null;
        _isApproximateEstimate = false;
      });
    }

    try {
      final estimate = await _openRouteService.fetchEtaAndDistance(
        from: _startLocation,
        to: selectedBus.location,
      );

      if (!mounted || requestVersion != _etaRequestVersion) {
        return;
      }

      setState(() {
        _selectedBusEstimate = estimate;
        _selectedBusRoutePoints = estimate.routePoints;
        _estimateMessage = null;
        _isApproximateEstimate = false;
        _isFetchingEstimate = false;
      });
    } catch (e) {
      if (!mounted || requestVersion != _etaRequestVersion) {
        return;
      }

      final fallbackEstimate = _buildFallbackEstimate(
        from: _startLocation,
        to: selectedBus.location,
      );

      setState(() {
        _selectedBusEstimate = fallbackEstimate;
        _selectedBusRoutePoints = fallbackEstimate.routePoints;
        _estimateMessage =
            'Live traffic ETA is temporarily unavailable. Showing an approximate estimate.';
        _isApproximateEstimate = true;
        _isFetchingEstimate = false;
      });

      debugPrint('Error fetching selected bus ETA: $e');
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
    );
  }

  /// Get filtered buses based on selected route
  Map<String, BusData> get filteredBusData {
    if (selectedRoute == null) {
      return busData;
    }

    return _routeBusData;
  }

  /// Handle viewing all buses on the map
  void _viewAllBuses() {
    final displayBuses = filteredBusData;
    if (displayBuses.isNotEmpty) {
      MapUtils.fitToBuses(mapController, displayBuses);
    }
  }

  /// Handle centering on user's location
  void _centerOnMyLocation() {
    mapController.move(myCurrentLocation ?? _startLocation, 17);
  }

  void _updateMapCenterLocation(MapPosition position) {
    if (position.center == null) {
      return;
    }

    setState(() {
      _pendingStartLocation = position.center!;
    });
  }

  void _confirmMarkerAndFetchTraffic() {
    if (_isDriverMode) {
      return;
    }

    if (_selectedBusId == null) {
      return;
    }

    final confirmedLocation = _pendingStartLocation ?? _startLocation;
    setState(() {
      _startLocation = confirmedLocation;
      _pendingStartLocation = null;
      _selectedBusEstimate = null;
      _selectedBusRoutePoints = [];
      _estimateMessage = null;
      _isApproximateEstimate = false;
      _isFetchingEstimate = true;
      _hasConfirmedPickupLocation = true;
      _lastApiBusLocation = null;
    });

    _scheduleEstimateRefresh(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final displayBusData = _displayBusDataForCurrentMode();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RouteLK Bus Tracker',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFfec205),
        foregroundColor: Colors.black,
        toolbarHeight: 72,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
      ),
      body: Stack(
        children: [
          _buildMap(displayBusData),
          _buildCenterBalloonMarker(),
          _buildConfirmLocationButton(),
          _buildRouteMenuButton(),
          _buildRouteSelectorPanel(),
          _buildSelectedBusEtaCard(),
          _buildPickedBusMessage(),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(displayBusData),
    );
  }

  Map<String, BusData> _displayBusDataForCurrentMode() {
    final routeFilteredBuses = filteredBusData;
    if (!_isDriverMode) {
      return routeFilteredBuses;
    }

    final driverBusId = widget.driverBusId;
    if (driverBusId == null || !routeFilteredBuses.containsKey(driverBusId)) {
      return {};
    }

    return {driverBusId: routeFilteredBuses[driverBusId]!};
  }

  /// Build the map widget
  Widget _buildCenterBalloonMarker() {
    if (_isDriverMode) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            color: Colors.blue,
            size: 40,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmLocationButton() {
    if (_isDriverMode || _showRouteSelector || _selectedBusId == null) {
      return const SizedBox.shrink();
    }

    final isBusPicked = _pickedBusId != null;

    return Positioned(
      top: 12,
      right: 12,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: isBusPicked ? null : _confirmMarkerAndFetchTraffic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isBusPicked
                    ? Colors.grey.shade100
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isBusPicked
                      ? Colors.grey.shade300
                      : Colors.blue.withValues(alpha: 0.16),
                ),
                boxShadow: isBusPicked
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: isBusPicked
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isBusPicked ? Colors.grey.shade400 : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.my_location,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Set Location',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isBusPicked ? Colors.grey.shade500 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the map widget
  Widget _buildMap(Map<String, BusData> displayBusData) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _startLocation,
        initialZoom: 17,
        onPositionChanged: (MapPosition position, bool hasGesture) {
          if (hasGesture) {
            _updateMapCenterLocation(position);
          }
        },
        onMapReady: () {
          _isMapReady = true;
          _focusUserOnLoad();
          _maybeAutoFitToBuses();
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&key=AIzaSyAO5ec1tqP3KkvuVuhs2cm25-geO9PZQA8',
          userAgentPackageName: 'com.example.bus_tracker',
        ),
        if (_selectedBusRoutePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _selectedBusRoutePoints,
                strokeWidth: 4,
                color: Colors.blue,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (!_showRouteSelector && myCurrentLocation != null)
              Marker(
                point: myCurrentLocation!,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withValues(alpha: 0.25),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
            // Bus markers
            if (!_showRouteSelector)
              ...displayBusData.entries.map(
                (entry) => BusMarker.create(
                  entry.key,
                  entry.value,
                  onTap: _isDriverMode ? null : () => _onBusTapped(entry.key),
                ),
              ),
            if (_isDriverMode && !_showRouteSelector)
              ..._pickupLocations.values.map(
                (location) => Marker(
                  point: location,
                  width: 54,
                  height: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 34,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedBusEtaCard() {
    if (_showRouteSelector) {
      return const SizedBox.shrink();
    }

    if (_isDriverMode) {
      return _buildDriverPickupCard();
    }

    final selectedBusId = _selectedBusId;
    if (selectedBusId == null) {
      return const SizedBox.shrink();
    }

    final selectedBus = busData[selectedBusId];
    if (selectedBus == null) {
      return const SizedBox.shrink();
    }

    final isEmergency = selectedBus.emergency;
    final crowdColor = selectedBus.occupancyColor;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final arrivalLabel = isEmergency
        ? 'Emergency'
        : (_selectedBusEstimate != null
              ? 'Bus arriving in ${_selectedBusEstimate!.durationMinutes.toStringAsFixed(0)} mins'
              : (_isFetchingEstimate
                    ? 'Bus arriving in ...'
                    : 'Bus arrival time is being prepared'));

    return Positioned(
      left: 12,
      right: 12,
      bottom: 10 + bottomInset,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_bus, color: crowdColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bus $selectedBusId - ${selectedBus.route}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedBusId = null;
                        _selectedBusEstimate = null;
                        _selectedBusRoutePoints = [];
                        _estimateMessage = null;
                        _isApproximateEstimate = false;
                        _isFetchingEstimate = false;
                        _hasConfirmedPickupLocation = false;
                        _lastApiBusLocation = null;
                      });
                    },
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isEmergency
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isEmergency
                        ? Colors.red.withValues(alpha: 0.45)
                        : Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEmergency
                          ? Icons.warning_rounded
                          : Icons.access_time_filled,
                      size: 16,
                      color: isEmergency ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        arrivalLabel,
                        style: TextStyle(
                          color: isEmergency ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_isFetchingEstimate)
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Refreshing distance and ETA...'),
                  ],
                )
              else if (_selectedBusEstimate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_estimateMessage != null)
                      Text(
                        _estimateMessage!,
                        style: TextStyle(
                          color: _isApproximateEstimate
                              ? Colors.orange.shade900
                              : Colors.black87,
                          fontSize: 12,
                          fontWeight: _isApproximateEstimate
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    if (_estimateMessage != null) const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetric(
                            icon: Icons.route,
                            label: _isApproximateEstimate
                                ? 'Approx Distance'
                                : 'Distance',
                            value:
                                '${_selectedBusEstimate!.distanceKm.toStringAsFixed(2)} km',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetric(
                            icon: Icons.people_alt,
                            label: 'Crowd Level',
                            value: selectedBus.occupancyLevel,
                            valueColor: selectedBus.occupancyColor,
                            iconColor: selectedBus.occupancyColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _buildPickBusTile(selectedBusId)),
                      ],
                    ),
                  ],
                )
              else
                const Text('Preparing route details...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverPickupCard() {
    final driverBusId = widget.driverBusId ?? 'your bus';
    final pendingCount = _pickupLocations.length;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 10 + bottomInset,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Driver view - $driverBusId',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pendingCount == 0
                            ? 'No pickup requests yet for this bus'
                            : '$pendingCount pickup request(s) are shown on the map',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickedBusMessage() {
    if (!_showPickedBusMessage || _pickedBusMessageText == null) {
      return const SizedBox.shrink();
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isCancellation = _pickedBusMessageIsCancellation;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 320 + bottomInset,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isCancellation ? Colors.red : Colors.green,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isCancellation ? Icons.cancel : Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _pickedBusMessageText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickBusTile(String busId) {
    final isPicked = _pickedBusId == busId;
    final isClickable = isPicked || _hasConfirmedPickupLocation;

    return Material(
      color: isClickable
          ? (isPicked ? Colors.red.shade50 : Colors.orange.shade50)
          : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: (_isSavingPickupRequest || !isClickable)
            ? null
            : () async {
                final pickupLocation = _startLocation;
                setState(() {
                  _isSavingPickupRequest = true;
                });

                try {
                  final passengerId = (widget.passengerId ?? 1).toString();
                  final isCancelling = isPicked && _pickedPickupId != null;

                  if (isCancelling) {
                    await _busService.cancelPickupRequest(
                      pickId: _pickedPickupId!,
                      busId: busId,
                      passengerId: passengerId,
                    );
                  } else {
                    final createdPickup = await _busService.createPickupRequest(
                      busId: busId,
                      passengerId: widget.passengerId ?? 1,
                      location: pickupLocation,
                      route: busData[busId]?.route,
                    );

                    _pickedPickupId = createdPickup['pickId']?.toString();
                  }

                  if (!mounted) {
                    return;
                  }

                  _pickedBusMessageTimer?.cancel();
                  setState(() {
                    _pickedBusId = isCancelling ? null : busId;
                    if (isCancelling) {
                      _pickedPickupId = null;
                    }
                    _pickedBusMessageText = isCancelling
                        ? 'Bus $busId pickup cancelled'
                        : 'Bus $busId picked successfully';
                    _pickedBusMessageIsCancellation = isCancelling;
                    _showPickedBusMessage = true;
                  });
                  _pickedBusMessageTimer = Timer(
                    const Duration(seconds: 2),
                    () {
                      if (mounted) {
                        setState(() {
                          _showPickedBusMessage = false;
                        });
                      }
                    },
                  );
                } catch (e) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send pickup location: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _isSavingPickupRequest = false;
                    });
                  }
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPicked ? 'Cancel Pick Up' : 'Pick Bus',
                style: TextStyle(
                  fontSize: 11,
                  color: isClickable
                      ? (isPicked ? Colors.red : Colors.black54)
                      : Colors.grey.shade500,
                  fontWeight: isPicked ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _isSavingPickupRequest
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isPicked ? Icons.cancel_outlined : Icons.check_circle,
                          size: 16,
                          color: isClickable
                              ? (isPicked ? Colors.red : Colors.deepOrange)
                              : Colors.grey.shade500,
                        ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      busId,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isClickable
                            ? (isPicked ? Colors.red : Colors.deepOrange)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor ?? Colors.deepOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMenuButton() {
    if (_isDriverMode) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 12,
      left: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            setState(() {
              if (!_showRouteSelector) {
                _routeSearchController.clear();
                _routeSearchQuery = '';
              }
              _showRouteSelector = !_showRouteSelector;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.deepOrange.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8A00), Color(0xFFFFB347)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.alt_route,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Routes',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _showRouteSelector ? Icons.expand_less : Icons.expand_more,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSelectorPanel() {
    final filteredRoutes = availableRoutes.where((route) {
      final query = _routeSearchQuery.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }

      return route.toLowerCase().contains(query);
    }).toList();

    final routeItems = <String?>[null, ...filteredRoutes];

    return Positioned(
      top: 64,
      left: 12,
      right: 12,
      child: IgnorePointer(
        ignoring: !_showRouteSelector,
        child: AnimatedOpacity(
          opacity: _showRouteSelector ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Align(
            alignment: Alignment.topLeft,
            child: AnimatedSlide(
              offset: _showRouteSelector
                  ? Offset.zero
                  : const Offset(-0.02, -0.08),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 24,
                    maxHeight: MediaQuery.of(context).size.height * 0.68,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.deepOrange.withValues(alpha: 0.10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFF1D6), Color(0xFFFFF8EE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.route,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Pick a Route',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close routes',
                                onPressed: () {
                                  setState(() {
                                    _showRouteSelector = false;
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: TextField(
                            controller: _routeSearchController,
                            autofocus: true,
                            onChanged: (value) {
                              setState(() {
                                _routeSearchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search route',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _routeSearchQuery.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        setState(() {
                                          _routeSearchController.clear();
                                          _routeSearchQuery = '';
                                        });
                                      },
                                      icon: const Icon(Icons.close),
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildRouteChip(
                                label: 'All Routes',
                                selected: selectedRoute == null,
                                icon: Icons.public,
                                onTap: () {
                                  setState(() {
                                    selectedRoute = null;
                                    _showRouteSelector = false;
                                  });
                                  _loadBusesForSelectedRoute(null);
                                },
                              ),
                              if (availableRoutes.isNotEmpty)
                                _buildRouteChip(
                                  label: availableRoutes.first,
                                  selected:
                                      selectedRoute == availableRoutes.first,
                                  icon: Icons.star_rounded,
                                  onTap: () {
                                    setState(() {
                                      selectedRoute = availableRoutes.first;
                                      _showRouteSelector = false;
                                    });
                                    _loadBusesForSelectedRoute(
                                      availableRoutes.first,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Flexible(
                          child: routeItems.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 28),
                                  child: Center(
                                    child: Text('No routes match your search'),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: routeItems.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: Colors.grey.shade100,
                                  ),
                                  itemBuilder: (context, index) {
                                    final route = routeItems[index];
                                    final isSelected = selectedRoute == route;

                                    return ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4,
                                          ),
                                      leading: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.deepOrange.withValues(
                                                  alpha: 0.12,
                                                )
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          route == null
                                              ? Icons.public
                                              : Icons.alt_route,
                                          color: isSelected
                                              ? Colors.deepOrange
                                              : Colors.black54,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(
                                        route ?? 'All Routes',
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: route == null
                                          ? const Text('Show every live bus')
                                          : Text('Search result for $route'),
                                      trailing: isSelected
                                          ? Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.deepOrange
                                                    .withValues(alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.deepOrange,
                                                size: 18,
                                              ),
                                            )
                                          : null,
                                      selected: isSelected,
                                      selectedTileColor: Colors.deepOrange
                                          .withValues(alpha: 0.06),
                                      onTap: () {
                                        setState(() {
                                          selectedRoute = route;
                                          _showRouteSelector = false;
                                        });
                                        _loadBusesForSelectedRoute(route);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteChip({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Colors.deepOrange.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.deepOrange.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.deepOrange : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.deepOrange : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build floating action buttons
  Widget _buildFloatingButtons(Map<String, BusData> displayBusData) {
    if (_showRouteSelector) {
      return const SizedBox.shrink();
    }

    final isEtaCardVisible =
        _selectedBusId != null && busData.containsKey(_selectedBusId);
    final bottomLift = isEtaCardVisible ? 180.0 : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomLift),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // View all buses button
          if (displayBusData.isNotEmpty)
            FloatingActionButton(
              heroTag: 'viewAllBusesBtn',
              mini: true,
              onPressed: _viewAllBuses,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.yellow,
              child: const Icon(Icons.directions_bus),
            ),
          const SizedBox(height: 10),
          // Center on my location button
          FloatingActionButton(
            heroTag: 'myLocationBtn',
            mini: true,
            onPressed: _centerOnMyLocation,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.yellow,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
