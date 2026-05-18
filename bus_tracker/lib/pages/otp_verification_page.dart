import 'package:flutter/material.dart';
import 'dart:async';
import 'signup_page.dart';
import 'role_selection_page.dart';

/// OTP Verification Page with email input and OTP dialog
class OtpVerificationPage extends StatefulWidget {
  final String? selectedRole;

  const OtpVerificationPage({super.key, this.selectedRole});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _emailController = TextEditingController();
  bool _isEmailSubmitted = false;
  String _generatedOtp = '';
  Timer? _countdownTimer;
  int _remainingSeconds = 420; // 7 minutes in seconds
  bool _isOtpExpired = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _generateAndSendOtp() {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generate a 6-digit OTP
    _generatedOtp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
        .toString()
        .substring(0, 6);

    // In production, you would send this OTP via Firebase or email service
    print('OTP sent to $email: $_generatedOtp');

    setState(() {
      _isEmailSubmitted = true;
      _remainingSeconds = 420;
      _isOtpExpired = false;
    });

    // Show OTP dialog
    _showOtpDialog();

    // Start countdown timer
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _isOtpExpired = true;
          timer.cancel();
        }
      });
    });
  }

  void _resendOtp() {
    setState(() {
      _remainingSeconds = 420;
      _isOtpExpired = false;
    });

    // Generate new OTP
    _generatedOtp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
        .toString()
        .substring(0, 6);

    print('OTP resent to ${_emailController.text}: $_generatedOtp');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP resent successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // Restart countdown timer
    _startCountdownTimer();
  }

  void _showOtpDialog() {
    final otpController = TextEditingController();
    int attempts = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Enter OTP'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Enter the 6-digit OTP sent to\n${_emailController.text}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      // Auto-submit when 6 digits are entered
                      if (value.length == 6 && !_isOtpExpired) {
                        _verifyOtp(value, attempts, dialogContext);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 24,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFEC205),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Timer display
                  Text(
                    _isOtpExpired
                        ? 'OTP Expired'
                        : 'Expires in ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isOtpExpired ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    otpController.dispose();
                    Navigator.pop(dialogContext);
                    setState(() {
                      _isEmailSubmitted = false;
                    });
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEC205),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _isOtpExpired || otpController.text.length != 6
                      ? null
                      : () {
                          _verifyOtp(otpController.text.trim(), attempts, dialogContext);
                        },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      otpController.dispose();
      // When dialog closes
      if (_isEmailSubmitted && !_isOtpExpired) {
        // Dialog was closed without successful verification
        _countdownTimer?.cancel();
        setState(() {
          _isEmailSubmitted = false;
        });
      }
    });
  }

  void _verifyOtp(String enteredOtp, int attempts, BuildContext dialogContext) {
    attempts++;

    if (enteredOtp.isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(
          content: Text('Please enter OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (enteredOtp.length != 6) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(
          content: Text('OTP must be 6 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (enteredOtp == _generatedOtp) {
      Navigator.pop(dialogContext);
      _countdownTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP verified successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to login page after verification
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const SignupPage(),
            ),
          );
        }
      });
    } else {
      if (attempts >= 3) {
        Navigator.pop(dialogContext);
        _countdownTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Too many incorrect attempts. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isEmailSubmitted = false;
        });
      } else {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text(
                'Incorrect OTP. ${3 - attempts} attempts remaining.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTimerText() {
    if (_isOtpExpired) {
      return 'OTP has expired';
    }
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return 'Expires in $minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00458C)),
          onPressed: () {
            _countdownTimer?.cancel();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const RoleSelectionPage(),
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Title
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00458C),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Enter your email to receive an OTP',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 40),

              // Email input field
              TextField(
                controller: _emailController,
                enabled: !_isEmailSubmitted,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFEC205),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: _isEmailSubmitted
                      ? Colors.grey.shade100
                      : Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 24),

              // Role display
              if (widget.selectedRole != null) ...[
                Row(
                  children: [
                    const Text(
                      'Role: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEC205).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.selectedRole!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF00458C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              // Send OTP Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEC205),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      _isEmailSubmitted ? null : _generateAndSendOtp,
                  child: Text(
                    _isEmailSubmitted ? 'OTP Sent - Check Your Dialog' : 'Send OTP',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // OTP Status Section
              if (_isEmailSubmitted) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEC205).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFEC205),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OTP Status:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00458C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getTimerText(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _isOtpExpired ? Colors.red : Colors.orange,
                        ),
                      ),
                      if (_isOtpExpired) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00458C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _resendOtp,
                            child: const Text(
                              'Resend OTP',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Help text
              Center(
                child: Text(
                  'Didn\'t receive OTP? Check your email or resend after expiry',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
