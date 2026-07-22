import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'account_page.dart';

class EditBusPage extends StatefulWidget {
  final String busId;
  final Map<String, dynamic> busData;
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const EditBusPage({
    super.key,
    required this.busId,
    required this.busData,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  State<EditBusPage> createState() => _EditBusPageState();
}

class _EditBusPageState extends State<EditBusPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  static const Color _yellow   = Color(0xFFfec205);
  static const Color _darkBlue = Color(0xFF00458C);

  // ── Instant fields (no re-approval) ─────────────────────────────────
  late final TextEditingController _contactNoController;
  late final TextEditingController _routeController;
  late final TextEditingController _deviceIdController;

  // ── Re-approval fields ───────────────────────────────────────────────
  late final TextEditingController _totalSeatsController;
  late final TextEditingController _windowSeatsController;
  late final TextEditingController _normalSeatsController;
  late final TextEditingController _serviceNameController;
  late final TextEditingController _serviceFromController;
  late final TextEditingController _serviceToController;

  String? _busType;
  bool    _trackingService = false;
  bool    _bookingService  = false;

  final List<String> _busTypes = [
    'Normal', 'Semi-luxury', 'Luxury', 'AC'
  ];

  Map<String, dynamic> get _bus     => widget.busData['bus']            ?? {};
  Map<String, dynamic> get _services => widget.busData['services']      ?? {};
  Map<String, dynamic> get _tracking => widget.busData['tracking']      ?? {};
  Map<String, dynamic> get _booking  => widget.busData['booking_config'] ?? {};
  Map<String, dynamic> get _other    => widget.busData['other_service'] ?? {};

  bool get _isOther => _services['other_enabled'] == true;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data
    _contactNoController  =
        TextEditingController(text: _bus['contact_no']       ?? '');
    _routeController      =
        TextEditingController(text: _bus['route']             ?? '');
    _deviceIdController   =
        TextEditingController(text: _tracking['device_id']   ?? '');
    _totalSeatsController =
        TextEditingController(text: _bus['total_seats']?.toString() ?? '');
    _windowSeatsController =
        TextEditingController(
            text: _booking['window_seats']?.toString() ?? '');
    _normalSeatsController =
        TextEditingController(
            text: _booking['normal_seats']?.toString() ?? '');
    _serviceNameController =
        TextEditingController(text: _other['service_name']   ?? '');
    _serviceFromController =
        TextEditingController(text: _other['service_from']   ?? '');
    _serviceToController   =
        TextEditingController(text: _other['service_to']     ?? '');

    _busType         = _bus['bus_type'];
    _trackingService = _services['tracking_enabled'] ?? false;
    _bookingService  = _services['booking_enabled']  ?? false;
  }

  @override
  void dispose() {
    _contactNoController.dispose();
    _routeController.dispose();
    _deviceIdController.dispose();
    _totalSeatsController.dispose();
    _windowSeatsController.dispose();
    _normalSeatsController.dispose();
    _serviceNameController.dispose();
    _serviceFromController.dispose();
    _serviceToController.dispose();
    super.dispose();
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

  // ── Save instant changes (contact, route, device) ──────────────────
  Future<void> _saveInstant() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.updateBusInstant({
        'bus_id'    : widget.busId,
        'contact_no': _contactNoController.text.trim(),
        'route'     : _routeController.text.trim(),
        'device_id' : _deviceIdController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content        : Text('Contact, route and device updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content        : Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Submit re-approval request ─────────────────────────────────────
  Future<void> _submitReApproval() async {
    if (!_formKey.currentState!.validate()) return;

    // Confirm with user
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title  : const Text('Submit for re-approval?'),
        content: const Text(
          'Your bus will go offline until the admin approves these changes. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child    : const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child    : const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.updateBusRequest({
        'bus_id'          : widget.busId,
        'bus_type'        : _busType,
        'total_seats'     : int.tryParse(_totalSeatsController.text.trim()),
        'window_seats'    : int.tryParse(_windowSeatsController.text.trim()),
        'normal_seats'    : int.tryParse(_normalSeatsController.text.trim()),
        'tracking_service': _trackingService,
        'booking_service' : _bookingService,
        'service_name'    : _serviceNameController.text.trim(),
        'service_from'    : _serviceFromController.text.trim(),
        'service_to'      : _serviceToController.text.trim(),
        'other_service_type': _other['service_type'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content        : Text('Changes submitted for admin re-approval.'),
          backgroundColor: _darkBlue,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content        : Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 40,
                    width : 40,
                    decoration: BoxDecoration(
                      color       : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.black87, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Bus Details',
                        style: TextStyle(
                          fontSize  : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Some changes require admin re-approval',
                        style: TextStyle(
                            fontSize: 13, color: Colors.black87),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child  : Form(
                key  : _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),

                    // ── Instant section ──────────────────────────
                    _sectionHeader(
                      icon   : Icons.bolt,
                      label  : 'Instant updates',
                      color  : Colors.green.shade700,
                      subtitle: 'No re-approval needed',
                    ),

                    const SizedBox(height: 10),

                    _sectionCard(
                      icon : Icons.phone_outlined,
                      title: 'Contact & Route',
                      children: [
                        _field(
                          controller: _contactNoController,
                          label     : 'Contact Number',
                          hint      : 'e.g., 0771234567',
                          icon      : Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                        ),
                        if (!_isOther) ...[
                          const SizedBox(height: 12),
                          _field(
                            controller: _routeController,
                            label     : 'Route',
                            hint      : 'e.g., Kandy – Gampola',
                            icon      : Icons.map_outlined,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _field(
                          controller: _deviceIdController,
                          label     : 'GPS Device ID',
                          hint      : 'Your GPS tracker device ID',
                          icon      : Icons.phonelink_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Save instant button
                    OutlinedButton(
                      onPressed: _isLoading ? null : _saveInstant,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(color: Colors.green.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Save instant changes',
                            style: TextStyle(
                              fontSize  : 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Re-approval section ──────────────────────
                    _sectionHeader(
                      icon    : Icons.pending_actions,
                      label   : 'Changes requiring re-approval',
                      color   : _darkBlue,
                      subtitle: 'Bus goes offline until admin approves',
                    ),

                    const SizedBox(height: 10),

                    // Bus identity
                    _sectionCard(
                      icon : Icons.directions_bus_outlined,
                      title: 'Bus Identity',
                      children: [
                        DropdownButtonFormField<String>(
                          value     : _busType,
                          decoration: _inputDeco(
                            'Bus Type', 'Select type',
                            Icons.directions_bus_outlined,
                          ),
                          items: _busTypes
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _busType = v),
                          validator: (v) => v == null
                              ? 'Please select a bus type'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _totalSeatsController,
                          label     : 'Total Seats',
                          hint      : 'e.g., 54',
                          icon      : Icons.event_seat_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter total seats';
                            }
                            final n = int.tryParse(v);
                            if (n == null || n <= 0) {
                              return 'Enter a valid seat count';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Services
                    _sectionCard(
                      icon : Icons.settings_outlined,
                      title: 'Services',
                      children: [
                        _toggleRow(
                          icon    : Icons.location_on_outlined,
                          label   : 'Live Tracking',
                          subtitle: 'Show bus on map in real time',
                          value   : _trackingService,
                          onChanged: (v) =>
                              setState(() => _trackingService = v),
                        ),
                        const Divider(height: 20),
                        _toggleRow(
                          icon    : Icons.event_seat_outlined,
                          label   : 'Seat Booking',
                          subtitle: 'Allow passengers to reserve seats',
                          value   : _bookingService,
                          onChanged: (v) =>
                              setState(() => _bookingService = v),
                          isLast  : true,
                        ),
                        if (_bookingService) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _windowSeatsController,
                                  label     : 'Window seats',
                                  hint      : 'e.g., 20',
                                  icon      : Icons.window_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _field(
                                  controller: _normalSeatsController,
                                  label     : 'Normal seats',
                                  hint      : 'e.g., 34',
                                  icon      : Icons.event_seat_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // Other service details (if applicable)
                    if (_isOther) ...[
                      const SizedBox(height: 12),
                      _sectionCard(
                        icon : Icons.school_outlined,
                        title: _other['service_type'] ?? 'Other Service',
                        children: [
                          _field(
                            controller: _serviceNameController,
                            label     : 'Service Name',
                            hint      : 'e.g., Kandy Office Staff Bus',
                            icon      : Icons.label_outline,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _serviceFromController,
                            label     : 'From',
                            hint      : 'Starting location',
                            icon      : Icons.trip_origin,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _serviceToController,
                            label     : 'To',
                            hint      : 'Destination',
                            icon      : Icons.location_on_outlined,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Submit re-approval button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitReApproval,
                      style: ElevatedButton.styleFrom(
                        backgroundColor        : _yellow,
                        foregroundColor        : Colors.black,
                        disabledBackgroundColor:
                            _yellow.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width : 20,
                              child : CircularProgressIndicator(
                                color      : Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_outlined),
                                SizedBox(width: 8),
                                Text(
                                  'Submit for Re-approval',
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

  // ── Helpers ──────────────────────────────────────────────────────────

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required Color color,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize  : 14,
                  fontWeight: FontWeight.bold,
                  color     : color,
                ),
              ),
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
      ],
    );
  }

  Widget _sectionCard({
    required IconData     icon,
    required String       title,
    required List<Widget> children,
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
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData          icon,
    required String            label,
    required String            subtitle,
    required bool              value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child  : Row(
        children: [
          Icon(icon, color: _darkBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize  : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color   : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value           : value,
            onChanged       : onChanged,
            activeColor     : _darkBlue,
            activeTrackColor: _darkBlue.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String                label,
    required String                hint,
    required IconData              icon,
    TextInputType                  keyboardType    = TextInputType.text,
    List<TextInputFormatter>?      inputFormatters,
    String? Function(String?)?     validator,
  }) {
    return TextFormField(
      controller     : controller,
      keyboardType   : keyboardType,
      inputFormatters: inputFormatters,
      validator      : validator,
      decoration     : _inputDeco(label, hint, icon),
    );
  }

  InputDecoration _inputDeco(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText  : label,
      hintText   : hint,
      labelStyle : const TextStyle(color: _darkBlue),
      prefixIcon : Icon(icon, color: _darkBlue),
      border     : OutlineInputBorder(
          borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide  : const BorderSide(color: _darkBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide  : BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}