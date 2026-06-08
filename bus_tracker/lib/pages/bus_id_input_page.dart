import 'package:flutter/material.dart';
import 'driver_analytics_page.dart';

class BusIdInputPage extends StatefulWidget {
  const BusIdInputPage({super.key});

  @override
  State<BusIdInputPage> createState() => _BusIdInputPageState();
}

class _BusIdInputPageState extends State<BusIdInputPage> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  void _proceed() {
    final busId = _controller.text.trim().toUpperCase();
    if (busId.isEmpty) {
      setState(() => _error = 'Please enter your Bus ID');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverAnalyticsPage(busId: busId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        title: const Text('Driver Analytics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bus icon
            Icon(Icons.directions_bus,
              size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),

            const Text(
              'Enter Your Bus ID',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'View analytics for your bus',
              style: theme.textTheme.bodyMedium!
                  .copyWith(color: theme.colorScheme.onBackground.withOpacity(0.6)),
            ),
            const SizedBox(height: 40),

            // Input field
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 18, letterSpacing: 2),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'e.g. B001',
                hintStyle: TextStyle(),
                errorText: _error,
                // Use app InputDecorationTheme for consistent look
                filled: theme.inputDecorationTheme.filled,
                fillColor: theme.inputDecorationTheme.fillColor,
                border: theme.inputDecorationTheme.border,
                focusedBorder: theme.inputDecorationTheme.focusedBorder,
              ),
            ),
            const SizedBox(height: 24),

            // Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _proceed,
                child: const Text(
                  'View Analytics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
