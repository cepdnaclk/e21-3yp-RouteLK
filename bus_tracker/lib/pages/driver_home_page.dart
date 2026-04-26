import 'package:flutter/material.dart';
import 'bus_map_page.dart';
import 'passenger_home_page.dart';

class DriverHomePage extends StatefulWidget {
  final String userName;

  const DriverHomePage({super.key, this.userName = 'Driver'});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  Future<void> _navigateToMap() async {
    final busId = await _askDriverBusId();
    if (!mounted || busId == null || busId.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusMapPage(mode: BusMapMode.driver, driverBusId: busId),
      ),
    );
  }

  Future<String?> _askDriverBusId() async {
    final controller = TextEditingController(text: 'bus1');
    final busId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Driver Bus ID'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Bus ID',
              hintText: 'Example: bus1',
            ),
            textInputAction: TextInputAction.done,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Open Map'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return busId;
  }

  void _navigateToPassenger() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerHomePage(userName: widget.userName),
      ),
    );
  }

  void _navigateToAdmin() {
    // Placeholder for Admin Page: Navigate to a simple scaffold or show a message
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Admin Page")),
          body: const Center(child: Text("Admin functionality coming soon")),
        ),
      ),
    );
  }

  void _navigateToAnalytics() {
    // Placeholder for Analytics
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Analytics feature coming soon")),
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
          // Background Map
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Center Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Live Bus Tracking Button
                  SizedBox(
                    width: 300,
                    height: 80,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.location_on),
                      label: const Text(
                        "Bus Tracking",
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

                  // Analytics Button
                  SizedBox(
                    width: 300,
                    height: 80,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.analytics),
                      label: const Text(
                        "Analytics",
                        style: TextStyle(fontSize: 24, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFfec205),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _navigateToAnalytics,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Right Buttons (Passenger & Admin)
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
                    heroTag: "btnPassenger",
                    onPressed: _navigateToPassenger,
                    label: const Text("Passenger"),
                    icon: const Icon(Icons.person),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 140,
                  child: FloatingActionButton.extended(
                    heroTag: "btnAdmin",
                    onPressed: _navigateToAdmin,
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
