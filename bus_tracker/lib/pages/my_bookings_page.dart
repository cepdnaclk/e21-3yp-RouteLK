import 'package:flutter/material.dart';
import '../services/booking_service.dart';

class MyBookingsPage extends StatefulWidget {
  /// Pass contactNo to auto-load bookings after payment
  final String? initialContactNo;

  const MyBookingsPage({super.key, this.initialContactNo});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final _phoneController = TextEditingController();
  final _bookingService  = BookingService();

  List<MyBooking>? _bookings;
  bool _isLoading = false;
  String? _error;

  static const int _maxBookings = 3;

  @override
  void initState() {
    super.initState();
    // Auto-load if phone passed (e.g. after payment redirect)
    if (widget.initialContactNo != null && widget.initialContactNo!.isNotEmpty) {
      _phoneController.text = widget.initialContactNo!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBookings());
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }
    setState(() { _isLoading = true; _error = null; _bookings = null; });
    try {
      final bookings = await _bookingService.getMyBookings(contactNo: phone);
      setState(() { _bookings = bookings; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  int get _activeBookingCount =>
      _bookings?.where((b) => b.bookingStatus.toLowerCase() != 'cancelled').length ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: const Color(0xFFfec205),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,  // clean light background
        child: Column(
            children: [
              // ── Search bar ────────────────────────────────────────────
              Container(
                color: Colors.white.withOpacity(0.95),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Enter your phone number',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                          onSubmitted: (_) => _fetchBookings(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFfec205),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onPressed: _isLoading ? null : _fetchBookings,
                        child: const Icon(Icons.search),
                      ),
                    ]),

                    // ── Booking quota indicator ───────────────────────
                    if (_bookings != null) ...[
                      const SizedBox(height: 10),
                      _buildQuotaBar(),
                    ],
                  ],
                ),
              ),

              // ── Booking list ──────────────────────────────────────────
              Expanded(child: _buildBody()),
            ],
          ),
        ),
    );
  }

  // ── Quota bar ─────────────────────────────────────────────────────────────
  Widget _buildQuotaBar() {
    final active = _activeBookingCount;
    final remaining = _maxBookings - active;
    final color = remaining == 0 ? Colors.red
        : remaining == 1 ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.confirmation_number, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            remaining > 0
                ? 'Active bookings: $active / $_maxBookings  •  $remaining slot(s) remaining'
                : 'Booking limit reached (max $_maxBookings active bookings)',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ]),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
        ]),
      ),
    );

    if (_bookings == null) return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text('Enter your phone number to see bookings',
            style: TextStyle(color: Colors.grey)),
      ]),
    );

    if (_bookings!.isEmpty) return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text('No bookings found', style: TextStyle(color: Colors.grey, fontSize: 16)),
      ]),
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings!.length,
      itemBuilder: (context, index) => _buildBookingCard(_bookings![index]),
    );
  }

  // ── Booking card ──────────────────────────────────────────────────────────
  Widget _buildBookingCard(MyBooking b) {
    final statusColor = switch (b.bookingStatus.toLowerCase()) {
      'confirmed' => Colors.green,
      'cancelled' => Colors.red,
      'pending'   => Colors.orange,
      _           => Colors.grey,
    };
    final payColor = b.paymentStatus.toLowerCase() == 'paid'
        ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFfec205),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Booking #${b.bookingId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Row(children: [
                _statusBadge(b.bookingStatus.toUpperCase(), statusColor),
                const SizedBox(width: 6),
                _statusBadge(b.paymentStatus.toUpperCase(), payColor),
              ]),
            ],
          ),
        ),

        // ── Body ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _infoRow(Icons.directions_bus, 'Bus',
                '${b.busNumber} (${b.busType})'),
            _infoRow(Icons.route, 'Route', b.route),
            _infoRow(Icons.calendar_today, 'Travel Date', b.travelDate),
            _infoRow(Icons.airline_seat_recline_normal, 'Seats',
                '${b.windowSeats} window  +  ${b.normalSeats} normal  =  ${b.noOfSeats} total'),
            _infoRow(Icons.person, 'Passenger', b.passengerName),
            _infoRow(Icons.access_time, 'Booked At',
                b.bookedAt.split('.').first),
          ]),
        ),
      ]),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color, width: 1.2),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: Colors.grey.shade600),
      const SizedBox(width: 10),
      SizedBox(width: 90,
          child: Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
      Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );
}