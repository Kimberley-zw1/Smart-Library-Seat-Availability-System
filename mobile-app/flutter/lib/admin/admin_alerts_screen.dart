import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_home_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_profile_screen.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  int _currentIndex = 1; // Alerts tab selected

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    Widget targetScreen;
    switch (index) {
      case 0:
        targetScreen = const AdminHomeScreen();
        break;
      case 1:
        return; // Already on Alerts
      case 2:
        targetScreen = const AdminOverviewScreen();
        break;
      case 3:
        targetScreen = const AdminReportsScreen();
        break;
      case 4:
        targetScreen = const AdminProfileScreen();
        break;
      default:
        return;
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => targetScreen));
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);

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
          'Alerts & Staff Activity',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Header Subtitle
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Live platform events',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8C919E),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Real-Time Events List from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('admin_alerts')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryRed),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No live platform events yet.',
                        style: TextStyle(
                          color: Color(0xFF8C919E),
                          fontSize: 15,
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final String title = data['title'] ?? '';
                      final String type = data['type'] ?? 'system';
                      final Timestamp? timestamp =
                          data['timestamp'] as Timestamp?;
                      final String timeString = _formatTimestamp(timestamp);

                      // Determine icon and color style based on event type
                      IconData iconData = Icons.notifications_rounded;
                      Color iconColor = const Color(0xFFDCA134);
                      Color avatarBg = const Color(0xFFFEF3DF);

                      if (type == 'user') {
                        iconData = Icons.person;
                        iconColor = const Color(0xFF6B8096);
                        avatarBg = const Color(0xFFFDE8E9);
                      } else if (type == 'warning') {
                        iconData = Icons.warning_rounded;
                        iconColor = Colors.black87;
                        avatarBg = const Color(0xFFFEF3DF);
                      }

                      return Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cardBorderColor,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar / Icon Badge
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: avatarBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(iconData, color: iconColor, size: 24),
                            ),

                            const SizedBox(width: 14),

                            // Title & Time Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    timeString,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF9E9E9E),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
          unselectedItemColor: const Color(0xFF9E9E9E),
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
}
