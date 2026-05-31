import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'operator_dashboard_page.dart';
import 'account_page.dart';

class PendingApprovalPage extends StatefulWidget {
  final String busId;
  final Map<String, dynamic> busData;
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const PendingApprovalPage({
    super.key,
    required this.busId,
    required this.busData,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isChecking = false;

  static const Color _yellow   = Color(0xFFfec205);
  static const Color _darkBlue = Color(0xFF00458C);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountPage(
          role     : 'Bus Operator',
          email    : widget.userEmail,
          userName : widget.userName,
          onLogout : widget.onLogout,
        ),
      ),
    );
  }

  Future<void> _checkApprovalStatus() async {
    setState(() => _isChecking = true);
    try {
      final approved = await ApiService.checkApprovalStatus(widget.busId);
      if (!mounted) return;

      if (approved) {
        // Load full details then go to dashboard
        final details = await ApiService.getBusDetails(widget.busId);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OperatorDashboardPage(
              busId    : widget.busId,
              busData  : details,
              userName : widget.userName,
              userEmail: widget.userEmail,
              onLogout : widget.onLogout,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content         : Text('Still pending — admin has not approved yet.'),
            backgroundColor : _darkBlue,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content         : Text('Error: ${e.toString()}'),
          backgroundColor : Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data       = widget.busData;
    final bool isOther    = data['other_service']    == true;
    final bool hasTracking = data['tracking_service'] == true;
    final bool hasBooking  = data['booking_service']  == true;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation        : 0,
        backgroundColor  : Colors.transparent,
        toolbarHeight    : 0,
      ),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 18),
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
                      const SizedBox(height: 3),
                      Text(
                        'Your registration is submitted',
                        style: TextStyle(
                          fontSize: 13,
                          color   : Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _openAccount,
                  child: Container(
                    height: 44,
                    width : 44,
                    decoration: BoxDecoration(
                      color        : Colors.white,
                      borderRadius : BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_circle,
                      size : 30,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // ── Bus ID chip ──────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color       : _darkBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border      : Border.all(
                          color: _darkBlue.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        'Bus ID: ${widget.busId}',
                        style: const TextStyle(
                          fontSize  : 13,
                          fontWeight: FontWeight.w600,
                          color     : _darkBlue,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Pending status card ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00458C), Color(0xFF0E74C8)],
                        begin : Alignment.topLeft,
                        end   : Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color : Colors.white.withOpacity(0.15),
                              shape : BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.pending_actions,
                              color: Colors.white,
                              size : 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Pending Admin Approval',
                          style: TextStyle(
                            color     : Colors.white,
                            fontSize  : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your bus registration has been submitted successfully. '
                          'An admin will review your details and approve your bus shortly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color   : Colors.white.withOpacity(0.88),
                            fontSize: 13,
                            height  : 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color       : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border      : Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width : 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _yellow,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Awaiting review',
                                style: TextStyle(
                                  color     : Colors.white,
                                  fontSize  : 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Bus Identity ─────────────────────────────────
                  _detailCard(
                    icon : Icons.directions_bus_outlined,
                    title: 'Bus Identity',
                    rows : [
                      _detailRow('Bus Number', data['bus_number']),
                      _detailRow('Bus Type',   data['bus_type']),
                      _detailRow('Total Seats',
                          data['total_seats']?.toString()),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Owner Details ────────────────────────────────
                  _detailCard(
                    icon : Icons.person_outline,
                    title: 'Owner Details',
                    rows : [
                      _detailRow('Owner NIC', data['owner_nic']),
                      _detailRow('Contact No', data['contact_no']),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Route / Service ──────────────────────────────
                  isOther
                      ? _detailCard(
                          icon : Icons.school_outlined,
                          title: data['other_service_type'] ?? 'Other Service',
                          badge: data['other_service_type'],
                          rows : [
                            _detailRow('Service Name', data['service_name']),
                            _detailRow('From',         data['service_from']),
                            _detailRow('To',           data['service_to']),
                          ],
                        )
                      : _detailCard(
                          icon : Icons.route_outlined,
                          title: 'Route',
                          rows : [
                            _detailRow('Route', data['route']),
                          ],
                        ),

                  const SizedBox(height: 12),

                  // ── Services ─────────────────────────────────────
                  _detailCard(
                    icon : Icons.settings_outlined,
                    title: 'Services',
                    rows : [
                      _serviceRow(
                        'Live Tracking',
                        hasTracking,
                        hasTracking ? data['device_id'] : null,
                      ),
                      _serviceRow(
                        'Seat Booking',
                        hasBooking,
                        hasBooking
                            ? 'Window: ${data['window_seats']}  ·  '
                              'Normal: ${data['normal_seats']}'
                            : null,
                      ),
                      _serviceRow('Other Service', isOther, null),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Check status button ──────────────────────────
                  ElevatedButton(
                    onPressed: _isChecking ? null : _checkApprovalStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor        : _darkBlue,
                      foregroundColor        : Colors.white,
                      disabledBackgroundColor: _darkBlue.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width : 20,
                            child : CircularProgressIndicator(
                              color      : Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh),
                              SizedBox(width: 8),
                              Text(
                                'Check Approval Status',
                                style: TextStyle(
                                  fontSize  : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 12),

                  // ── Info note ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color       : _darkBlue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: _darkBlue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You will be notified once your bus is approved. '
                            'Tap "Check Approval Status" at any time to see the latest.',
                            style: TextStyle(
                              fontSize: 12,
                              color   : Colors.grey.shade700,
                              height  : 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────

  Widget _detailCard({
    required IconData      icon,
    required String        title,
    required List<Widget>  rows,
    String?                badge,
  }) {
    return Card(
      shape    : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child    : Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _darkBlue, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize  : 13,
                    fontWeight: FontWeight.bold,
                    color     : _darkBlue,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color       : _darkBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      style: const TextStyle(
                        color      : Colors.white,
                        fontSize   : 9,
                        fontWeight : FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child  : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize  : 13,
                fontWeight: FontWeight.w600,
                color     : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceRow(String label, bool enabled, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child  : Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel_outlined,
            size : 18,
            color: enabled ? Colors.green.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize  : 13,
                    fontWeight: FontWeight.w600,
                    color     : enabled
                        ? Colors.black87
                        : Colors.grey.shade400,
                  ),
                ),
                if (subtitle != null && enabled)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color   : Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color       : enabled
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              enabled ? 'Enabled' : 'Disabled',
              style: TextStyle(
                fontSize  : 11,
                fontWeight: FontWeight.w600,
                color     : enabled
                    ? Colors.green.shade700
                    : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}