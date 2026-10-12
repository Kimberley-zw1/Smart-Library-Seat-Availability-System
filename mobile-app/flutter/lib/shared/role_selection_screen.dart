import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'general_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _selectRole(BuildContext context, String role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => GeneralLoginScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Header Graphic Container matching Login Screen style
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 50,
                    color: primaryRed,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Header Title
              const Text(
                'Welcome to Smart Library',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please select your user role to continue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),

              const SizedBox(height: 36),

              // Prompt Text
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'I am a...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Role Buttons
              _buildRoleButton(
                context: context,
                label: 'Student',
                icon: Icons.school_rounded,
                color: primaryRed,
                onPressed: () => _selectRole(context, 'student'),
              ),

              const SizedBox(height: 16),

              _buildRoleButton(
                context: context,
                label: 'Librarian',
                icon: Icons.collections_bookmark_rounded,
                color: primaryRed,
                onPressed: () => _selectRole(context, 'librarian'),
              ),

              const SizedBox(height: 16),

              _buildRoleButton(
                context: context,
                label: 'Administrator',
                icon: Icons.settings_rounded,
                color: primaryRed,
                onPressed: () => _selectRole(context, 'admin'),
              ),

              const SizedBox(height: 16),

              // Exit App Button
              _buildRoleButton(
                context: context,
                label: 'Exit',
                icon: Icons.power_settings_new_rounded,
                color: Colors.black87,
                onPressed: () => SystemNavigator.pop(),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.white),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}
