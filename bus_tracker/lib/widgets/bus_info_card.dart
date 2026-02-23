import 'package:flutter/material.dart';
import '../models/bus_data.dart';

/// Widget to display bus information and occupancy legend
class BusInfoCard extends StatelessWidget {
  final Map<String, BusData> busData;
  final String? selectedRoute;

  const BusInfoCard({super.key, required this.busData, this.selectedRoute});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 6),
            ...busData.entries.map(_buildBusItem).toList(),
            const SizedBox(height: 6),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.directions_bus, color: Colors.blue, size: 20),
        const SizedBox(width: 8),
        Text(
          '${busData.length} Bus${busData.length > 1 ? "es" : ""}${selectedRoute != null ? " on $selectedRoute" : " Active"}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBusItem(MapEntry<String, BusData> entry) {
    final bus = entry.value;
    final busColor = bus.occupancyColor;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bus ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: busColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: busColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, size: 10, color: busColor),
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
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem(Colors.green, 'Low (<20)'),
        const SizedBox(width: 6),
        _buildLegendItem(Colors.orange, 'Mod (20-40)'),
        const SizedBox(width: 6),
        _buildLegendItem(Colors.red, 'High (>40)'),
      ],
    );
  }

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

/// Widget to display message when no buses match the filter
class NoBusesMessage extends StatelessWidget {
  final String? selectedRoute;

  const NoBusesMessage({super.key, this.selectedRoute});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'No buses on ${selectedRoute ?? "this route"}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display waiting for data message
class WaitingForDataMessage extends StatelessWidget {
  const WaitingForDataMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      elevation: 4,
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('Waiting for bus data...', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
