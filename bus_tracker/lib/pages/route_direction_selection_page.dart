import 'package:flutter/material.dart';
import 'bus_map_page.dart';
import '../services/firebase_bus_service.dart';

class RouteDirectionSelectionPage extends StatefulWidget {
  final String busId;
  final String route;
  final String userName;
  final String userEmail;

  const RouteDirectionSelectionPage({
    super.key,
    required this.busId,
    required this.route,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<RouteDirectionSelectionPage> createState() => _RouteDirectionSelectionPageState();
}

class _RouteDirectionSelectionPageState extends State<RouteDirectionSelectionPage> {
  late List<String> _directions;

  @override
  void initState() {
    super.initState();
    _directions = _parseDirections(widget.route);
  }

  List<String> _parseDirections(String routeStr) {
    final cleanRoute = routeStr.trim();
    if (cleanRoute.isEmpty) {
      return ['Unknown Direction', 'Unknown Direction (Reverse)'];
    }

    // Split by common dash separators
    final parts = cleanRoute.split(RegExp(r'\s*-\s*|\s*–\s*|\s*—\s*'));
    if (parts.length >= 2) {
      final start = parts.first.trim();
      final end = parts.last.trim();
      return [
        '$start - $end',
        '$end - $start',
      ];
    }

    // Fallback if not splittable
    return [
      cleanRoute,
      '$cleanRoute (Reverse)',
    ];
  }

  void _selectDirection(String direction) async {
    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final busService = FirebaseBusService();
      await busService.setBusDirection(
        busId: widget.busId,
        direction: direction,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading spinner
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BusMapPage(
            mode: BusMapMode.driver,
            driverBusId: widget.busId,
            selectedDirection: direction,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update direction on server: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFEC205);
    const accentColor = Color(0xFF00458C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Select Direction',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Header Card
              Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_calls,
                          size: 36,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bus ID: ${widget.busId}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registered Route: ${widget.route}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please select your current driving direction to initialize the tracking map.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Option 1
              _buildDirectionCard(
                directionText: _directions[0],
                subtitle: 'Forward Route',
                icon: Icons.arrow_forward_rounded,
                primaryColor: primaryColor,
                accentColor: accentColor,
              ),
              const SizedBox(height: 16),
              // Option 2
              _buildDirectionCard(
                directionText: _directions[1],
                subtitle: 'Return Route',
                icon: Icons.arrow_back_rounded,
                primaryColor: primaryColor,
                accentColor: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionCard({
    required String directionText,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required Color accentColor,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _selectDirection(directionText),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      directionText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
