import 'package:flutter/material.dart';
import 'otp_verification_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  String? _selectedRole;

  void _navigateToOtpPage(String role) {
    setState(() => _selectedRole = role);

    // Small delay for visual feedback before navigation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(selectedRole: role),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Welcome message
              const Text(
                'Welcome to RouteLK',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00458C),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Select your role to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 50),

              // Section label
              const Text(
                'Choose Your Role',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00458C),
                ),
              ),

              const SizedBox(height: 24),

              // Role cards
              Expanded(
                child: ListView(
                  children: [
                    _buildRoleCard(
                      title: 'Passenger',
                      subtitle: 'Track and book bus rides',
                      icon: Icons.person_outline,
                      isSelected: _selectedRole == 'Passenger',
                      onTap: () => _navigateToOtpPage('Passenger'),
                    ),
                    const SizedBox(height: 20),
                    _buildRoleCard(
                      title: 'Driver',
                      subtitle: 'Drive and manage your routes',
                      icon: Icons.drive_eta_outlined,
                      isSelected: _selectedRole == 'Driver',
                      onTap: () => _navigateToOtpPage('Driver'),
                    ),
                    const SizedBox(height: 20),
                    _buildRoleCard(
                      title: 'Bus Operator',
                      subtitle: 'Manage your fleet and operations',
                      icon: Icons.directions_bus_outlined,
                      isSelected: _selectedRole == 'Bus Operator',
                      onTap: () => _navigateToOtpPage('Bus Operator'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: Card(
        elevation: isSelected ? 8 : 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFfec205)
                      : const Color(0xFF00458C),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 28, color: Colors.white),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              if (isSelected)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00458C),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
