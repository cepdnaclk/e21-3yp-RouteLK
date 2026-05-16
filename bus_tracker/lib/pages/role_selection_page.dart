import 'package:flutter/material.dart';
import 'bus_registration_page.dart';
import 'driver_home_page.dart';
import 'login_page.dart';
import 'passenger_home_page.dart';
import 'user_registration_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final _nameController = TextEditingController();
  String? _selectedRole;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
    });
  }

  void _openSignUp() {
    final role = _selectedRole;
    if (role == null) return;

    if (role == 'Passenger') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserRegistrationPage()),
      );
      return;
    }

    _openRoleDestination(role);
  }

  void _openSignIn() {
    final role = _selectedRole;
    if (role == null) return;

    if (role == 'Passenger') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    _openRoleDestination(role);
  }

  void _openRoleDestination(String role) {
    final displayName = _nameController.text.trim().isEmpty
        ? role
        : _nameController.text.trim();

    switch (role) {
      case 'Driver':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverHomePage(userName: displayName),
          ),
        );
        break;
      case 'Bus Operator':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BusRegistrationPage()),
        );
        break;
      case 'Passenger':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PassengerHomePage(userName: displayName),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = _selectedRole;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
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
              const SizedBox(height: 30),

              _buildRoleCard(
                title: 'Passenger',
                subtitle: 'Track and book bus rides',
                icon: Icons.person_outline,
                isSelected: selectedRole == 'Passenger',
                onTap: () => _selectRole('Passenger'),
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                title: 'Driver',
                subtitle: 'Drive and manage your routes',
                icon: Icons.drive_eta_outlined,
                isSelected: selectedRole == 'Driver',
                onTap: () => _selectRole('Driver'),
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                title: 'Bus Operator',
                subtitle: 'Manage your fleet and operations',
                icon: Icons.directions_bus_outlined,
                isSelected: selectedRole == 'Bus Operator',
                onTap: () => _selectRole('Bus Operator'),
              ),

              const SizedBox(height: 22),

              if (selectedRole != null && selectedRole != 'Passenger') ...[
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter your name',
                    prefixIcon: const Icon(Icons.person_outline),
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
                        color: Color(0xFFfec205),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _openRoleDestination(selectedRole),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFfec205),
                      foregroundColor: const Color(0xFF00458C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],

              if (selectedRole == 'Passenger') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _openSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFfec205),
                      foregroundColor: const Color(0xFF00458C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _openSignIn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00458C),
                      side: const BorderSide(color: Color(0xFF00458C)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Passenger accounts use AWS Cognito authentication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
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
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 8 : 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFfec205) : const Color(0xFF00458C),
                  shape: BoxShape.circle,
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
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? const Color(0xFFfec205) : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
