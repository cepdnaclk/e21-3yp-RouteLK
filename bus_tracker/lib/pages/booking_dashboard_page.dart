import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import 'ac_bus_booking_page.dart';
import 'account_page.dart';
import 'role_selection_page.dart';
import 'passenger_home_page.dart';

class BookingDashboardPage extends StatefulWidget {
  final int passengerId;
  final String passengerName;
  final String contactNo;
  final int? latestBookingId;
  final String userEmail; // for account settings

  const BookingDashboardPage({
    super.key,
    required this.passengerId,
    required this.passengerName,
    required this.contactNo,
    this.latestBookingId,
    this.userEmail = '',
  });

  @override
  State<BookingDashboardPage> createState() => _BookingDashboardPageState();
}

class _BookingDashboardPageState extends State<BookingDashboardPage> {
  final _bookingService = BookingService();

  List<MyBooking> _bookings = [];
  bool _isLoading = true;
  String? _error;
  int? _cancellingId; // which booking is being cancelled

  static const int _maxBookings = 3;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final bookings = await _bookingService.getMyBookings(
          passengerId: widget.passengerId);
      setState(() { _bookings = bookings; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  int get _activeCount =>
      _bookings.where((b) => b.bookingStatus.toLowerCase() != 'cancelled').length;

  bool get _canMakeNewBooking => _activeCount < _maxBookings;

  void _goToNewBooking() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ACBusBookingPage(
          passengerId: widget.passengerId,
          userEmail: widget.userEmail,
        ),
      ),
    ).then((_) => _loadBookings());
  }

  // ── Cancel booking flow ───────────────────────────────────────────────────
  Future<void> _confirmCancel(MyBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
          SizedBox(width: 8),
          Text('Cancel Booking?'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 12),
            _cancelSummaryRow('Booking', '#${booking.bookingId}'),
            _cancelSummaryRow('Route', booking.route),
            _cancelSummaryRow('Bus', booking.busNumber),
            _cancelSummaryRow('Travel Date', booking.travelDate),
            _cancelSummaryRow('Seats', '${booking.noOfSeats} seat(s)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.red, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This will free up 1 booking slot. '
                    'This action cannot be undone.',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _doCancel(booking.bookingId);
  }

  Future<void> _doCancel(int bookingId) async {
    setState(() => _cancellingId = bookingId);
    try {
      await _bookingService.cancelBooking(
        bookingId: bookingId,
        passengerId: widget.passengerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadBookings(); // refresh list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  Widget _cancelSummaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 80,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountPage(
          role: 'Passenger',
          email: widget.userEmail,
          userName: widget.passengerName,
          onLogout: _logout,
        ),
      ),
    );
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('My Bookings'),
        backgroundColor: const Color(0xFFfec205),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Refresh',
          ),
          GestureDetector(
            onTap: _openAccount,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.account_circle,
                  size: 28,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Column(children: [
                  _buildHeader(),
                  Expanded(child: _buildBookingList()),
                ]),
      floatingActionButton: _canMakeNewBooking
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFfec205),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('New Booking',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _goToNewBooking,
            )
          : null,
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final remaining = _maxBookings - _activeCount;
    final quotaColor = remaining == 0 ? Colors.red
        : remaining == 1 ? Colors.orange
        : Colors.green;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Passenger info
        Row(children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFfec205),
            radius: 24,
            child: Text(
              widget.passengerName.isNotEmpty
                  ? widget.passengerName[0].toUpperCase() : 'P',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.passengerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              Text(widget.contactNo,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          )),
        ]),
        const SizedBox(height: 14),

        // Quota bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: quotaColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: quotaColor.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.confirmation_number_outlined, color: quotaColor, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining > 0
                      ? '$remaining booking slot(s) remaining'
                      : 'Booking limit reached — cancel one to make a new booking',
                  style: TextStyle(
                      color: quotaColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text('$_activeCount of $_maxBookings active bookings used',
                    style: TextStyle(
                        color: quotaColor.withOpacity(0.8), fontSize: 12)),
              ],
            )),
            // Slot dots
            Row(children: List.generate(_maxBookings, (i) => Container(
              width: 14, height: 14,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _activeCount
                    ? quotaColor : quotaColor.withOpacity(0.2),
              ),
            ))),
          ]),
        ),
      ]),
    );
  }

  // ── Booking list ──────────────────────────────────────────────────────────
  Widget _buildBookingList() {
    if (_bookings.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('No bookings yet',
            style: TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 20),
        if (_canMakeNewBooking)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFfec205),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Make a Booking'),
            onPressed: _goToNewBooking,
          ),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final b = _bookings[index];
          return _buildBookingCard(b,
              highlight: b.bookingId == widget.latestBookingId);
        },
      ),
    );
  }

  // ── Booking card ──────────────────────────────────────────────────────────
  Widget _buildBookingCard(MyBooking b, {bool highlight = false}) {
    final isCancelled = b.bookingStatus.toLowerCase() == 'cancelled';
    final isCancelling = _cancellingId == b.bookingId;

    final statusColor = switch (b.bookingStatus.toLowerCase()) {
      'confirmed' => Colors.green,
      'cancelled' => Colors.red,
      'pending'   => Colors.orange,
      _           => Colors.grey,
    };

    // Parse travel date
    bool isPast = false;
    try {
      final travelDate = DateTime.parse(b.travelDate);
      isPast = travelDate.isBefore(
          DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    } catch (_) {}

    final isCompleted = isPast && !isCancelled;
    final canCancel   = !isCancelled && !isPast;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: const Color(0xFFfec205), width: 2.5)
            : null,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: isCancelled ? Colors.grey.shade100 : Colors.white,
          child: Column(children: [
            // ── Header strip ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isCancelled
                  ? Colors.grey.shade300
                  : isCompleted
                      ? Colors.blue.shade100
                      : const Color(0xFFfec205),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    if (highlight) ...[
                      const Icon(Icons.new_releases, size: 16, color: Colors.black54),
                      const SizedBox(width: 4),
                    ],
                    Text('Booking #${b.bookingId}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  _badge(
                    isCompleted ? 'COMPLETED' : b.bookingStatus.toUpperCase(),
                    isCompleted ? Colors.blue : statusColor,
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                // Route + bus
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? Colors.grey.shade200
                          : const Color(0xFFfec205).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.directions_bus,
                        color: isCancelled
                            ? Colors.grey : const Color(0xFFd4a000),
                        size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.route,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isCancelled ? Colors.grey : Colors.black)),
                      Text('${b.busNumber}  •  ${b.busType}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  )),
                ]),
                const Divider(height: 20),

                // Detail grid
                Row(children: [
                  Expanded(child: _detailCell(
                      Icons.calendar_today, 'Travel Date', b.travelDate,
                      dimmed: isCancelled)),
                  Expanded(child: _detailCell(
                      Icons.access_time, 'Booked On',
                      b.bookedAt.split(' ').first,
                      dimmed: isCancelled)),
                ]),
                const SizedBox(height: 10),
                // Passenger name + phone from booking form
                Row(children: [
                  Expanded(child: _detailCell(
                      Icons.person, 'Passenger', b.passengerName,
                      dimmed: isCancelled)),
                  Expanded(child: _detailCell(
                      Icons.phone, 'Contact', b.contactNo,
                      dimmed: isCancelled)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _detailCell(
                      Icons.window, 'Window Seats', '${b.windowSeats} seat(s)',
                      dimmed: isCancelled)),
                  Expanded(child: _detailCell(
                      Icons.airline_seat_recline_normal, 'Normal Seats',
                      '${b.normalSeats} seat(s)',
                      dimmed: isCancelled)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _detailCell(
                      Icons.people, 'Total Seats', '${b.noOfSeats} seat(s)',
                      dimmed: isCancelled)),
                  Expanded(child: _detailCell(
                      Icons.payment, 'Payment',
                      b.paymentStatus.toUpperCase(),
                      valueColor: b.paymentStatus.toLowerCase() == 'paid'
                          ? Colors.green : Colors.orange,
                      dimmed: isCancelled)),
                ]),

                // ── Cancel button ─────────────────────────────────────
                if (canCancel) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: isCancelling
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.red))
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(
                          isCancelling ? 'Cancelling...' : 'Cancel Booking'),
                      onPressed: isCancelling
                          ? null : () => _confirmCancel(b),
                    ),
                  ),
                ],

                // ── Cancelled label ───────────────────────────────────
                if (isCancelled) ...[
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.block, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('This booking was cancelled',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ]),
                ],

                // ── Completed trip label ──────────────────────────────
                if (isCompleted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.blue),
                        SizedBox(width: 6),
                        Text('Trip completed',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _detailCell(IconData icon, String label, String value,
      {Color? valueColor, bool dimmed = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: dimmed ? Colors.grey
                : (valueColor ?? Colors.black87))),
      ]);

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color, width: 1.2),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFfec205),
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          onPressed: _loadBookings,
        ),
      ]),
    ),
  );
}