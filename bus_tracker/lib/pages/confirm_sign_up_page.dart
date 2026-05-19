import 'dart:async';
import 'package:flutter/material.dart';
import '../services/cognito_auth_service.dart';
import 'passenger_home_page.dart';

class ConfirmSignUpPage extends StatefulWidget {
  final String email;
  final String displayName;
  final CognitoAuthService authService;
  final WidgetBuilder? nextPageBuilder;

  const ConfirmSignUpPage({
    super.key,
    required this.email,
    required this.displayName,
    required this.authService,
    this.nextPageBuilder,
  });

  @override
  State<ConfirmSignUpPage> createState() => _ConfirmSignUpPageState();
}

class _ConfirmSignUpPageState extends State<ConfirmSignUpPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  int _expiryRemaining = 0; // seconds remaining until code expires
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown(420); // start 7-minute countdown when page opens
  }

  @override
  void dispose() {
    _codeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 420]) {
    _resendTimer?.cancel();
    setState(() => _expiryRemaining = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _expiryRemaining -= 1;
        if (_expiryRemaining <= 0) {
          _expiryRemaining = 0;
          _resendTimer?.cancel();
        }
      });
    });
  }

  Future<void> _resendCode() async {
    if (_expiryRemaining > 0) return; // only allow resend after expiry

    setState(() => _isLoading = true);
    try {
      await widget.authService.resendConfirmationCode(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation code resent.')),
      );
      // restart 7-minute window after resending
      _startResendCooldown(420);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to resend code: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _confirm() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final confirmed = await widget.authService.confirmSignUp(
        widget.email,
        _codeController.text.trim(),
      );

      if (!mounted) return;
      if (confirmed == true) {
        final nextPageBuilder = widget.nextPageBuilder ??
            (_) => PassengerHomePage(userName: widget.displayName);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: nextPageBuilder),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirmation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Confirmation error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text('A confirmation code was sent to ${widget.email}.'),
            const SizedBox(height: 8),
            Text(
              'If you do not see the email in your inbox, please check your spam or junk folder. Confirmation codes are time-limited; if yours expired you can request a new code.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Confirmation code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _confirm,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Confirm'),
            ),
            const SizedBox(height: 8),
            if (_expiryRemaining > 0) ...[
              Center(
                child: Text(
                  'Code expires in ${_formatTime(_expiryRemaining)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ] else ...[
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: const Text('Resend code'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
