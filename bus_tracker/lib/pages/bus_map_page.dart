import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'passenger_pickup_status_page.dart';
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
  final String? selectedDirection;

  const BusMapPage({
    super.key,
    this.initialRoute,
    this.mode = BusMapMode.passenger,
    this.driverBusId,
    this.passengerId,
    this.selectedDirection,
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
  double? _pickedInitialDistance;
  bool _hasNavigatedToStatus = false;
  String? _pickedBusMessageText;
  bool _pickedBusMessageIsCancellation = false;
  Timer? _pickedBusMessageTimer;
  Map<String, LatLng> _pickupLocations = {};
  bool _isSavingPickupRequest = false;
  final Map<String, double> _busBearings = {};
  final Map<String, String> _tappedBusDirections = {};

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

    if (!_isDriverMode) {
      _loadPickupSession();
    }
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

  Future<void> _savePickupSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pickedBusId != null) {
        await prefs.setString('picked_bus_id', _pickedBusId!);
        await prefs.setString('picked_pickup_id', _pickedPickupId ?? '');
        if (_pickedInitialDistance != null) {
          await prefs.setDouble('picked_initial_distance', _pickedInitialDistance!);
        } else {
          await prefs.remove('picked_initial_distance');
        }
        await prefs.setDouble('pickup_latitude', _startLocation.latitude);
        await prefs.setDouble('pickup_longitude', _startLocation.longitude);
      } else {
        await _clearPickupSession();
      }
    } catch (e) {
      debugPrint('Error saving pickup session: $e');
    }
  }

  Future<void> _clearPickupSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('picked_bus_id');
      await prefs.remove('picked_pickup_id');
      await prefs.remove('picked_initial_distance');
      await prefs.remove('pickup_latitude');
      await prefs.remove('pickup_longitude');
    } catch (e) {
      debugPrint('Error clearing pickup session: $e');
    }
  }

  Future<void> _loadPickupSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final busId = prefs.getString('picked_bus_id');
      if (busId != null && busId.isNotEmpty) {
        final pickupId = prefs.getString('picked_pickup_id');
        final initialDistance = prefs.getDouble('picked_initial_distance');
        final lat = prefs.getDouble('pickup_latitude');
        final lng = prefs.getDouble('pickup_longitude');

        setState(() {
          _pickedBusId = busId;
          _pickedPickupId = (pickupId != null && pickupId.isNotEmpty) ? pickupId : null;
          _pickedInitialDistance = initialDistance;
          _hasNavigatedToStatus = false; // Will trigger navigation when busData loads
          if (lat != null && lng != null) {
            _startLocation = LatLng(lat, lng);
            _hasConfirmedPickupLocation = true;
          }
        });

        // Auto-navigate to status page if bus data is already available
        if (busData.containsKey(busId) && !_hasNavigatedToStatus) {
          _hasNavigatedToStatus = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navigateToStatusPage(busId);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading pickup session: $e');
    }
  }

  /// Initialize user's current location
  Future<void> _initializeLocation() async {
    final location = await LocationService.determinePosition();
    if (!mounted) {
      return;
    }

    // Check if there is an active pickup session saved in SharedPreferences
    bool hasActiveSession = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final busId = prefs.getString('picked_bus_id');
      if (busId != null && busId.isNotEmpty) {
        hasActiveSession = true;
      }
    } catch (e) {
      debugPrint('Error checking active session in _initializeLocation: $e');
    }

    setState(() {
      myCurrentLocation = location;
      if (!hasActiveSession) {
        _startLocation = location;
      }
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

        for (final entry in updatedBusData.entries) {
          final busId = entry.key;
          final newBus = entry.value;
          final oldBus = busData[busId];
          if (oldBus != null && oldBus.location != newBus.location) {
            _busBearings[busId] = MapUtils.calculateBearing(oldBus.location, newBus.location);
          }
        }

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

        // Auto-navigate to status page if there's a loaded pickup session but we haven't redirected yet
        if (!_isDriverMode && _pickedBusId != null && !_hasNavigatedToStatus) {
          final bus = updatedBusData[_pickedBusId];
          if (bus != null) {
            _hasNavigatedToStatus = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pickedBusId != null) {
                _navigateToStatusPage(_pickedBusId!);
              }
            });
          }
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

    if (_pickedBusId != null) {
      if (_pickedBusId == busId) {
        _navigateToStatusPage(busId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have an active pickup request for Bus $_pickedBusId. Cancel it first to select another bus.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

    print('DEBUG: _onBusTapped called for busId: $busId');
    _busService.getBusDirection(busId).then((direction) {
      print('DEBUG: _onBusTapped resolved direction for $busId: $direction');
      if (mounted && _selectedBusId == busId && direction != null) {
        setState(() {
          _tappedBusDirections[busId] = direction;
        });
      }
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

  Future<void> _navigateToStatusPage(String busId) async {
    final bus = busData[busId];
    if (bus == null) return;

    // Load the latest initial distance from SharedPreferences if available
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDist = prefs.getDouble('picked_initial_distance');
      if (savedDist != null) {
        _pickedInitialDistance = savedDist;
      }
    } catch (_) {}

    _hasNavigatedToStatus = true;

    final confirmedLocation = _startLocation;
    final passengerId = (widget.passengerId ?? 1).toString();

    final busWithDirection = BusData(
      location: bus.location,
      passengers: bus.passengers,
      route: bus.route,
      emergency: bus.emergency,
      speed: bus.speed,
      crowdLevel: bus.crowdLevel,
      updatedAt: bus.updatedAt,
      direction: _tappedBusDirections[busId] ?? bus.direction,
    );

    final cancelled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PassengerPickupStatusPage(
          busId: busId,
          pickupId: _pickedPickupId ?? '',
          passengerId: passengerId,
          pickupLocation: confirmedLocation,
          initialBusData: busWithDirection,
          initialDistance: _pickedInitialDistance,
        ),
      ),
    );

    if (!mounted) return;

    if (cancelled == true) {
      setState(() {
        _pickedBusId = null;
        _pickedPickupId = null;
        _pickedInitialDistance = null;
        _hasNavigatedToStatus = false;
        _selectedBusId = null;
        _selectedBusEstimate = null;
        _selectedBusRoutePoints = [];
        _hasConfirmedPickupLocation = false;
        _lastApiBusLocation = null;
      });

      await _clearPickupSession();
    }
  }

  Widget _buildActivePickupTracker() {
    final pickedBusId = _pickedBusId;
    if (pickedBusId == null) {
      return const SizedBox.shrink();
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 10 + bottomInset,
      child: Card(
        elevation: 8,
        color: const Color(0xFF00458C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.directions_bus, color: Color(0xFFFEC205)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Active Pickup: Bus $pickedBusId',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to view real-time tracking details',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _navigateToStatusPage(pickedBusId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEC205),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Track',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverDirectionBanner() {
    if (!_isDriverMode || widget.selectedDirection == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 14,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00458C),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEC205).withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Color(0xFFFEC205),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Active Route Direction',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.selectedDirection!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          _buildDriverDirectionBanner(),
          _pickedBusId != null ? _buildActivePickupTracker() : _buildSelectedBusEtaCard(),
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
    if (_isDriverMode || _showRouteSelector || _selectedBusId == null || _pickedBusId != null) {
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
                  bearing: _busBearings[entry.key],
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

    final String directionDisplay;
    final tappedDir = _tappedBusDirections[selectedBusId];
    final busDataDir = selectedBus.direction;
    final fallbackRoute = (selectedBus.route != 'Unknown' && selectedBus.route.isNotEmpty)
        ? selectedBus.route
        : (_routeBusData[selectedBusId]?.route ?? 'Unknown');

    if (tappedDir != null && tappedDir != 'Unknown') {
      directionDisplay = tappedDir;
    } else if (busDataDir != null && busDataDir != 'Unknown') {
      directionDisplay = busDataDir;
    } else {
      directionDisplay = fallbackRoute;
    }
    print('DEBUG: _buildSelectedBusEtaCard values -> tappedDir: $tappedDir, busDataDir: $busDataDir, route: ${selectedBus.route}, fallbackRoute: $fallbackRoute, directionDisplay: $directionDisplay');

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
                      'Bus $selectedBusId - $directionDisplay',
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
    final isClickable = _hasConfirmedPickupLocation;

    return Material(
      color: isClickable ? Colors.orange.shade50 : Colors.grey.shade200,
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
                  final createdPickup = await _busService.createPickupRequest(
                    busId: busId,
                    passengerId: widget.passengerId ?? 1,
                    location: pickupLocation,
                    route: busData[busId]?.route,
                  );

                  if (!mounted) {
                    return;
                  }

                  _pickedPickupId = createdPickup['pickId']?.toString();
                  _pickedBusId = busId;
                  _pickedInitialDistance = _selectedBusEstimate?.distanceKm;

                  setState(() {
                    _isSavingPickupRequest = false;
                  });

                  await _savePickupSession();

                  // Navigate to the real-time status page
                  await _navigateToStatusPage(busId);
                } catch (e) {
                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    _isSavingPickupRequest = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send pickup location: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pick Bus',
                style: TextStyle(
                  fontSize: 11,
                  color: isClickable ? Colors.black54 : Colors.grey.shade500,
                  fontWeight: FontWeight.normal,
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
                          Icons.check_circle,
                          size: 16,
                          color: isClickable
                              ? Colors.deepOrange
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
                            ? Colors.deepOrange
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
        _selectedBusId != null && busData.containsKey(_selectedBusId) && _pickedBusId == null;
    final isActivePickupVisible = _pickedBusId != null;
    final bottomLift = isEtaCardVisible ? 180.0 : (isActivePickupVisible ? 100.0 : 0.0);

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
