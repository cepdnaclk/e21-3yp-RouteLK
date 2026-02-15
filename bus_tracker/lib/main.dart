import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

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
  LatLng? busLocation; // Real-time bus location from Firebase
  final MapController mapController = MapController();
  late DatabaseReference busLocationRef;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _listenToBusLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Listen to Firebase Realtime Database for bus location updates
  void _listenToBusLocation() {
    // Firebase path: /bus/location
    // Expected structure: { "latitude": 7.2906, "longitude": 80.6337 }
    busLocationRef = FirebaseDatabase.instance.ref('bus/location');

    busLocationRef.onValue.listen(
      (DatabaseEvent event) {
        final data = event.snapshot.value;

        // Print raw data from Firebase
        print('=== Firebase Data Received ===');
        print('Raw data: $data');
        print('Data type: ${data.runtimeType}');

        if (data != null && data is Map) {
          try {
            final lat = (data['latitude'] as num).toDouble();
            // Handle both 'longitude' and 'longitute' typo in Firebase
            final lng =
                (data.containsKey('longitude')
                        ? data['longitude']
                        : data['longitute'])
                    as num;
            final lngDouble = lng.toDouble();

            // Print parsed values
            print('Parsed Latitude: $lat');
            print('Parsed Longitude: $lngDouble');
            print('==============================');

            setState(() {
              busLocation = LatLng(lat, lngDouble);
            });

            debugPrint('Bus location updated: $lat, $lngDouble');
          } catch (e) {
            print('Error parsing bus location: $e');
            debugPrint('Error parsing bus location: $e');
          }
        } else {
          print('No data received or data is not a Map');
          print('==============================');
        }
      },
      onError: (error) {
        print('=== Firebase Error ===');
        print('Error: $error');
        print('======================');
        debugPrint('Error listening to bus location: $error');
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

  @override
  Widget build(BuildContext context) {
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
                        // Bus location (green bus icon) - only show if data exists
                        if (busLocation != null)
                          Marker(
                            point: busLocation!,
                            width: 60,
                            height: 60,
                            child: Container(
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
                              child: const Icon(
                                Icons.directions_bus,
                                color: Colors.green,
                                size: 35,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Bus location info card
                if (busLocation != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Card(
                      color: Colors.green.shade50,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_bus,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Bus Location',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${busLocation!.latitude.toStringAsFixed(6)}, ${busLocation!.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.center_focus_strong,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                mapController.move(busLocation!, 16);
                              },
                              tooltip: 'Center on bus',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // No bus data message
                if (busLocation == null)
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
          // Center on bus button
          if (busLocation != null)
            FloatingActionButton(
              heroTag: 'busBtn',
              mini: true,
              onPressed: () {
                mapController.move(busLocation!, 16);
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
}
