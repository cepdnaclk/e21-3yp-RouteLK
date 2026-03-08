import 'package:flutter/material.dart';
import 'bus_map_page.dart';
import 'ac_bus_booking_page.dart';
import '../widgets/route_selector.dart';
import '../services/firebase_bus_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
  final FirebaseBusService _busService = FirebaseBusService();

  String? _selectedRoute;
  List<String> _availableRoutes = [];
  bool _showRouteSelector = false; // only show after tapping tracking

  @override
  void initState() {
    super.initState();
    // listen for route updates so dropdown includes current database values
    _busService.listenToBusLocations().listen((data) {
      final routes = _busService.getAvailableRoutes(data);
      setState(() {
        _availableRoutes = routes;
      });
    }, onError: (e) => debugPrint('route listener error: $e'));
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusMapPage(initialRoute: _selectedRoute),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Passenger"),
        backgroundColor: Color(0xFFfec205),
        centerTitle: true,
      ),

      body: Stack(
        children: [
          // background
          Positioned.fill(
            child: FlutterMap(
                options: MapOptions(
                initialCenter: LatLng(7.2906, 80.6337), // Kandy center
                initialZoom: 12,
                ),
                children: [
                TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                ],
            ),
         ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Live Tracking Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.location_on),
                    label: const Text(
                      "Live Bus Tracking",
                      style: TextStyle(fontSize: 24),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFfec205),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 30,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _showRouteSelector = true;
                      });
                    },
                  ),

                  // only show selector after button pressed
                  if (_showRouteSelector && _availableRoutes.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    RouteSelector(
                      selectedRoute: _selectedRoute,
                      availableRoutes: _availableRoutes,
                      onRouteChanged: (newRoute) {
                        setState(() {
                          _selectedRoute = newRoute;
                        });
                        if (newRoute != null) {
                          _navigateToMap();
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Seat Booking Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.event_seat),
                    label: const Text(
                      "Online Seat Booking",
                      style: TextStyle(fontSize: 24),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFfec205),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 30,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ACBusBookingPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
