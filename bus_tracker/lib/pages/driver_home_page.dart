import 'package:flutter/material.dart';

/// Driver Home Page - Placeholder for future implementation
class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: const Color(0xFF00458C),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.drive_eta, size: 100, color: Colors.grey.shade400),
              const SizedBox(height: 30),
              Text(
                'Driver Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Coming Soon!',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 40),
              Text(
                'This feature will allow drivers to:\n'
                '• Accept ride requests\n'
                '• View assigned routes\n'
                '• Update bus location in real-time\n'
                '• Manage passenger pickups',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
