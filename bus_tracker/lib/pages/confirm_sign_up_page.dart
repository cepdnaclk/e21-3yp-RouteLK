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

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }
}
