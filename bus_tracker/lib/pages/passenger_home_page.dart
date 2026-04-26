import 'package:flutter/material.dart';
import 'bus_map_page.dart';
import 'ac_bus_booking_page.dart';
import 'driver_home_page.dart';

class PassengerHomePage extends StatefulWidget {
  final String userName;

  const PassengerHomePage({super.key, this.userName = 'Passenger'});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BusMapPage()),
    );
  }

  void _navigateToDriver() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverHomePage(userName: widget.userName),
      ),
    );
  }

  void _navigateToOperator() {
    // Placeholder for Operator Page: Navigate to a simple scaffold or show a message
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Operator Page")),
          body: const Center(child: Text("Operator functionality coming soon")),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hi ${widget.userName}"),
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
      body: Stack(
        children: [
          // background
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Live Tracking Button
                  SizedBox(
                    width: 300,
                    height: 80,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.location_on),
                      label: const Text(
                        "Live Bus Tracking",
                        style: TextStyle(fontSize: 24, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFfec205),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _navigateToMap,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Seat Booking Button
                  SizedBox(
                    width: 300,
                    height: 80,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.event_seat),
                      label: const Text(
                        "Online Seat Booking",
                        style: TextStyle(fontSize: 24, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFfec205),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
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
                  ),
                ],
              ),
            ),
          ),

          // Bottom Right Buttons (Driver & Operator)
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 140,
                  child: FloatingActionButton.extended(
                    heroTag: "btnDriver",
                    onPressed: _navigateToDriver,
                    label: const Text("Driver"),
                    icon: const Icon(Icons.drive_eta),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 140,
                  child: FloatingActionButton.extended(
                    heroTag: "btnOperator",
                    onPressed: _navigateToOperator,
                    label: const Text("Operator"),
                    icon: const Icon(Icons.admin_panel_settings),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
