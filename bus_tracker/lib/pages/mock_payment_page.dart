import 'dart:math';
import 'package:flutter/material.dart';

/// Pricing constants – adjust as needed
const double kWindowSeatPrice = 350.0; // LKR
const double kNormalSeatPrice = 250.0; // LKR

class MockPaymentPage extends StatefulWidget {
  final String route;
  final String busNumber;
  final String travelDate;
  final int windowSeats;
  final int normalSeats;
  final String passengerName;
  final String contactNo;

  const MockPaymentPage({
    super.key,
    required this.route,
    required this.busNumber,
    required this.travelDate,
    required this.windowSeats,
    required this.normalSeats,
    required this.passengerName,
    required this.contactNo,
  });

  @override
  State<MockPaymentPage> createState() => _MockPaymentPageState();
}

class _MockPaymentPageState extends State<MockPaymentPage> {
  final _cardNumberController = TextEditingController(text: '4111 1111 1111 1111');
  final _expiryController     = TextEditingController(text: '12/28');
  final _cvvController        = TextEditingController(text: '123');
  final _cardHolderController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isProcessing = false;
  String _selectedMethod = 'card'; // 'card' | 'qr'

  @override
  void initState() {
    super.initState();
    _cardHolderController.text = widget.passengerName;
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  double get _totalAmount =>
      (widget.windowSeats * kWindowSeatPrice) +
      (widget.normalSeats * kNormalSeatPrice);

  String _generatePaymentRef() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return 'PAY-${List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join()}';
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == 'card' && !_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    // Simulate a 2-second payment gateway delay
    await Future.delayed(const Duration(seconds: 2));

    final paymentRef = _generatePaymentRef();

    setState(() => _isProcessing = false);

    if (!mounted) return;

    // Return the payment reference to the booking page
    Navigator.of(context).pop(paymentRef);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFFfec205),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,  // clean light background
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Order Summary ─────────────────────────────────────────
                _buildSummaryCard(),
                const SizedBox(height: 20),

                // ── Payment Method Selector ───────────────────────────────
                _buildMethodSelector(),
                const SizedBox(height: 20),

                // ── Payment Form ──────────────────────────────────────────
                if (_selectedMethod == 'card') _buildCardForm(),
                if (_selectedMethod == 'qr')   _buildQrSection(),
                const SizedBox(height: 30),

                // ── Pay Button ────────────────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFfec205),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 4,
                    ),
                    onPressed: _isProcessing ? null : _processPayment,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2.5))
                        : Text(
                            'Pay LKR ${_totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Secure Mock Payment Gateway',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
    );
  }

  // ── Summary Card ──────────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Booking Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _summaryRow('Route', widget.route),
            _summaryRow('Bus', widget.busNumber),
            _summaryRow('Date', widget.travelDate),
            _summaryRow('Passenger', widget.passengerName),
            const Divider(height: 20),
            if (widget.windowSeats > 0)
              _summaryRow(
                'Window × ${widget.windowSeats}',
                'LKR ${(widget.windowSeats * kWindowSeatPrice).toStringAsFixed(2)}',
              ),
            if (widget.normalSeats > 0)
              _summaryRow(
                'Normal × ${widget.normalSeats}',
                'LKR ${(widget.normalSeats * kNormalSeatPrice).toStringAsFixed(2)}',
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(
                  'LKR ${_totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFd4a000)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ],
        ),
      );

  // ── Method Selector ───────────────────────────────────────────────────────
  Widget _buildMethodSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _methodButton('card', Icons.credit_card, 'Card')),
            const SizedBox(width: 8),
            Expanded(child: _methodButton('qr', Icons.qr_code, 'QR / Scan')),
          ],
        ),
      ),
    );
  }

  Widget _methodButton(String value, IconData icon, String label) {
    final selected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFfec205) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFfec205) : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.black : Colors.grey.shade500,
                size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.black : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ── Card Form ─────────────────────────────────────────────────────────────
  Widget _buildCardForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Card Details',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cardHolderController,
                decoration: const InputDecoration(
                  labelText: 'Cardholder Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter cardholder name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                validator: (v) =>
                    (v == null || v.length < 16) ? 'Enter valid card number' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Expiry (MM/YY)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 3) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a mock payment. No real charge will be made.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── QR Section ────────────────────────────────────────────────────────────
  Widget _buildQrSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Scan to Pay',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Mock QR placeholder
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 100, color: Colors.black87),
                  SizedBox(height: 8),
                  Text('MOCK QR',
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'LKR ${_totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFd4a000)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "Pay" below after scanning',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}