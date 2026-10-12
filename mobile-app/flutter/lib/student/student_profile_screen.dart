import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';
import 'floor_selection_screen.dart';
import 'student_alerts.dart';
import '../shared/general_login_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const GeneralLoginScreen(role: 'student'),
      ),
      (route) => false,
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Send a password reset link to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset email sent successfully.'),
                    backgroundColor: Color(0xFFC01A32),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: const Color(0xFFC01A32),
                  ),
                );
              }
            },
            child: const Text(
              'Send',
              style: TextStyle(
                color: Color(0xFFC01A32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Top Header: Back Arrow & Profile Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: primaryRed,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profile Avatar & Dynamic User Details Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Avatar Circle
                    Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3ECEC),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 90,
                          color: Color(0xFF4B82AA),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dynamic User StreamBuilder
                    StreamBuilder<DocumentSnapshot>(
                      stream: currentUser != null
                          ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        String name = 'Student';
                        String studentId = 'N/A';
                        String email = currentUser?.email ?? 'N/A';

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          if (data != null) {
                            name = data['fullName'] ?? data['name'] ?? name;
                            studentId =
                                data['studentId'] ??
                                data['studentID'] ??
                                data['id'] ??
                                'N/A';
                            email = data['email'] ?? email;
                          }
                        } else if (currentUser?.displayName != null &&
                            currentUser!.displayName!.isNotEmpty) {
                          name = currentUser.displayName!;
                        }

                        return Column(
                          children: [
                            // Student Name
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 4),

                            // Student ID
                            Text(
                              'Student ID: $studentId',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8C919E),
                                fontWeight: FontWeight.w400,
                              ),
                            ),

                            const SizedBox(height: 2),

                            // Student Email
                            Text(
                              'Email: $email',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8C919E),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // Action Buttons List with Icons
                    _buildMenuButton(
                      title: 'Change Password',
                      icon: Icons.lock_outline_rounded,
                      onTap: () => _showChangePasswordDialog(context),
                      color: primaryRed,
                    ),

                    const SizedBox(height: 16),

                    _buildMenuButton(
                      title: 'App Settings',
                      icon: Icons.settings_outlined,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'System is running on latest build version.',
                            ),
                          ),
                        );
                      },
                      color: primaryRed,
                    ),

                    const SizedBox(height: 16),

                    _buildMenuButton(
                      title: 'Help & Support',
                      icon: Icons.help_outline_rounded,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Student Support'),
                            content: const Text(
                              'For library seat assistance, contact IT Services at africau.edu.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'OK',
                                  style: TextStyle(color: primaryRed),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      color: primaryRed,
                    ),

                    const SizedBox(height: 16),

                    _buildMenuButton(
                      title: 'Log Out',
                      icon: Icons.logout_rounded,
                      onTap: () => _handleLogout(context),
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFEEEEEE), width: 1.0),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: false,
                    onTap: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.map_outlined,
                    label: 'Map',
                    isSelected: false,
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const FloorSelectionScreen(),
                        ),
                      );
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.notifications_rounded,
                    label: 'Alerts',
                    isSelected: false,
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const StudentAlerts(),
                        ),
                      );
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    isSelected: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Menu Button Widget with Icons
  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  // Navigation Bar Item Widget
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const primaryRed = Color(0xFFC01A32);
    const unselectedColor = Color(0xFF8E8E93);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryRed : unselectedColor,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? primaryRed : unselectedColor,
            ),
          ),
        ],
      ),
    );
  }
}
