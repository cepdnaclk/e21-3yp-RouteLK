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
import '../widgets/bus_info_card.dart';
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

  // Route filtering
  String? selectedRoute;
  List<String> availableRoutes = [];

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
    setState(() {
      myCurrentLocation = location;
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
      },
      onError: (error) {
        debugPrint('Error listening to bus locations: $error');
      },
    );
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
    final userLocation = myCurrentLocation;
    if (selectedBusId == null || userLocation == null) {
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
        from: userLocation,
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
        from: userLocation,
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
    if (myCurrentLocation != null) {
      mapController.move(myCurrentLocation!, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayBusData = filteredBusData;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus Tracker - Real-time"),
        backgroundColor: Colors.deepOrange,
      ),
      body: myCurrentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildMap(displayBusData),
                _buildRouteSelector(),
                _buildInfoCards(displayBusData),
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
        initialCenter: LatLng(7.2906, 80.6337), // Kandy center
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        MarkerLayer(
          markers: [
            // User's current location marker
            Marker(
              point: myCurrentLocation!,
              width: 50,
              height: 50,
              child: const Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 40,
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

  /// Build route selector widget
  Widget _buildRouteSelector() {
    return Positioned(
      top: 10,
      left: 10,
      child: RouteSelector(
        selectedRoute: selectedRoute,
        availableRoutes: availableRoutes,
        onRouteChanged: (newRoute) {
          setState(() {
            selectedRoute = newRoute;
          });
        },
      ),
    );
  }

  /// Build info cards (bus info, no buses, or waiting)
  Widget _buildInfoCards(Map<String, BusData> displayBusData) {
    Widget infoCard;

    if (displayBusData.isNotEmpty) {
      infoCard = BusInfoCard(
        busData: displayBusData,
        selectedRoute: selectedRoute,
      );
    } else if (busData.isNotEmpty) {
      infoCard = NoBusesMessage(selectedRoute: selectedRoute);
    } else {
      infoCard = const WaitingForDataMessage();
    }

    return Positioned(top: 10, right: 10, child: infoCard);
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
