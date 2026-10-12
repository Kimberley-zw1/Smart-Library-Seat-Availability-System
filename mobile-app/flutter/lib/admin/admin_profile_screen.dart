import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_home_screen.dart';
import 'admin_alerts_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_reports_screen.dart';
import '../shared/general_login_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  int _currentIndex = 4; // Profile tab selected

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    Widget targetScreen;
    switch (index) {
      case 0:
        targetScreen = const AdminHomeScreen();
        break;
      case 1:
        targetScreen = const AdminAlertsScreen();
        break;
      case 2:
        targetScreen = const AdminOverviewScreen();
        break;
      case 3:
        targetScreen = const AdminReportsScreen();
        break;
      case 4:
        return;
      default:
        return;
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => targetScreen));
  }

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const GeneralLoginScreen(role: 'admin'),
      ),
      (route) => false,
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'admin@africau.edu';
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
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset email sent successfully.'),
                    backgroundColor: Color(0xFFC82333),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: const Color(0xFFC82333),
                  ),
                );
              }
            },
            child: const Text(
              'Send',
              style: TextStyle(
                color: Color(0xFFC82333),
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
    const primaryRed = Color(0xFFC82333);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryRed),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: currentUser != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              String name = currentUser?.displayName ?? 'Admin';
              String email = currentUser?.email ?? 'admin@africau.edu';
              String roleTitle = 'Administrator';

              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  name = data['fullName'] ?? name;
                  email = data['email'] ?? email;
                  final r = (data['role'] ?? 'admin').toString();
                  roleTitle = r[0].toUpperCase() + r.substring(1);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  // Profile Picture Avatar
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: const Color(0xFFF3E8E9),
                    child: Icon(
                      Icons.person,
                      size: 72,
                      color: Colors.blueGrey.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Role
                  Text(
                    roleTitle,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    email,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 32),

                  // Option Buttons with Matching Icons
                  _buildMenuButton(
                    title: 'Personal Information',
                    icon: Icons.badge_outlined,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logged in as $name ($email)')),
                      );
                    },
                    color: primaryRed,
                  ),
                  const SizedBox(height: 14),
                  _buildMenuButton(
                    title: 'Change Password',
                    icon: Icons.lock_outline_rounded,
                    onPressed: () => _showChangePasswordDialog(context),
                    color: primaryRed,
                  ),
                  const SizedBox(height: 14),
                  _buildMenuButton(
                    title: 'App Settings',
                    icon: Icons.settings_outlined,
                    onPressed: () {
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
                  const SizedBox(height: 14),
                  _buildMenuButton(
                    title: 'Help & Support',
                    icon: Icons.help_outline_rounded,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Admin Support'),
                          content: const Text(
                            'For system escalations, contact IT Services at africau.edu.',
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
                  const SizedBox(height: 14),
                  _buildMenuButton(
                    title: 'Log Out',
                    icon: Icons.logout_rounded,
                    onPressed: () => _handleLogout(context),
                    color: Colors.black87,
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1.0)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryRed,
          unselectedItemColor: Colors.grey.shade600,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              activeIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
              label: 'Overview',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_drive_file_outlined),
              activeIcon: Icon(Icons.insert_drive_file_rounded),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
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
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
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
}
