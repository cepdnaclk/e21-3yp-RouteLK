import 'package:flutter/material.dart';

/// Widget for selecting route filter
class RouteSelector extends StatelessWidget {
  final String? selectedRoute;
  final List<String> availableRoutes;
  final ValueChanged<String?> onRouteChanged;

  const RouteSelector({
    super.key,
    required this.selectedRoute,
    required this.availableRoutes,
    required this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route, size: 16, color: Colors.deepOrange),
                const SizedBox(width: 6),
                const Text(
                  'Select Route:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                hint: const Text('All Routes', style: TextStyle(fontSize: 11)),
                isExpanded: false,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                style: const TextStyle(fontSize: 11, color: Colors.black87),
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
                onChanged: onRouteChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
