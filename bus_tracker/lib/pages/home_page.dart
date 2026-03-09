import 'package:flutter/material.dart';
import 'role_selection_page.dart';
import 'ac_bus_booking_page.dart';

/// Home page with app information and navigation options
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade700],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 20),

              // App Information Card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 30),
                        _buildNavigationOptions(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus,
            size: 60,
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Bus Tracker',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your Complete Bus Travel Solution',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.deepOrange.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'About Our App',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoItem(
              Icons.location_on,
              'Real-time Bus Tracking',
              'Track buses in real-time with live location updates and occupancy information.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              Icons.airline_seat_recline_extra,
              'AC Bus Booking',
              'Book comfortable AC bus seats for your long-distance travel.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              Icons.route,
              'Multiple Routes',
              'Filter and view buses on different routes across the city.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              Icons.people,
              'Passenger Count',
              'Check bus occupancy levels before boarding to avoid crowded buses.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.deepOrange, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationOptions(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Choose Your Service',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 20),
        _buildServiceCard(
          context,
          icon: Icons.map,
          title: 'Live Bus Tracking',
          description: 'Track buses in real-time on the map',
          color: Colors.green,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildServiceCard(
          context,
          icon: Icons.event_seat,
          title: 'AC Bus Booking',
          description: 'Book your comfortable AC bus seats',
          color: Colors.blue,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ACBusBookingPage()));
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
