import 'package:flutter/material.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  int _currentIndex = 1; // Alerts tab selected

  final List<Map<String, dynamic>> _activities = [
    {
      'type': 'user',
      'title': 'Mr. Moyo sent closing time alert to all floors',
      'time': '5 min ago',
      'icon': Icons.person,
      'iconColor': const Color(0xFF6B8096),
      'avatarBg': const Color(0xFFFDE8E9),
    },
    {
      'type': 'warning',
      'title': 'Seat A3 occupied past closing — First Floor',
      'time': '12 min ago',
      'icon': Icons.warning_rounded,
      'iconColor': Colors.black87,
      'avatarBg': const Color(0xFFFEF3DF),
    },
    {
      'type': 'user',
      'title': 'Ms. Ncube checked occupancy — First Floor',
      'time': '28 min ago',
      'icon': Icons.person,
      'iconColor': const Color(0xFF6B8096),
      'avatarBg': const Color(0xFFFDE8E9),
    },
    {
      'type': 'system',
      'title': 'System alert: Library closing in 30 minutes',
      'time': '45 min ago',
      'icon': Icons.notifications_rounded,
      'iconColor': const Color(0xFFDCA134),
      'avatarBg': const Color(0xFFFEF3DF),
    },
  ];

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Alerts & Staff Activity',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Live platform events',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8C919E),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Events List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                itemCount: _activities.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _activities[index];
                  return Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar / Icon Badge
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: item['avatarBg'] as Color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: item['iconColor'] as Color,
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Title & Time Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['time'] as String,
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
          onTap: (index) {
            if (index == 0) {
              Navigator.of(context).pop();
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
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
