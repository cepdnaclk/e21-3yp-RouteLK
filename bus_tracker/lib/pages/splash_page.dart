import 'package:flutter/material.dart';
import 'dart:async';
import 'role_selection_page.dart';

/// Splash screen with app logo
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Navigate to role selection page after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Blue background (theme color)
      backgroundColor: const Color(0xFFfec205),

      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Logo
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),


<<<<<<< Updated upstream
              const SizedBox(height: 40),

              // Tagline
              const Text(
                'Track Your Bus. Save Your Time.',
                style: TextStyle(
                  fontSize: 20,
                  color: Color(0xFF00458C),
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
=======
                // Tagline
                const Text(
                  'Track Your Bus. Save Your Time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00458C),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
>>>>>>> Stashed changes
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
