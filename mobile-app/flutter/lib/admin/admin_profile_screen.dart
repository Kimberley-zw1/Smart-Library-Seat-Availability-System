import 'package:flutter/material.dart';

import 'admin_home_screen.dart';
import 'admin_alerts_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_reports_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC82333);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryRed),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const AdminHomeScreen(),
                ),
              );
            }
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
          child: Column(
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
              const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),

              // Role
              Text(
                'Administrator',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),

              // Email
              Text(
                'admin@africau.edu',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 32),

              // Option Buttons
              _buildMenuButton(
                title: 'Personal Information',
                onPressed: () {},
                color: primaryRed,
              ),
              const SizedBox(height: 14),
              _buildMenuButton(
                title: 'Change Password',
                onPressed: () {},
                color: primaryRed,
              ),
              const SizedBox(height: 14),
              _buildMenuButton(
                title: 'App Settings',
                onPressed: () {},
                color: primaryRed,
              ),
              const SizedBox(height: 14),
              _buildMenuButton(
                title: 'Help & Support',
                onPressed: () {},
                color: primaryRed,
              ),
            ],
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}
