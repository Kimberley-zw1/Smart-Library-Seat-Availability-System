import 'package:flutter/material.dart';

import '../student/student_login_screen.dart';
import '../librarian/librarian_login_screen.dart';
import '../admin/admin_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _selectRole(BuildContext context, String role) {
    Widget targetScreen;

    if (role == 'Student') {
      targetScreen = const StudentLoginScreen();
    } else if (role == 'Librarian') {
      targetScreen = const LibrarianLoginScreen();
    } else {
      targetScreen = const AdminLoginScreen();
    }

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => targetScreen));
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

              // Header Book Graphic
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 65,
                  color: Colors.blue.shade600,
                ),
              ),

              const SizedBox(height: 28),

              // Header Title
              const Text(
                'Welcome to Smart Library',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Prompt Text
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'I am a.....',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5A6275),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Role Buttons
              _buildRoleButton(
                context: context,
                label: 'Student',
                icon: Icons.school_rounded,
                color: primaryRed,
                onPressed: () => _selectRole(context, 'Student'),
              ),

              const SizedBox(height: 16),

              _buildRoleButton(
                context: context,
                label: 'Librarian',
                icon: Icons.collections_bookmark_rounded,
                color: primaryRed,
                onPressed: () => _selectRole(context, 'Librarian'),
              ),

              const SizedBox(height: 16),

              _buildRoleButton(
                context: context,
                label: 'Administrator',
                icon: Icons.settings_rounded,
                color: primaryRed,
                onPressed: () => _selectRole(context, 'Administrator'),
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
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.white),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}
