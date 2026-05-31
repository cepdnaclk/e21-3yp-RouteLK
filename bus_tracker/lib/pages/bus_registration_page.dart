import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'pending_approval_page.dart';
import 'account_page.dart';
import 'role_selection_page.dart';

class BusRegistrationPage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const BusRegistrationPage({
    super.key,
    this.userName = 'Bus Operator',
    this.userEmail = '',
    required this.onLogout,
  });

  @override
  State<BusRegistrationPage> createState() => _BusRegistrationPageState();
}

class _BusRegistrationPageState extends State<BusRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _busNumberController    = TextEditingController();
  final _ownerNicController     = TextEditingController();
  final _contactNoController    = TextEditingController();
  final _routeController        = TextEditingController();
  final _totalSeatsController   = TextEditingController();
  final _deviceIdController     = TextEditingController();
  final _windowSeatsController  = TextEditingController();
  final _normalSeatsController  = TextEditingController();
  final _serviceNameController  = TextEditingController();
  final _fromController         = TextEditingController();
  final _toController           = TextEditingController();

  // Service toggles
  bool _trackingService = true;
  bool _bookingService  = false;
  bool _otherService    = false;

  // Dropdowns
  String? _busType;
  String? _otherServiceType;

  final List<String> _busTypes          = ['Normal', 'Semi-luxury', 'Luxury', 'AC'];
  final List<String> _otherServiceTypes = ['Staff Service', 'School Service'];

  bool _isLoading = false;

  static const Color _yellow   = Color(0xFFfec205);
  static const Color _darkBlue = Color(0xFF00458C);

  @override
  void dispose() {
    _busNumberController.dispose();
    _ownerNicController.dispose();
    _contactNoController.dispose();
    _routeController.dispose();
    _totalSeatsController.dispose();
    _deviceIdController.dispose();
    _windowSeatsController.dispose();
    _normalSeatsController.dispose();
    _serviceNameController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountPage(
          role: 'Bus Operator',
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

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate Other service type chip selection
    if (_otherService && _otherServiceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content         : Text('Please select a service type (Staff or School).'),
          backgroundColor : Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Build payload matching DB columns
      final payload = {
        'bus_number'        : _busNumberController.text.trim(),
        'owner_nic'         : _ownerNicController.text.trim(),
        'contact_no'        : _contactNoController.text.trim(),
        'bus_type'          : _busType,
        'total_seats'       : int.parse(_totalSeatsController.text.trim()),
        'approved'          : false,
        'tracking_service'  : _trackingService,
        'device_id'         : _trackingService
                                ? _deviceIdController.text.trim()
                                : null,
        'booking_service'   : _bookingService,
        'window_seats'      : _bookingService
                                ? int.tryParse(_windowSeatsController.text.trim())
                                : null,
        'normal_seats'      : _bookingService
                                ? int.tryParse(_normalSeatsController.text.trim())
                                : null,
        'other_service'     : _otherService,
        'other_service_type': _otherService ? _otherServiceType : null,
        'route'             : !_otherService
                                ? _routeController.text.trim()
                                : null,
        'service_name'      : _otherService
                                ? _serviceNameController.text.trim()
                                : null,
        'service_from'      : _otherService
                                ? _fromController.text.trim()
                                : null,
        'service_to'        : _otherService
                                ? _toController.text.trim()
                                : null,
      };

      // Call real API
      final result = await ApiService.registerBus(payload);
      final busId  = result['bus_id'] as String;

      if (!mounted) return;

      // Navigate to pending approval page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PendingApprovalPage(
            busId    : busId,
            busData  : payload,
            userName : widget.userName,
            userEmail: widget.userEmail,
            onLogout : widget.onLogout,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content         : Text('Error: ${e.toString()}'),
          backgroundColor : Colors.red.shade700,
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

          // ── Header ──────────────────────────────────────────────────
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
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.black87,
                      size : 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Register Your Bus',
                        style: TextStyle(
                          fontSize  : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Add your bus to the tracking system',
                        style: TextStyle(
                          fontSize: 13,
                          color   : Colors.black87,
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
                      color       : Colors.white,
                      borderRadius: BorderRadius.circular(14),
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

          // ── Scrollable body ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child  : Form(
                key  : _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),

                    // ── Promo banner ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00458C), Color(0xFF0E74C8)],
                          begin : Alignment.topLeft,
                          end   : Alignment.bottomRight,
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
                            child: const Icon(
                              Icons.app_registration,
                              color: Colors.white,
                              size : 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'One-time setup',
                                  style: TextStyle(
                                    color     : Colors.white,
                                    fontSize  : 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Submit details and await admin approval before going live.',
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

                    const SizedBox(height: 14),

                    // ── Section 1: Bus Identity ──────────────────────
                    _sectionCard(
                      icon : Icons.badge_outlined,
                      title: 'Bus Identity',
                      children: [
                        _field(
                          controller: _busNumberController,
                          label     : 'Bus Number Plate',
                          hint      : 'e.g., NB-1234',
                          icon      : Icons.credit_card,
                          validator : _required('Bus number plate'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value     : _busType,
                          decoration: _inputDeco(
                            'Bus Type',
                            'Select type',
                            Icons.directions_bus_outlined,
                          ),
                          items: _busTypes
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _busType = v),
                          validator: (v) =>
                              v == null ? 'Please select a bus type' : null,
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

                    // ── Section 2: Owner Details ─────────────────────
                    _sectionCard(
                      icon : Icons.person_outline,
                      title: 'Owner Details',
                      children: [
                        _field(
                          controller: _ownerNicController,
                          label     : 'Owner NIC',
                          hint      : 'National identity card number',
                          icon      : Icons.fingerprint,
                          validator : _required('Owner NIC'),
                        ),
                        const SizedBox(height: 12),
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
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Section 3: Route or Service Details ──────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve   : Curves.easeInOut,
                      child   : _otherService
                          ? _serviceRouteCard()
                          : _sectionCard(
                              icon : Icons.route_outlined,
                              title: 'Route',
                              children: [
                                _field(
                                  controller: _routeController,
                                  label     : 'Route',
                                  hint      : 'e.g., Kandy – Gampola',
                                  icon      : Icons.map_outlined,
                                  validator : !_otherService
                                      ? _required('Route')
                                      : null,
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 12),

                    // ── Section 4: Services ──────────────────────────
                    _sectionCard(
                      icon : Icons.settings_outlined,
                      title: 'Services',
                      children: [

                        // Live Tracking toggle
                        _toggleRow(
                          icon     : Icons.location_on_outlined,
                          label    : 'Live Tracking',
                          subtitle : 'Show bus position on map in real time',
                          value    : _trackingService,
                          onChanged: (v) =>
                              setState(() => _trackingService = v),
                        ),

                        // Conditional: Device ID
                        if (_trackingService)
                          _conditionalBox(
                            child: _field(
                              controller: _deviceIdController,
                              label     : 'GPS Device ID',
                              hint      : 'Enter your GPS tracker device ID',
                              icon      : Icons.phonelink_outlined,
                              validator : _trackingService
                                  ? _required('Device ID')
                                  : null,
                            ),
                          ),

                        const Divider(height: 20),

                        // Seat Booking toggle
                        _toggleRow(
                          icon     : Icons.event_seat_outlined,
                          label    : 'Seat Booking',
                          subtitle : 'Allow passengers to reserve seats',
                          value    : _bookingService,
                          onChanged: (v) =>
                              setState(() => _bookingService = v),
                        ),

                        // Conditional: Window + Normal seats
                        if (_bookingService)
                          _conditionalBox(
                            child: Row(
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
                                    validator: _bookingService
                                        ? _required('Window seats')
                                        : null,
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
                                    validator: _bookingService
                                        ? _required('Normal seats')
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const Divider(height: 20),

                        // Other toggle
                        _toggleRow(
                          icon     : Icons.directions_bus_filled_outlined,
                          label    : 'Other',
                          subtitle : 'Staff service / school service',
                          value    : _otherService,
                          onChanged: (v) => setState(() {
                            _otherService     = v;
                            if (!v) _otherServiceType = null;
                          }),
                          isLast   : true,
                        ),

                        // Conditional: Service type chips
                        if (_otherService)
                          _conditionalBox(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.list_alt_outlined,
                                      color: _darkBlue,
                                      size : 14,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Select service type',
                                      style: TextStyle(
                                        fontSize  : 12,
                                        fontWeight: FontWeight.w600,
                                        color     : _darkBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing   : 8,
                                  runSpacing: 8,
                                  children  : _otherServiceTypes.map((type) {
                                    final selected = _otherServiceType == type;
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => _otherServiceType = type,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical  : 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color : selected
                                              ? _darkBlue
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: selected
                                                ? _darkBlue
                                                : Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              type == 'Staff Service'
                                                  ? Icons
                                                      .business_center_outlined
                                                  : Icons.school_outlined,
                                              size : 16,
                                              color: selected
                                                  ? Colors.white
                                                  : _darkBlue,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              type,
                                              style: TextStyle(
                                                fontSize  : 13,
                                                fontWeight: FontWeight.w600,
                                                color     : selected
                                                    ? Colors.white
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (_otherService &&
                                    _otherServiceType == null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Please select a service type',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color   : Colors.red.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Approval note ────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color       : _darkBlue.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.pending_actions,
                            color: _darkBlue,
                            size : 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your registration will be pending admin approval. '
                              'Services go live only after the admin reviews and approves your bus.',
                              style: TextStyle(
                                fontSize: 13,
                                color   : Colors.grey.shade800,
                                height  : 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Submit button ────────────────────────────────
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor        : _yellow,
                        foregroundColor        : Colors.black,
                        disabledBackgroundColor: _yellow.withOpacity(0.5),
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
                                Icon(Icons.check_circle_outline),
                                SizedBox(width: 8),
                                Text(
                                  'Submit Registration',
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

  // ── Service route card (shown when Other is ON) ──────────────────────
  Widget _serviceRouteCard() {
    return Container(
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border      : Border.all(color: _darkBlue, width: 1.5),
        boxShadow   : [
          BoxShadow(
            color : _darkBlue.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color       : _darkBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                (_otherServiceType ?? 'Other Service').toUpperCase(),
                style: const TextStyle(
                  color        : Colors.white,
                  fontSize     : 10,
                  fontWeight   : FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                    Icons.route_outlined, color: _darkBlue, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Service Details',
                  style: TextStyle(
                    fontSize  : 13,
                    fontWeight: FontWeight.bold,
                    color     : _darkBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Service Name
            TextFormField(
              controller: _serviceNameController,
              decoration: _inputDeco(
                'Service Name',
                'e.g., Kandy Office Staff Bus',
                Icons.label_outline,
              ),
              validator: _otherService ? _required('Service name') : null,
            ),

            const SizedBox(height: 6),

            // Hint box
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color       : _yellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Passengers will search this name to find and track your bus.',
                      style: TextStyle(
                        fontSize: 11,
                        color   : Colors.grey.shade700,
                        height  : 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // From
            TextFormField(
              controller: _fromController,
              decoration: _inputDeco(
                'From', 'Starting location', Icons.trip_origin,
              ),
              validator: _otherService
                  ? _required('Starting location')
                  : null,
            ),

            const SizedBox(height: 12),

            // Arrow
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _darkBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_downward,
                  color: _darkBlue,
                  size : 18,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // To
            TextFormField(
              controller: _toController,
              decoration: _inputDeco(
                'To', 'Destination', Icons.location_on_outlined,
              ),
              validator: _otherService
                  ? _required('Destination')
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable widgets ─────────────────────────────────────────────────

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

  Widget _conditionalBox({required Widget child}) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve   : Curves.easeInOut,
      child   : Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF00458C).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: const Border(
            left: BorderSide(color: _darkBlue, width: 3),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _toggleRow({
    required IconData           icon,
    required String             label,
    required String             subtitle,
    required bool               value,
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
    required TextEditingController  controller,
    required String                 label,
    required String                 hint,
    required IconData               icon,
    TextInputType                   keyboardType    = TextInputType.text,
    List<TextInputFormatter>?       inputFormatters,
    String? Function(String?)?      validator,
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

  String? Function(String?) _required(String name) =>
      (v) => (v == null || v.trim().isEmpty)
          ? 'Please enter $name'
          : null;
}