import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import 'mock_payment_page.dart';
import 'booking_dashboard_page.dart';

class ACBusBookingPage extends StatefulWidget {
  final int passengerId;
  final String userEmail; // for account sheet in dashboard

  const ACBusBookingPage({
    super.key,
    required this.passengerId,
    this.userEmail = '',
  });

  @override
  State<ACBusBookingPage> createState() => _ACBusBookingPageState();
}

class _ACBusBookingPageState extends State<ACBusBookingPage> {
  final _bookingService = BookingService();

  // ── Step 1: Route ─────────────────────────────────────────────────────────
  String? _selectedRoute;
  final List<String> _routes = [
    'Colombo - Kandy',
    'Colombo - Galle',
    'Kandy - Colombo',
    'Galle - Colombo',
    'Colombo - Matara',
    'Matara - Colombo',
  ];

  // ── Step 2: Date ──────────────────────────────────────────────────────────
  DateTime? _selectedDate;

  // ── Step 3: Bus ───────────────────────────────────────────────────────────
  List<BusOption> _availableBuses = [];
  bool _isLoadingBuses = false;
  String? _busLoadError;
  BusOption? _selectedBus;

  // ── Step 4: Seats ─────────────────────────────────────────────────────────
  int _windowSeatsRequested = 0;
  int _normalSeatsRequested = 0;
  static const int _maxSeatsPerBooking = 10;

  // ── Step 5: Passenger ─────────────────────────────────────────────────────
  final _nameController  = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey         = GlobalKey<FormState>();
  String _selectedGender = 'Male';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onRouteChanged(String? route) {
    setState(() {
      _selectedRoute = route;
      _selectedDate  = null;
      _availableBuses = [];
      _selectedBus   = null;
      _windowSeatsRequested = 0;
      _normalSeatsRequested = 0;
      _busLoadError  = null;
    });
  }

  void _onBusSelected(BusOption bus) {
    setState(() {
      _selectedBus = bus;
      _windowSeatsRequested = 0;
      _normalSeatsRequested = 0;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _availableBuses = [];
        _selectedBus = null;
        _windowSeatsRequested = 0;
        _normalSeatsRequested = 0;
      });
      await _loadBuses();
    }
  }

  Future<void> _loadBuses() async {
    if (_selectedRoute == null || _selectedDate == null) return;
    setState(() { _isLoadingBuses = true; _busLoadError = null; _availableBuses = []; });
    try {
      final buses = await _bookingService.getAvailableBuses(
        route: _selectedRoute!, travelDate: _selectedDate!);
      setState(() { _availableBuses = buses; _isLoadingBuses = false; });
    } catch (e) {
      setState(() {
        _busLoadError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingBuses = false;
      });
    }
  }

  int get _totalSeats => _windowSeatsRequested + _normalSeatsRequested;

  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalSeats == 0) { _showSnack('Please select at least one seat.'); return; }
    if (_selectedDate == null) { _showSnack('Please select a travel date.'); return; }

    final dateStr =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}';

    final paymentRef = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => MockPaymentPage(
        route: _selectedRoute!,
        busNumber: _selectedBus!.busNumber,
        travelDate: dateStr,
        windowSeats: _windowSeatsRequested,
        normalSeats: _normalSeatsRequested,
        passengerName: _nameController.text.trim(),
        contactNo: _phoneController.text.trim(),
      )),
    );

    if (paymentRef == null || !mounted) return;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _bookingService.createBooking(
        passengerId: widget.passengerId,
        route: _selectedRoute!,
        busId: _selectedBus!.busId,
        scheduleId: _selectedBus!.scheduleId,
        travelDate: _selectedDate!,
        windowSeats: _windowSeatsRequested,
        normalSeats: _normalSeatsRequested,
        passengerName: _nameController.text.trim(),
        contactNo: _phoneController.text.trim(),
        gender: _selectedGender,
        paymentRef: paymentRef,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader
      final passengerName = _nameController.text.trim();
      final contactNo     = _phoneController.text.trim();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingDashboardPage(
            passengerId: widget.passengerId,
            passengerName: passengerName,
            contactNo: contactNo,
            latestBookingId: result.bookingId,
            userEmail: widget.userEmail,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AC Bus Booking'),
        backgroundColor: const Color(0xFFfec205),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── 1. Route ──────────────────────────────────────────
                  _sectionTitle('1. Select Route'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text('Choose your route'),
                          value: _selectedRoute,
                          items: _routes.map((r) =>
                            DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: _onRouteChanged,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 2. Date ───────────────────────────────────────────
                  if (_selectedRoute != null) ...[
                    _sectionTitle('2. Select Travel Date'),
                    Card(
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 16),
                            Text(
                              _selectedDate == null
                                  ? 'Tap to select travel date'
                                  : '${_selectedDate!.toLocal()}'.split(' ')[0],
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedDate == null ? Colors.grey : Colors.black,
                                fontWeight: _selectedDate == null
                                    ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── 3. Bus ────────────────────────────────────────────
                  if (_selectedDate != null) ...[
                    _sectionTitle('3. Select Available Bus'),
                    if (_isLoadingBuses)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_busLoadError != null)
                      _errorCard(_busLoadError!, onRetry: _loadBuses)
                    else if (_availableBuses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('No buses available for this route and date.',
                            style: TextStyle(fontStyle: FontStyle.italic)),
                      )
                    else
                      ..._availableBuses.map((bus) {
                        final selected = _selectedBus?.busId == bus.busId;
                        return Card(
                          color: selected ? Colors.yellow.shade100 : Colors.white,
                          elevation: selected ? 4 : 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: selected
                                ? const BorderSide(color: Color(0xFFfec205), width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => _onBusSelected(bus),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_bus, size: 36, color: Colors.black87),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(bus.busNumber,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 2),
                                      // ── Departure / Arrival times ──
                                      Row(children: [
                                        const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${bus.departureTime} → ${bus.arrivalTime}',
                                          style: const TextStyle(
                                              fontSize: 13, color: Colors.black87),
                                        ),
                                      ]),
                                      const SizedBox(height: 4),
                                      // ── Seat availability chips ──
                                      Row(children: [
                                        _seatChip(
                                          Icons.window,
                                          '${bus.availableWindowSeats} window',
                                          bus.availableWindowSeats > 0
                                              ? Colors.green : Colors.red,
                                        ),
                                        const SizedBox(width: 6),
                                        _seatChip(
                                          Icons.airline_seat_recline_normal,
                                          '${bus.availableNormalSeats} normal',
                                          bus.availableNormalSeats > 0
                                              ? Colors.blue : Colors.red,
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check_circle, color: Color(0xFFfec205))
                                else
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                  ],

                  // ── 4. Seats ──────────────────────────────────────────
                  if (_selectedBus != null) ...[
                    _sectionTitle('4. Select Seats'),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Max seats warning
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.blue, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Max $_maxSeatsPerBooking seats per booking  •  '
                                  '${_maxSeatsPerBooking - _totalSeats} remaining',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.blue),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            _buildSeatCounter(
                              label: 'Window Seats',
                              available: _selectedBus!.availableWindowSeats,
                              count: _windowSeatsRequested,
                              onChanged: (v) {
                                if (v + _normalSeatsRequested <= _maxSeatsPerBooking) {
                                  setState(() => _windowSeatsRequested = v);
                                } else {
                                  _showSnack('Maximum $_maxSeatsPerBooking seats per booking');
                                }
                              },
                            ),
                            const Divider(),
                            _buildSeatCounter(
                              label: 'Normal Seats',
                              available: _selectedBus!.availableNormalSeats,
                              count: _normalSeatsRequested,
                              onChanged: (v) {
                                if (_windowSeatsRequested + v <= _maxSeatsPerBooking) {
                                  setState(() => _normalSeatsRequested = v);
                                } else {
                                  _showSnack('Maximum $_maxSeatsPerBooking seats per booking');
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.yellow.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Seats:',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('$_totalSeats / $_maxSeatsPerBooking',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Color(0xFFfec205))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 5. Passenger Details ──────────────────────────
                    _sectionTitle('5. Passenger Details'),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Please enter your name' : null,
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
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please enter your phone number';
                              if (v.length < 9) return 'Enter a valid phone number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: ['Male', 'Female', 'Other']
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedGender = v!),
                          ),
                          const SizedBox(height: 12),
                          // Max bookings note
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(children: [
                              Icon(Icons.warning_amber_outlined,
                                  color: Colors.orange, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Each passenger can have a maximum of 3 active bookings.',
                                  style: TextStyle(fontSize: 12, color: Colors.orange),
                                ),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── Proceed to Payment ────────────────────────────
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFfec205),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.payment),
                        label: const Text('Proceed to Payment',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        onPressed: _proceedToPayment,
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

  // ── Reusable widgets ──────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
  );

  Widget _seatChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _errorCard(String message, {required VoidCallback onRetry}) => Card(
    color: Colors.red.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Text(message,
            style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ]),
    ),
  );

  Widget _buildSeatCounter({
    required String label,
    required int available,
    required int count,
    required ValueChanged<int> onChanged,
  }) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Text('$available remaining',
                style: TextStyle(
                    fontSize: 12,
                    color: available > 0 ? Colors.green : Colors.red)),
          ]),
          Row(children: [
            IconButton(
              onPressed: count > 0 ? () => onChanged(count - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.red,
            ),
            SizedBox(
              width: 30,
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: (count < available && _totalSeats < _maxSeatsPerBooking)
                  ? () => onChanged(count + 1)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              color: available > 0 ? Colors.green : Colors.grey,
            ),
          ]),
        ],
      );
}