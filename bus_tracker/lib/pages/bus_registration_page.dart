import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// Bus registration page for bus operators
class BusRegistrationPage extends StatefulWidget {
  const BusRegistrationPage({super.key});

  @override
  State<BusRegistrationPage> createState() => _BusRegistrationPageState();
}

class _BusRegistrationPageState extends State<BusRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _busIdController = TextEditingController();
  final _routeController = TextEditingController();
  final _passengersController = TextEditingController();

  bool _isLoading = false;

  // Default location (Kandy, Sri Lanka)
  static const double _defaultLatitude = 7.2906;
  static const double _defaultLongitude = 80.6337;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _busIdController.dispose();
    _routeController.dispose();
    _passengersController.dispose();
    super.dispose();
  }

  Future<void> _registerBus() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final busId = _busIdController.text.trim();
      final route = _routeController.text.trim();
      final passengers = int.parse(_passengersController.text.trim());

      final DatabaseReference busRef = FirebaseDatabase.instance.ref(
        'buses/$busId',
      );

      await busRef.set({
        'latitude': _defaultLatitude,
        'longitude': _defaultLongitude,
        'route': route,
        'passengers': passengers,
        'timestamp': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bus $busId registered successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear form
        _busIdController.clear();
        _routeController.clear();
        _passengersController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Bus'),
        backgroundColor: Colors.orange,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.orange.shade100],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      size: 60,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Register Your Bus',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in the details to add your bus to the tracking system',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 30),

                  // Form card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Bus ID field
                          TextFormField(
                            controller: _busIdController,
                            decoration: InputDecoration(
                              labelText: 'Bus ID',
                              hintText: 'e.g., bus1, NB-1234',
                              prefixIcon: Icon(
                                Icons.badge,
                                color: Colors.orange.shade700,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.orange.shade700,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a bus ID';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Route field
                          TextFormField(
                            controller: _routeController,
                            decoration: InputDecoration(
                              labelText: 'Route',
                              hintText: 'e.g., Kandy-Gampola',
                              prefixIcon: Icon(
                                Icons.route,
                                color: Colors.orange.shade700,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.orange.shade700,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a route';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Passengers field
                          TextFormField(
                            controller: _passengersController,
                            decoration: InputDecoration(
                              labelText: 'Current Passengers',
                              hintText: 'e.g., 25',
                              prefixIcon: Icon(
                                Icons.people,
                                color: Colors.orange.shade700,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.orange.shade700,
                                  width: 2,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter passenger count';
                              }
                              final number = int.tryParse(value);
                              if (number == null || number < 0) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Register button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerBus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline),
                              SizedBox(width: 8),
                              Text(
                                'Register Bus',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Info text
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bus will be registered with default location. Update location in real-time later.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
