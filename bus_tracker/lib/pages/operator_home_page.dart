import 'package:flutter/material.dart';
import 'bus_registration_page.dart';
import 'operator_dashboard_page.dart';
import 'pending_approval_page.dart';
import 'edit_bus_page.dart';
import 'account_page.dart';
import '../services/api_service.dart';

class OperatorHomePage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const OperatorHomePage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  State<OperatorHomePage> createState() => _OperatorHomePageState();
}

class _OperatorHomePageState extends State<OperatorHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _pulseAnimation;

  List<Map<String, dynamic>> _buses = [];
  bool _isLoadingBuses = false;
  bool _initialLoad    = true;

  static const Color _yellow   = Color(0xFFfec205);
  static const Color _darkBlue = Color(0xFF00458C);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync   : this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Load buses on page open
    _loadBuses();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5  && hour < 12) return 'Good Morning!';
    if (hour >= 12 && hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountPage(
          role    : 'Bus Operator',
          email   : widget.userEmail,
          userName: widget.userName,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Future<void> _loadBuses() async {
    setState(() => _isLoadingBuses = true);
    try {
        final buses = await ApiService.getMyBuses(widget.userEmail);
        if (!mounted) return;
        setState(() {
        _buses       = buses;
        _initialLoad = false;
        });
    } catch (e) {
        // Silently fail — just show empty state, no error snackbar
        if (!mounted) return;
        setState(() {
        _buses       = [];
        _initialLoad = false;
        });
    } finally {
        if (mounted) setState(() => _isLoadingBuses = false);
    }
    }

  void _goToRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusRegistrationPage(
          userName : widget.userName,
          userEmail: widget.userEmail,
          onLogout : widget.onLogout,
        ),
      ),
    );
    // Reload buses when returning from registration
    _loadBuses();
  }

  void _openBus(Map<String, dynamic> busData) {
    final approved = busData['bus']['approved'] == true;
    if (approved) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OperatorDashboardPage(
            busId    : busData['bus']['bus_id'],
            busData  : busData,
            userName : widget.userName,
            userEmail: widget.userEmail,
            onLogout : widget.onLogout,
          ),
        ),
      ).then((_) => _loadBuses());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PendingApprovalPage(
            busId    : busData['bus']['bus_id'],
            busData  : Map<String, dynamic>.from(busData['bus']),
            userName : widget.userName,
            userEmail: widget.userEmail,
            onLogout : widget.onLogout,
          ),
        ),
      ).then((_) => _loadBuses());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation      : 0,
        backgroundColor: Colors.transparent,
        toolbarHeight  : 0,
      ),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              color: _yellow,
              borderRadius: BorderRadius.only(
                bottomLeft : Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi ${widget.userName},',
                        style: const TextStyle(
                          fontSize  : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getTimeBasedGreeting(),
                        style: TextStyle(
                          fontSize: 14,
                          color   : Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh button
                GestureDetector(
                  onTap: _isLoadingBuses ? null : _loadBuses,
                  child: Container(
                    height: 44,
                    width : 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color       : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isLoadingBuses
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color      : Colors.black87,
                            ),
                          )
                        : const Icon(Icons.refresh,
                            size: 24, color: Colors.black87),
                  ),
                ),
                // Account button
                GestureDetector(
                  onTap: _openAccount,
                  child: Container(
                    height: 44,
                    width : 44,
                    decoration: BoxDecoration(
                      color       : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_circle,
                        size: 30, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBuses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child  : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // ── Animated banner ────────────────────────────
                    AnimatedBuilder(
                      animation: _animationController,
                      builder  : (context, child) => Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child : child,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00458C), Color(0xFF0E74C8)],
                            begin : Alignment.topLeft,
                            end   : Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color     : const Color(0xFF00458C).withOpacity(0.18),
                              blurRadius: 18,
                              offset    : const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            AnimatedBuilder(
                              animation: _animationController,
                              builder  : (context, child) => Transform.scale(
                                scale: _pulseAnimation.value,
                                child: child,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color : Colors.white.withOpacity(0.18),
                                  shape : BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.directions_bus,
                                  color: Colors.white,
                                  size : 30,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Manage your fleet',
                                    style: TextStyle(
                                      color     : Colors.white,
                                      fontSize  : 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Register buses and manage your operations.',
                                    style: TextStyle(
                                      color   : Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                      height  : 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Register new bus button ────────────────────
                    ElevatedButton(
                      onPressed: _goToRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _yellow,
                        foregroundColor: Colors.black,
                        padding        : const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline),
                          SizedBox(width: 8),
                          Text(
                            'Register a New Bus',
                            style: TextStyle(
                              fontSize  : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── My buses section ───────────────────────────
                    Row(
                      children: [
                        Text(
                          'My Buses',
                          style: TextStyle(
                            fontSize  : 15,
                            fontWeight: FontWeight.bold,
                            color     : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_buses.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color       : _darkBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_buses.length}',
                              style: const TextStyle(
                                color    : Colors.white,
                                fontSize : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Loading state ──────────────────────────────
                    if (_initialLoad)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child  : CircularProgressIndicator(),
                        ),
                      )

                    // ── Empty state ────────────────────────────────
                    else if (_buses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color       : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border      : Border.all(
                              color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.directions_bus_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No buses registered yet',
                              style: TextStyle(
                                fontSize  : 15,
                                fontWeight: FontWeight.w600,
                                color     : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap "Register a New Bus" to add your first bus.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color   : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      )

                    // ── Bus list ───────────────────────────────────
                    else
                      ..._buses.map((busData) {
                        final bus      = busData['bus'] as Map<String, dynamic>;
                        final approved = bus['approved'] == true;
                        final services = busData['services'] as Map<String, dynamic>?;
                        final isOther  = services?['other_enabled'] == true;
                        final other    = busData['other_service'] as Map<String, dynamic>?;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child  : Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 3,
                            child    : InkWell(
                              onTap        : () => _openBus(busData),
                              borderRadius : BorderRadius.circular(16),
                              child        : Padding(
                                padding: const EdgeInsets.all(16),
                                child  : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── Top row ──────────────────
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color       : _yellow,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.directions_bus,
                                            size : 24,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                bus['bus_number'] ?? '-',
                                                style: const TextStyle(
                                                  fontSize  : 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                bus['bus_type'] ?? '-',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color   : Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: approved
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: approved
                                                  ? Colors.green.shade300
                                                  : Colors.orange.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width : 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: approved
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                approved ? 'Live' : 'Pending',
                                                style: TextStyle(
                                                  fontSize  : 11,
                                                  fontWeight: FontWeight.w600,
                                                  color     : approved
                                                      ? Colors.green.shade700
                                                      : Colors.orange.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),

                                    // ── Bottom info row ───────────
                                    Row(
                                      children: [
                                        // Route or service name
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                isOther
                                                    ? Icons.school_outlined
                                                    : Icons.route_outlined,
                                                size : 14,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  isOther
                                                      ? (other?['service_name'] ?? '-')
                                                      : (bus['route'] ?? '-'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color   : Colors.grey.shade600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Seats
                                        Row(
                                          children: [
                                            Icon(Icons.event_seat_outlined,
                                                size : 14,
                                                color: Colors.grey.shade400),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${bus['total_seats'] ?? '-'} seats',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color   : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        // Arrow
                                        Icon(Icons.arrow_forward_ios,
                                            size : 14,
                                            color: Colors.grey.shade400),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}