import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'edit_bus_page.dart';
import 'account_page.dart';

class OperatorDashboardPage extends StatefulWidget {
  final String busId;
  final Map<String, dynamic> busData;
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const OperatorDashboardPage({
    super.key,
    required this.busId,
    required this.busData,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  State<OperatorDashboardPage> createState() =>
      _OperatorDashboardPageState();
}

class _OperatorDashboardPageState extends State<OperatorDashboardPage> {
  late Map<String, dynamic> _fullData;
  bool _isRefreshing = false;
  

  static const Color _yellow   = Color(0xFFfec205);
  static const Color _darkBlue = Color(0xFF00458C);

  @override
  void initState() {
    super.initState();
    _fullData = widget.busData;
  }

  Map<String, dynamic> get _bus      => _fullData['bus']           ?? {};
  Map<String, dynamic> get _services => _fullData['services']      ?? {};
  Map<String, dynamic> get _tracking => _fullData['tracking']      ?? {};
  Map<String, dynamic> get _booking  => _fullData['booking_config'] ?? {};
  Map<String, dynamic> get _other    => _fullData['other_service'] ?? {};

  bool get _isOther    => _services['other_enabled']    == true;
  bool get _hasTracking => _services['tracking_enabled'] == true;
  bool get _hasBooking  => _services['booking_enabled']  == true;

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

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final data = await ApiService.getBusDetails(widget.busId);
      if (!mounted) return;
      setState(() => _fullData = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _openEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditBusPage(
          busId    : widget.busId,
          busData  : _fullData,
          userName : widget.userName,
          userEmail: widget.userEmail,
          onLogout : widget.onLogout,
        ),
      ),
    );
    if (updated == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final approved = _bus['approved'] == true;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation      : 0,
        backgroundColor: Colors.transparent,
        toolbarHeight  : 0,
      ),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
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
                        'Manage your bus',
                        style: TextStyle(
                          fontSize: 13,
                          color   : Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh
                GestureDetector(
                  onTap: _isRefreshing ? null : _refresh,
                  child: Container(
                    height: 44,
                    width : 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color       : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isRefreshing
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
                // Account
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
              onRefresh: _refresh,
              child    : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child  : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),

                    // ── Status banner ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: approved
                              ? [
                                  Colors.green.shade700,
                                  Colors.green.shade500,
                                ]
                              : [
                                  const Color(0xFF00458C),
                                  const Color(0xFF0E74C8),
                                ],
                          begin: Alignment.topLeft,
                          end  : Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color : Colors.white.withOpacity(0.18),
                              shape : BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              approved
                                  ? Icons.verified
                                  : Icons.pending_actions,
                              color: Colors.white,
                              size : 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  approved
                                      ? 'Your bus is live!'
                                      : 'Changes pending approval',
                                  style: const TextStyle(
                                    color     : Colors.white,
                                    fontSize  : 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  approved
                                      ? 'Passengers can now see and track your bus.'
                                      : 'Admin is reviewing your recent changes.',
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

                    const SizedBox(height: 16),

                    // ── Bus Identity ───────────────────────────────
                    _detailCard(
                      icon : Icons.directions_bus_outlined,
                      title: 'Bus Identity',
                      rows : [
                        _detailRow('Bus ID',     _bus['bus_id']),
                        _detailRow('Bus Number', _bus['bus_number']),
                        _detailRow('Bus Type',   _bus['bus_type']),
                        _detailRow('Total Seats',
                            _bus['total_seats']?.toString()),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Owner Details ──────────────────────────────
                    _detailCard(
                      icon : Icons.person_outline,
                      title: 'Owner Details',
                      rows : [
                        _detailRow('Owner NIC', _bus['owner_nic']),
                        _detailRow('Contact No', _bus['contact_no']),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Route / Service ────────────────────────────
                    _isOther
                        ? _detailCard(
                            icon : Icons.school_outlined,
                            title: _other['service_type'] ??
                                'Other Service',
                            badge: _other['service_type'],
                            rows : [
                              _detailRow(
                                  'Service Name',
                                  _other['service_name']),
                              _detailRow('From', _other['service_from']),
                              _detailRow('To',   _other['service_to']),
                            ],
                          )
                        : _detailCard(
                            icon : Icons.route_outlined,
                            title: 'Route',
                            rows : [
                              _detailRow('Route', _bus['route']),
                            ],
                          ),

                    const SizedBox(height: 12),

                    // ── Services ───────────────────────────────────
                    _detailCard(
                      icon : Icons.settings_outlined,
                      title: 'Services',
                      rows : [
                        _serviceRow(
                          'Live Tracking',
                          _hasTracking,
                          _hasTracking
                              ? _tracking['device_id']
                              : null,
                        ),
                        _serviceRow(
                          'Seat Booking',
                          _hasBooking,
                          _hasBooking
                              ? 'Window: ${_booking['window_seats']}  ·  '
                                'Normal: ${_booking['normal_seats']}'
                              : null,
                        ),
                        _serviceRow('Other Service', _isOther, null),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Edit button ────────────────────────────────
                    ElevatedButton(
                      onPressed: _openEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _yellow,
                        foregroundColor: Colors.black,
                        padding        : const EdgeInsets.symmetric(
                            vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 8),
                          Text(
                            'Edit Bus Details',
                            style: TextStyle(
                              fontSize  : 17,
                              fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────

  Widget _detailCard({
    required IconData     icon,
    required String       title,
    required List<Widget> rows,
    String?               badge,
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
                        color        : Colors.white,
                        fontSize     : 9,
                        fontWeight   : FontWeight.bold,
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

  Widget _detailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child  : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
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
            color: enabled
                ? Colors.green.shade600
                : Colors.grey.shade400,
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