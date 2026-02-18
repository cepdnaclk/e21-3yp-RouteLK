import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

// Bus data model to store location, passenger count, and route
class BusData {
  final LatLng location;
  final int passengers;
  final String route;

  BusData({
    required this.location,
    required this.passengers,
    required this.route,
  });

  // Determine occupancy level and return color
  Color get occupancyColor {
    if (passengers < 20) {
      return Colors.green; // Low occupancy
    } else if (passengers < 40) {
      return Colors.orange; // Moderate occupancy
    } else {
      return Colors.red; // High occupancy
    }
  }

  String get occupancyLevel {
    if (passengers < 20) {
      return 'Low';
    } else if (passengers < 40) {
      return 'Moderate';
    } else {
      return 'High';
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BusTrackerApp());
}

class BusTrackerApp extends StatelessWidget {
  const BusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepOrange, useMaterial3: true),
      home: const BusMapPage(),
    );
  }
}

// Bus Map Page
class BusMapPage extends StatefulWidget {
  const BusMapPage({super.key});

  @override
  State<BusMapPage> createState() => _BusMapPageState();
}

class _BusMapPageState extends State<BusMapPage> {
  LatLng? myCurrentLocation;
  Map<String, BusData> busData =
      {}; // Multiple bus data (location + passengers + route) from Firebase
  final MapController mapController = MapController();
  late DatabaseReference busesRef;

  // Route filtering
  String? selectedRoute; // Currently selected route
  List<String> availableRoutes = []; // List of all available routes

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _listenToBusLocations();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Listen to Firebase Realtime Database for multiple bus data updates
  void _listenToBusLocations() {
    // Firebase path: /buses
    // Expected structure:
    // buses/
    //   bus1: { "latitude": 7.3, "longitude": 80.593, "passengers": 45, "route": "Kandy-Gampola" }
    //   bus2: { "latitude": 7.35, "longitude": 80.6, "passengers": 15, "route": "Kandy-Peradeniya" }
    busesRef = FirebaseDatabase.instance.ref('buses');

    busesRef.onValue.listen(
      (DatabaseEvent event) {
        final data = event.snapshot.value;

        print('=== Firebase Data Received ===');
        print('Raw data: $data');
        print('Data type: ${data.runtimeType}');

        if (data != null && data is Map) {
          Map<String, BusData> updatedBusData = {};

          data.forEach((key, value) {
            if (value is Map) {
              try {
                final lat = (value['latitude'] as num).toDouble();
                // Handle both 'longitude' and 'longitute' typo in Firebase
                final lng =
                    (value.containsKey('longitude')
                            ? value['longitude']
                            : value['longitute'])
                        as num;
                final lngDouble = lng.toDouble();

                // Get passenger count, default to 0 if not provided
                final passengers = (value['passengers'] as num?)?.toInt() ?? 0;

                // Get route, default to 'Unknown' if not provided
                final route = (value['route'] as String?) ?? 'Unknown';

                updatedBusData[key.toString()] = BusData(
                  location: LatLng(lat, lngDouble),
                  passengers: passengers,
                  route: route,
                );
                print(
                  'Bus $key: $lat, $lngDouble, Passengers: $passengers, Route: $route',
                );
              } catch (e) {
                print('Error parsing bus $key: $e');
              }
            }
          });

          setState(() {
            busData = updatedBusData;
            // Extract unique routes from bus data
            availableRoutes =
                busData.values.map((bus) => bus.route).toSet().toList()..sort();
          });

          print('Total buses: ${busData.length}');
          print('Available routes: $availableRoutes');
          print('==============================');
        } else {
          print('No data received or data is not a Map');
          print('==============================');
        }
      },
      onError: (error) {
        print('=== Firebase Error ===');
        print('Error: $error');
        print('======================');
        debugPrint('Error listening to bus locations: $error');
      },
    );
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location services disabled");
      setState(() {
        myCurrentLocation = LatLng(7.2906, 80.6337); // Default to Kandy
      });
      return;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Permission denied");
        setState(() {
          myCurrentLocation = LatLng(7.2906, 80.6337); // Default to Kandy
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Permission denied forever");
      setState(() {
        myCurrentLocation = LatLng(7.2906, 80.6337); // Default to Kandy
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final loc = LatLng(position.latitude, position.longitude);

    setState(() {
      myCurrentLocation = loc;
    });
  }

  // Get filtered buses based on selected route
  Map<String, BusData> get filteredBusData {
    if (selectedRoute == null) {
      return busData; // Show all buses if no route selected
    }
    return Map.fromEntries(
      busData.entries.where((entry) => entry.value.route == selectedRoute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayBusData = filteredBusData; // Buses to display on map

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus Tracker - Real-time"),
        backgroundColor: Colors.deepOrange,
      ),
      body: myCurrentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: LatLng(7.2906, 80.6337), // Kandy center
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    // Markers layer
                    MarkerLayer(
                      markers: [
                        // Your current location (blue marker)
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
                        // Bus markers - create one for each bus with color-coded occupancy
                        ...displayBusData.entries.map((entry) {
                          final busId = entry.key;
                          final bus = entry.value;
                          final busColor = bus.occupancyColor;

                          return Marker(
                            point: bus.location,
                            width: 70,
                            height: 70,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.directions_bus,
                                    color: busColor,
                                    size: 35,
                                  ),
                                ),
                                // Bus ID and passenger count label below the icon
                                Positioned(
                                  bottom: -5,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: busColor,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          busId,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          border: Border.all(
                                            color: busColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person,
                                              size: 8,
                                              color: busColor,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${bus.passengers}',
                                              style: TextStyle(
                                                color: busColor,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                // Route selector dropdown
                Positioned(
                  top: 10,
                  left: 10,
                  child: Card(
                    elevation: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.route,
                                size: 16,
                                color: Colors.deepOrange,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Select Route:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButton<String>(
                              value: selectedRoute,
                              hint: const Text(
                                'All Routes',
                                style: TextStyle(fontSize: 11),
                              ),
                              isExpanded: false,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, size: 20),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Routes'),
                                ),
                                ...availableRoutes.map((route) {
                                  return DropdownMenuItem<String>(
                                    value: route,
                                    child: Text(route),
                                  );
                                }).toList(),
                              ],
                              onChanged: (String? newRoute) {
                                setState(() {
                                  selectedRoute = newRoute;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bus location info card with passenger counts
                if (displayBusData.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Card(
                      color: Colors.blue.shade50,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions_bus,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${displayBusData.length} Bus${displayBusData.length > 1 ? "es" : ""}${selectedRoute != null ? " on $selectedRoute" : " Active"}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...displayBusData.entries.map((entry) {
                              final bus = entry.value;
                              final busColor = bus.occupancyColor;

                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Bus ID
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: busColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Passenger count and occupancy
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: busColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: busColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 10,
                                            color: busColor,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${bus.passengers}',
                                            style: TextStyle(
                                              color: busColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            bus.occupancyLevel,
                                            style: TextStyle(
                                              color: busColor,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 6),
                            // Legend
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildLegendItem(Colors.green, 'Low (<20)'),
                                const SizedBox(width: 6),
                                _buildLegendItem(Colors.orange, 'Mod (20-40)'),
                                const SizedBox(width: 6),
                                _buildLegendItem(Colors.red, 'High (>40)'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // No bus data message
                if (displayBusData.isEmpty && busData.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Card(
                      color: Colors.blue.shade50,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No buses on ${selectedRoute ?? "this route"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Waiting for data message
                if (busData.isEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Card(
                      color: Colors.orange.shade50,
                      elevation: 4,
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Waiting for bus data...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // View all buses button
          if (displayBusData.isNotEmpty)
            FloatingActionButton(
              heroTag: 'viewAllBusesBtn',
              mini: true,
              onPressed: () {
                // Calculate bounds to show all buses
                if (displayBusData.isNotEmpty) {
                  double minLat = displayBusData.values.first.location.latitude;
                  double maxLat = displayBusData.values.first.location.latitude;
                  double minLng =
                      displayBusData.values.first.location.longitude;
                  double maxLng =
                      displayBusData.values.first.location.longitude;

                  for (var bus in displayBusData.values) {
                    if (bus.location.latitude < minLat)
                      minLat = bus.location.latitude;
                    if (bus.location.latitude > maxLat)
                      maxLat = bus.location.latitude;
                    if (bus.location.longitude < minLng)
                      minLng = bus.location.longitude;
                    if (bus.location.longitude > maxLng)
                      maxLng = bus.location.longitude;
                  }

                  // Add padding to bounds
                  final latPadding = (maxLat - minLat) * 0.1;
                  final lngPadding = (maxLng - minLng) * 0.1;

                  final bounds = LatLngBounds(
                    LatLng(minLat - latPadding, minLng - lngPadding),
                    LatLng(maxLat + latPadding, maxLng + lngPadding),
                  );

                  mapController.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(50),
                    ),
                  );
                }
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.directions_bus),
            ),
          const SizedBox(height: 10),
          // Center on my location button
          FloatingActionButton(
            heroTag: 'myLocationBtn',
            onPressed: () {
              if (myCurrentLocation != null) {
                mapController.move(myCurrentLocation!, 15);
              }
            },
            backgroundColor: Colors.deepOrange,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  // Helper method to build legend items
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 7, color: Colors.black54)),
      ],
    );
  }
}
