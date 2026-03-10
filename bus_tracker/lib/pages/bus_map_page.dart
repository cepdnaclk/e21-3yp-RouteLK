import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_data.dart';
import '../services/location_service.dart';
import '../services/firebase_bus_service.dart';
import '../services/open_route_service.dart';
import '../widgets/bus_marker.dart';
import '../widgets/route_selector.dart';
import '../utils/map_utils.dart';

/// Main page displaying the bus tracking map
class BusMapPage extends StatefulWidget {
  /// Optionally start the map with a specific route selected.
  final String? initialRoute;

  const BusMapPage({super.key, this.initialRoute});

  @override
  State<BusMapPage> createState() => _BusMapPageState();
}

class _BusMapPageState extends State<BusMapPage> {
  LatLng? myCurrentLocation;
  LatLng _startLocation = LocationService.defaultLocation;
  Map<String, BusData> busData = {};
  final MapController mapController = MapController();
  final FirebaseBusService _busService = FirebaseBusService();
  final OpenRouteService _openRouteService = OpenRouteService();

  StreamSubscription<Map<String, BusData>>? _busSubscription;
  StreamSubscription<LatLng>? _userLocationSubscription;
  Timer? _etaDebounceTimer;

  String? _selectedBusId;
  RouteEstimate? _selectedBusEstimate;
  bool _isFetchingEstimate = false;
  String? _estimateMessage;
  bool _isApproximateEstimate = false;
  int _etaRequestVersion = 0;
  bool _hasAdjustedInitialMapView = false;
  bool _isMapReady = false;
  bool _hasFocusedUserOnLoad = false;

  // Route filtering
  String? selectedRoute;
  List<String> availableRoutes = [];
  bool _showRouteSelector = false;

  @override
  void initState() {
    super.initState();
    // respect any initialRoute passed from previous screen
    selectedRoute = widget.initialRoute;
    _initializeLocation();
    _listenToUserLocation();
    _listenToBusLocations();
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
    _userLocationSubscription?.cancel();
    _etaDebounceTimer?.cancel();
    super.dispose();
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
        final hasSelectedBus = _selectedBusId != null;
        final selectedStillExists =
            hasSelectedBus && updatedBusData.containsKey(_selectedBusId);

        setState(() {
          busData = updatedBusData;
          availableRoutes = _busService.getAvailableRoutes(busData);

          // If the preselected route is no longer available, fall back to all routes.
          if (selectedRoute != null && !availableRoutes.contains(selectedRoute)) {
            selectedRoute = null;
          }

          if (hasSelectedBus && !selectedStillExists) {
            _selectedBusId = null;
            _selectedBusEstimate = null;
            _estimateMessage = null;
            _isApproximateEstimate = false;
            _isFetchingEstimate = false;
          }
        });

        if (selectedStillExists) {
          _scheduleEstimateRefresh();
        }

        _maybeAutoFitToBuses();
      },
      onError: (error) {
        debugPrint('Error listening to bus locations: $error');
      },
    );
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

        if (_selectedBusId != null) {
          _scheduleEstimateRefresh();
        }
      },
      onError: (error) {
        debugPrint('Error listening to user location: $error');
      },
    );
  }

  void _onBusTapped(String busId) {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedBusId = busId;
      _selectedBusEstimate = null;
      _estimateMessage = null;
      _isApproximateEstimate = false;
      _isFetchingEstimate = true;
    });

    _scheduleEstimateRefresh(immediate: true);
  }

  void _scheduleEstimateRefresh({bool immediate = false}) {
    _etaDebounceTimer?.cancel();

    final delay = immediate ? Duration.zero : const Duration(milliseconds: 1500);
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
        _estimateMessage =
            'Live traffic ETA is temporarily unavailable. Showing an approximate estimate.';
        _isApproximateEstimate = true;
        _isFetchingEstimate = false;
      });

      debugPrint('Error fetching selected bus ETA: $e');
    }
  }

  RouteEstimate _buildFallbackEstimate({required LatLng from, required LatLng to}) {
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
    return _busService.filterBusesByRoute(busData, selectedRoute);
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

  @override
  Widget build(BuildContext context) {
    final displayBusData = filteredBusData;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus Tracker - Real-time"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Stack(
        children: [
          _buildMap(displayBusData),
          _buildRouteMenuButton(),
          _buildRouteSelectorPanel(),
          _buildTopPromptMessage(),
          _buildSelectedBusEtaCard(),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(displayBusData),
    );
  }

  /// Build the map widget
  Widget _buildMap(Map<String, BusData> displayBusData) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _startLocation,
        initialZoom: 17,
        onMapReady: () {
          _isMapReady = true;
          _focusUserOnLoad();
          _maybeAutoFitToBuses();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.bus_tracker',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _startLocation,
              width: 24,
              height: 24,
              child: const Icon(
                Icons.place,
                color: Colors.blue,
                size: 20,
              ),
            ),
            if (myCurrentLocation != null)
              Marker(
                point: myCurrentLocation!,
                width: 22,
                height: 22,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            // Bus markers
            ...displayBusData.entries
                .map(
                  (entry) => BusMarker.create(
                    entry.key,
                    entry.value,
                    onTap: () => _onBusTapped(entry.key),
                  ),
                )
                .toList(),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedBusEtaCard() {
    final selectedBusId = _selectedBusId;
    if (selectedBusId == null) {
      return const SizedBox.shrink();
    }

    final selectedBus = busData[selectedBusId];
    if (selectedBus == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 12,
      right: 12,
      bottom: 20,
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
                  const Icon(Icons.directions_bus, color: Colors.deepOrange),
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
                        _estimateMessage = null;
                        _isApproximateEstimate = false;
                        _isFetchingEstimate = false;
                      });
                    },
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
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
                          color:
                              _isApproximateEstimate
                                  ? Colors.orange.shade900
                                  : Colors.black87,
                          fontSize: 12,
                          fontWeight:
                              _isApproximateEstimate
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
                            label:
                                _isApproximateEstimate
                                    ? 'Approx Distance'
                                    : 'Distance',
                            value:
                                '${_selectedBusEstimate!.distanceKm.toStringAsFixed(2)} km',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetric(
                            icon: Icons.access_time,
                            label: _isApproximateEstimate ? 'Approx ETA' : 'ETA',
                            value:
                                '${_selectedBusEstimate!.durationMinutes.toStringAsFixed(0)} min',
                          ),
                        ),
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

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.deepOrange),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
    return Positioned(
      top: 10,
      left: 10,
      child: Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          tooltip: 'Select Route',
          icon: const Icon(Icons.filter_list),
          color: Colors.deepOrange,
          onPressed: () {
            setState(() {
              _showRouteSelector = !_showRouteSelector;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRouteSelectorPanel() {
    if (!_showRouteSelector) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 62,
      left: 10,
      child: Material(
        color: Colors.white,
        elevation: 5,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(10),
          child: RouteSelector(
            selectedRoute: selectedRoute,
            availableRoutes: availableRoutes,
            onRouteChanged: (newRoute) {
              setState(() {
                selectedRoute = newRoute;
                _showRouteSelector = false;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopPromptMessage() {
    if (_selectedBusId != null) {
      return const SizedBox.shrink();
    }

    const message = 'Select a bus on the map';

    return Positioned(
      top: 10,
      left: 64,
      right: 10,
      child: Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// Build floating action buttons
  Widget _buildFloatingButtons(Map<String, BusData> displayBusData) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // View all buses button
        if (displayBusData.isNotEmpty)
          FloatingActionButton(
            heroTag: 'viewAllBusesBtn',
            mini: true,
            onPressed: _viewAllBuses,
            backgroundColor: Colors.green,
            child: const Icon(Icons.directions_bus),
          ),
        const SizedBox(height: 10),
        // Center on my location button
        FloatingActionButton(
          heroTag: 'myLocationBtn',
          onPressed: _centerOnMyLocation,
          backgroundColor: Colors.deepOrange,
          child: const Icon(Icons.my_location),
        ),
      ],
    );
  }
}
