import 'package:flutter/material.dart';
import '../services/booking_service.dart';

class ACBusBookingPage extends StatefulWidget {
  const ACBusBookingPage({super.key});

  @override
  State<ACBusBookingPage> createState() => _ACBusBookingPageState();
}

class _ACBusBookingPageState extends State<ACBusBookingPage> {
  // --- 1. Route Selection State ---
  String? _selectedRoute;
  final List<String> _routes = [
    'Colombo - Kandy',
    'Colombo - Galle',
    'Kandy - Colombo',
    'Galle - Colombo',
    'Colombo - Matara',
    'Matara - Colombo',
  ];

  // --- 2. Bus Selection State ---
  Map<String, dynamic>? _selectedBus;
  // Mock data for buses available per route
  final Map<String, List<Map<String, dynamic>>> _busesByRoute = {
    'Colombo - Kandy': [
      {'id': 'B001', 'time': '08:00 AM', 'busNo': 'NB-1234', 'window': 5, 'normal': 10},
      {'id': 'B002', 'time': '10:30 AM', 'busNo': 'ND-5678', 'window': 2, 'normal': 8},
      {'id': 'B003', 'time': '01:00 PM', 'busNo': 'NC-9012', 'window': 8, 'normal': 15},
    ],
    'Colombo - Galle': [
      {'id': 'B004', 'time': '07:00 AM', 'busNo': 'NE-3456', 'window': 0, 'normal': 5},
      {'id': 'B005', 'time': '09:00 AM', 'busNo': 'NF-7890', 'window': 4, 'normal': 12},
    ],
    // Generic mock data for others
    'Kandy - Colombo': [
      {'id': 'B006', 'time': '02:00 PM', 'busNo': 'NA-1111', 'window': 6, 'normal': 20},
    ],
    'Galle - Colombo': [
      {'id': 'B007', 'time': '04:00 PM', 'busNo': 'NB-2222', 'window': 3, 'normal': 8},
    ],
    'Colombo - Matara': [
      {'id': 'B008', 'time': '06:00 AM', 'busNo': 'NM-3333', 'window': 10, 'normal': 12},
    ],
    'Matara - Colombo': [
      {'id': 'B009', 'time': '05:00 PM', 'busNo': 'NM-4444', 'window': 2, 'normal': 4},
    ],
  };

  // --- 3. Date Selection State ---
  DateTime? _selectedDate;

  // --- 4. Seat Selection State ---
  int _windowSeatsRequested = 0;
  int _normalSeatsRequested = 0;

  // --- 5. Passenger Details State ---
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  // Custom Booking Service
  final _bookingService = BookingService();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _resetSelection() {
    setState(() {
      _selectedBus = null;
      _selectedDate = null;
      _windowSeatsRequested = 0;
      _normalSeatsRequested = 0;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitBooking() {
    if (_formKey.currentState!.validate()) {
      if (_windowSeatsRequested == 0 && _normalSeatsRequested == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one seat.')),
        );
        return;
      }
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a travel date.')),
        );
        return;
      }

      // Show a summary or process booking
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Booking'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Route: $_selectedRoute'),
                const SizedBox(height: 4),
                Text('Bus: ${_selectedBus!['busNo']} (${_selectedBus!['time']})'),
                const SizedBox(height: 4),
                Text('Date: ${_selectedDate.toString().split(' ')[0]}'),
                const SizedBox(height: 4),
                Text('Seats: $_windowSeatsRequested Window, $_normalSeatsRequested Normal'),
                const SizedBox(height: 4),
                Text('Name: ${_nameController.text}'),
                const SizedBox(height: 4),
                Text('Tel: ${_phoneController.text}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Close the dialog first
                Navigator.of(context).pop(); 
                
                // Show loading indicator
                showDialog(
                  context: context, 
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  await _bookingService.createBooking(
                    route: _selectedRoute!,
                    busId: _selectedBus!['id'],
                    busNo: _selectedBus!['busNo'],
                    time: _selectedBus!['time'],
                    travelDate: _selectedDate!,
                    windowSeats: _windowSeatsRequested,
                    normalSeats: _normalSeatsRequested,
                    passengerName: _nameController.text,
                    passengerPhone: _phoneController.text,
                  );

                  // Close loading indicator
                  if (mounted) Navigator.of(context).pop();

                  // Show success
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking Confirmed Successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Navigate back to home
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  // Close loading indicator
                  if (mounted) Navigator.of(context).pop();
                  
                  // Show error
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Booking failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get buses for selected route
    List<Map<String, dynamic>> availableBuses = [];
    if (_selectedRoute != null && _busesByRoute.containsKey(_selectedRoute)) {
      availableBuses = _busesByRoute[_selectedRoute]!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AC Bus Booking'),
        backgroundColor: Colors.blue,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Select Route
                _buildSectionTitle('1. Select Route'),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Choose your route'),
                        value: _selectedRoute,
                        items: _routes.map((String route) {
                          return DropdownMenuItem(value: route, child: Text(route));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedRoute = val;
                            _resetSelection();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Select Bus
                if (_selectedRoute != null) ...[
                  _buildSectionTitle('2. Select Available Bus'),
                  if (availableBuses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No buses available for this route.', style: TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  ...availableBuses.map((bus) {
                    bool isSelected = _selectedBus == bus;
                    return Card(
                      color: isSelected ? Colors.blue.shade100 : Colors.white,
                      elevation: isSelected ? 4 : 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isSelected ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.directions_bus, color: Colors.blue),
                        title: Text('${bus['time']} - ${bus['busNo']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('AC Luxury Service'),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          setState(() {
                            _selectedBus = bus;
                            _windowSeatsRequested = 0;
                            _normalSeatsRequested = 0;
                          });
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],

                // 3. Select Date
                if (_selectedBus != null) ...[
                  _buildSectionTitle('3. Select Date'),
                  Card(
                    elevation: 2,
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.blue),
                            const SizedBox(width: 16),
                            Text(
                              _selectedDate == null
                                  ? 'Tap to select travel date'
                                  : '${_selectedDate!.toLocal()}'.split(' ')[0],
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedDate == null ? Colors.grey : Colors.black,
                                fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Select Seats
                  _buildSectionTitle('4. Select Seats'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildSeatCounter(
                            label: 'Window Seats',
                            available: _selectedBus!['window'],
                            count: _windowSeatsRequested,
                            onChanged: (val) {
                              setState(() => _windowSeatsRequested = val);
                            },
                          ),
                          const Divider(),
                          _buildSeatCounter(
                            label: 'Normal Seats',
                            available: _selectedBus!['normal'],
                            count: _normalSeatsRequested,
                            onChanged: (val) {
                              setState(() => _normalSeatsRequested = val);
                            },
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Total Seats: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  '${_windowSeatsRequested + _normalSeatsRequested}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Passenger Details
                  _buildSectionTitle('5. Passenger Details'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telephone Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _submitBooking,
                      child: const Text(
                        'Confirm Booking',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }

  Widget _buildSeatCounter({
    required String label,
    required int available,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Text(
              '$available remaining',
              style: TextStyle(fontSize: 12, color: available > 0 ? Colors.green : Colors.red),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: count > 0 ? () => onChanged(count - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.red,
            ),
            Container(
              width: 30,
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: count < available ? () => onChanged(count + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
              color: available > 0 ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ],
    );
  }
}
