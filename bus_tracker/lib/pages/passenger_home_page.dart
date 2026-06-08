import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import 'bus_map_page.dart';
import 'ac_bus_booking_page.dart';
import 'booking_dashboard_page.dart';
import 'account_page.dart';
import 'role_selection_page.dart';

class PassengerHomePage extends StatefulWidget {
  final String userName;
  final String userEmail; // used to look up passenger_id

  const PassengerHomePage({
    super.key,
    this.userName = 'Passenger',
    this.userEmail = '',
  });

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage>
    with SingleTickerProviderStateMixin {

  // ── Passenger account ─────────────────────────────────────────────────────
  int? _passengerId;
  bool _loadingPassenger = true;

  final _bookingService = BookingService();

  int _selectedIndex = 0;
  late final AnimationController _animationController;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Fetch passenger_id using cognito_sub
    _fetchPassengerId();
  }

  Future<void> _fetchPassengerId() async {
    if (widget.userEmail.isEmpty) {
      setState(() => _loadingPassenger = false);
      return;
    }
    try {
      final data = await _bookingService
          .getPassengerByEmail(widget.userEmail);
      setState(() {
        _passengerId = data['passenger_id'] as int;
        _loadingPassenger = false;
      });
    } catch (e) {
      debugPrint('Could not fetch passenger: $e');
      setState(() => _loadingPassenger = false);
    }
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning!';
    if (hour >= 12 && hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToMap() {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => const BusMapPage(passengerId: 1)));
  }

  void _navigateToBooking() {
    if (_passengerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading your account, please wait...')),
      );
      return;
    }
    // Go to dashboard — shows existing bookings + New Booking FAB
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDashboardPage(
          passengerId: _passengerId!,
          passengerName: widget.userName,
          contactNo: widget.userEmail,
        ),
      ),
    );
  }

  void _showAboutAppSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 48, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10)),
            )),
            const SizedBox(height: 16),
            const Text('About Our App',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            _aboutRow(Icons.directions_bus,
                'Real-time bus tracking with live location updates'),
            _aboutRow(Icons.event_seat,
                'AC bus booking with seat selection and confirmations'),
            _aboutRow(Icons.people_alt,
                'Passenger counts and occupancy indicators'),
            _aboutRow(Icons.location_on,
                'Easy pickup requests and driver communication'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountPage(
          role: 'Passenger',
          email: widget.userEmail,
          userName: widget.userName,
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFFfec205),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hi ${widget.userName},',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(_getTimeBasedGreeting(),
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade900)),
                    const SizedBox(height: 12),
                  ],
                )),
                GestureDetector(
                  onTap: _openAccount,
                  child: Container(
                    height: 44, width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_circle,
                        size: 30, color: Colors.black87),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // ── Animated hero card ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _floatAnimation.value), child: child),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00458C), Color(0xFF0E74C8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF00458C).withOpacity(0.18),
                      blurRadius: 18, offset: const Offset(0, 8),
                    )],
                  ),
                  child: Row(children: [
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseAnimation.value, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: const Icon(Icons.directions_bus,
                            color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your ride is ready',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          'Track buses, book seats, and stay updated in real time.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13, height: 1.35),
                        ),
                      ],
                    )),
                  ]),
                ),
              ),
            ),

            if (_selectedIndex == 0) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _featureBar(Icons.directions_bus, 'Buses'),
                        _featureBar(Icons.access_time, 'ETA'),
                        _featureBar(Icons.event_seat, 'AC Booking'),
                        _featureBar(Icons.people_alt, 'Occupancy'),
                        _featureBar(Icons.route, 'Routes'),
                        _featureBar(Icons.location_on, 'Pickups'),
                        _featureBar(Icons.monetization_on, 'Fare Est.'),
                        _featureBar(Icons.support_agent, 'Support'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 18),

            // ── Action cards ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(children: [
                // Live tracking card
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  child: InkWell(
                    onTap: _navigateToMap,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 18),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfec205),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.location_on,
                              size: 28, color: Colors.black),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Live Bus Tracking',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('See buses live on map',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        )),
                        const Icon(Icons.arrow_forward_ios,
                            size: 18, color: Colors.grey),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Booking card
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  child: InkWell(
                    onTap: _navigateToBooking,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 18),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfec205),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _loadingPassenger
                              ? const SizedBox(
                                  width: 28, height: 28,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.event_seat,
                                  size: 28, color: Colors.black),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Online Seat Booking',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                              _loadingPassenger
                                  ? 'Loading your account...'
                                  : 'Reserve seats quickly',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        )),
                        const Icon(Icons.arrow_forward_ios,
                            size: 18, color: Colors.grey),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            if (index == 1) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')));
            } else if (index == 2) {
              _showAboutAppSheet();
            }
          },
          selectedItemColor: const Color(0xFF00458C),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications), label: 'Notifications'),
            BottomNavigationBarItem(
                icon: Icon(Icons.info_outline), label: 'About Our App'),
          ],
        ),
      ),
    );
  }

  Widget _featureBar(IconData icon, String label) => Column(children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFfec205),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.black, size: 20),
    ),
    const SizedBox(height: 6),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
  ]);

  Widget _aboutRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFfec205).withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF00458C)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text,
          style: TextStyle(
              fontSize: 14, color: Colors.grey.shade800, height: 1.4))),
    ]),
  );
}