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

/// Main page displaying the bus tracking map
class BusMapPage extends StatefulWidget {
  /// Optionally start the map with a specific route selected.
  final String? initialRoute;

  const BusMapPage({super.key, this.initialRoute});

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
  Timer? _etaDebounceTimer;

  String? _selectedBusId;
  RouteEstimate? _selectedBusEstimate;
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
  bool _showRouteSelector = false;

  // Picked bus message state
  bool _showPickedBusMessage = false;
  String? _pickedBusId;
  Timer? _pickedBusMessageTimer;

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
    _pickedBusMessageTimer?.cancel();
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
          if (selectedRoute != null &&
              !availableRoutes.contains(selectedRoute)) {
            selectedRoute = null;
          }

          if (hasSelectedBus && !selectedStillExists) {
            _selectedBusId = null;
            _selectedBusEstimate = null;
            _estimateMessage = null;
            _isApproximateEstimate = false;
            _isFetchingEstimate = false;
            _hasConfirmedPickupLocation = false;
            _lastApiBusLocation = null;
          }
        });

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
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedBusId = busId;
      _selectedBusEstimate = null;
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

  void _updateMapCenterLocation(MapPosition position) {
    if (position.center == null) {
      return;
    }

    setState(() {
      _pendingStartLocation = position.center!;
    });
  }

  void _confirmMarkerAndFetchTraffic() {
    if (_selectedBusId == null) {
      return;
    }

    final confirmedLocation = _pendingStartLocation ?? _startLocation;
    setState(() {
      _startLocation = confirmedLocation;
      _pendingStartLocation = null;
      _selectedBusEstimate = null;
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
    final displayBusData = filteredBusData;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus Tracker - Real-time"),
        backgroundColor: const Color(0xFFfec205),
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

  /// Build the map widget
  Widget _buildCenterBalloonMarker() {
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
    if (_showRouteSelector || _selectedBusId == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(
            child: ElevatedButton.icon(
              onPressed: _confirmMarkerAndFetchTraffic,
              icon: const Icon(Icons.check),
              label: const Text('set location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
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
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.bus_tracker',
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
                  onTap: () => _onBusTapped(entry.key),
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

  Widget _buildPickedBusMessage() {
    if (!_showPickedBusMessage || _pickedBusId == null) {
      return const SizedBox.shrink();
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 320 + bottomInset,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green,
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
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bus $_pickedBusId picked successfully',
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
    return Material(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _pickedBusMessageTimer?.cancel();
          setState(() {
            _pickedBusId = busId;
            _showPickedBusMessage = true;
          });
          _pickedBusMessageTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showPickedBusMessage = false;
              });
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pick Bus',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.deepOrange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      busId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.deepOrange,
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
    final routeItems = <String?>[null, ...availableRoutes];

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_showRouteSelector,
        child: AnimatedOpacity(
          opacity: _showRouteSelector ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Container(
            color: Colors.black38,
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSlide(
                  offset: _showRouteSelector
                      ? Offset.zero
                      : const Offset(-1, 0),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: Material(
                    color: Colors.white,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.route,
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Select Route',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
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
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.builder(
                              itemCount: routeItems.length,
                              itemBuilder: (context, index) {
                                final route = routeItems[index];
                                final isSelected = selectedRoute == route;

                                return ListTile(
                                  leading: Icon(
                                    route == null
                                        ? Icons.public
                                        : Icons.alt_route,
                                    color: isSelected
                                        ? Colors.deepOrange
                                        : Colors.black54,
                                  ),
                                  title: Text(route ?? 'All Routes'),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.deepOrange,
                                        )
                                      : null,
                                  selected: isSelected,
                                  selectedTileColor: Colors.deepOrange
                                      .withValues(alpha: 0.08),
                                  onTap: () {
                                    setState(() {
                                      selectedRoute = route;
                                      _showRouteSelector = false;
                                    });
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
              backgroundColor: Colors.green,
              child: const Icon(Icons.directions_bus),
            ),
          const SizedBox(height: 10),
          // Center on my location button
          FloatingActionButton(
            heroTag: 'myLocationBtn',
            mini: true,
            onPressed: _centerOnMyLocation,
            backgroundColor: Colors.deepOrange,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
