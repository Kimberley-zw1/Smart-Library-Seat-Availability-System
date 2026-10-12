import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'librarian_occupancy_screen.dart';
import 'librarian_alerts_screen.dart';
import 'librarian_profile_screen.dart';

class LibrarianHomeScreen extends StatefulWidget {
  const LibrarianHomeScreen({super.key});

  @override
  State<LibrarianHomeScreen> createState() => _LibrarianHomeScreenState();
}

class _LibrarianHomeScreenState extends State<LibrarianHomeScreen> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);

    final List<Widget> pages = [
      LibrarianDashboardView(onNavigateTab: _onTabTapped),
      LibrarianOccupancyScreen(
        onNavigateTab: _onTabTapped,
      ), // Pass callback here
      LibrarianAlertsScreen(onNavigateTab: _onTabTapped),
      LibrarianProfileScreen(onNavigateTab: _onTabTapped),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _currentIndex, children: pages),
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
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Occupancy',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              activeIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
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

class LibrarianDashboardView extends StatelessWidget {
  final Function(int) onNavigateTab;

  const LibrarianDashboardView({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const softPinkFill = Color(0xFFFFF0F2);
    const cardBgColor = Color(0xFFFAF8F8);

    final currentUser = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: currentUser != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots()
                  : null,
              builder: (context, userSnapshot) {
                String librarianName = 'Librarian';
                if (userSnapshot.hasData &&
                    userSnapshot.data != null &&
                    userSnapshot.data!.exists) {
                  final data =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  librarianName =
                      data['name'] ??
                      data['fullName'] ??
                      currentUser?.email?.split('@').first ??
                      'Librarian';
                } else if (currentUser?.displayName != null) {
                  librarianName = currentUser!.displayName!;
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $librarianName 👋',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Main Library Overview',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF7E8494),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAFAF1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, color: Color(0xFF2EC4B6), size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Open',
                            style: TextStyle(
                              color: Color(0xFF2EC4B6),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('seats')
                  .snapshots(),
              builder: (context, snapshot) {
                int totalCapacity = 0;
                int occupiedCount = 0;

                if (snapshot.hasData && snapshot.data != null) {
                  final docs = snapshot.data!.docs;
                  totalCapacity = docs.length;

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['isOccupied'] == true) occupiedCount++;
                  }
                }

                if (totalCapacity == 0) totalCapacity = 4;
                int availableCount = totalCapacity - occupiedCount;
                if (availableCount < 0) availableCount = 0;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: softPinkFill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Main Library Live Seats',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryRed,
                            ),
                          ),
                          Icon(
                            Icons.account_balance_rounded,
                            color: Color(0xFF8B7E74),
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            occupiedCount.toString(),
                            'Occupied',
                            primaryRed,
                          ),
                          _buildStatColumn(
                            availableCount.toString(),
                            'Available',
                            const Color(0xFF2EC4B6),
                          ),
                          _buildStatColumn(
                            totalCapacity.toString(),
                            'Total Capacity',
                            Colors.black87,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.bar_chart_rounded,
                    iconColor: Colors.blue.shade600,
                    label: 'View Occupancy',
                    bgColor: cardBgColor,
                    onTap: () => onNavigateTab(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.access_time_filled_rounded,
                    iconColor: Colors.grey.shade600,
                    label: 'Closing Check',
                    bgColor: cardBgColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const LibrarianClosingCheckScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.notifications_active_rounded,
                    iconColor: const Color(0xFFDCA134),
                    label: 'Send Alert',
                    bgColor: cardBgColor,
                    onTap: () => onNavigateTab(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStatColumn(String count, String label, Color countColor) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: countColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF7E8494),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 105,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
