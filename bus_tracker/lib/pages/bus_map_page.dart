import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_data.dart';
import '../services/location_service.dart';
import '../services/firebase_bus_service.dart';
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

  // Route filtering
  String? selectedRoute;
  List<String> availableRoutes = [];

  @override
  void initState() {
    super.initState();
    // respect any initialRoute passed from previous screen
    selectedRoute = widget.initialRoute;
    _initializeLocation();
    _listenToBusLocations();
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
    _busService.listenToBusLocations().listen(
      (updatedBusData) {
        setState(() {
          busData = updatedBusData;
          availableRoutes = _busService.getAvailableRoutes(busData);
        });
      },
      onError: (error) {
        debugPrint('Error listening to bus locations: $error');
      },
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
        backgroundColor: const Color(0xFFfec205),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No new notifications")),
              );
            },
          ),
        ],
      ),
      body: myCurrentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildMap(displayBusData),
                _buildRouteSelector(),
                _buildInfoCards(displayBusData),
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
                .map((entry) => BusMarker.create(entry.key, entry.value))
                .toList(),
          ],
        ),
      ],
    );
  }

  /// Build route selector widget
  Widget _buildRouteSelector() {
    return Positioned(
      top: 10,
      left: 10,
<<<<<<< Updated upstream
      child: RouteSelector(
        selectedRoute: selectedRoute,
        availableRoutes: availableRoutes,
        onRouteChanged: (newRoute) {
          setState(() {
            selectedRoute = newRoute;
          });
        },
=======
      child: Material(
        color: const Color(0xFFfec205).withOpacity(0.95),
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          tooltip: 'Select Route',
          icon: const Icon(Icons.filter_list),
          color: Colors.black,
          onPressed: () {
            setState(() {
              _showRouteSelector = !_showRouteSelector;
            });
          },
        ),
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
    return Positioned(top: 10, right: 10, child: infoCard);
=======
    return Positioned(
      top: 62,
      left: 10,
      child: Material(
        color: Colors.white.withOpacity(0.85),
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
        color: Colors.yellow.shade100.withOpacity(0.85),
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
>>>>>>> Stashed changes
  }

  /// Build floating action buttons
  Widget _buildFloatingButtons(Map<String, BusData> displayBusData) {
    const appBarColor = Color(0xFFfec205);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // View all buses button
        if (displayBusData.isNotEmpty)
          FloatingActionButton(
            heroTag: 'viewAllBusesBtn',
            mini: true,
            onPressed: _viewAllBuses,
            backgroundColor: appBarColor,
            child: const Icon(Icons.directions_bus, color: Colors.black),
          ),
        const SizedBox(height: 10),
        // Center on my location button
        FloatingActionButton(
          heroTag: 'myLocationBtn',
          onPressed: _centerOnMyLocation,
          backgroundColor: appBarColor,
          child: const Icon(Icons.my_location, color: Colors.black),
        ),
      ],
    );
  }
}
