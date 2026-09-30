import 'package:flutter/material.dart';

class LibrarianHomeScreen extends StatefulWidget {
  const LibrarianHomeScreen({super.key});

  @override
  State<LibrarianHomeScreen> createState() => _LibrarianHomeScreenState();
}

class _LibrarianHomeScreenState extends State<LibrarianHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const softPinkFill = Color(0xFFFFF0F2);
    const cardBgColor = Color(0xFFFAF8F8);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Back Arrow
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: primaryRed,
                  size: 26,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),

              const SizedBox(height: 16),

              // Header Row: Greeting & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Hello, Mr. Moyo 👋',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Main Library Overview',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF7E8494),
                        ),
                      ),
                    ],
                  ),
                  // Open Status Badge
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
              ),

              const SizedBox(height: 28),

              // Live Seats Card
              Container(
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
                        _buildStatColumn('1', 'Occupied', primaryRed),
                        _buildStatColumn(
                          '3',
                          'Available',
                          const Color(0xFF2EC4B6),
                        ),
                        _buildStatColumn('4', 'Total Capacity', Colors.black87),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions Section Title
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              // Quick Action Grid Cards
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.bar_chart_rounded,
                      iconColor: Colors.blue.shade600,
                      label: 'View Occupancy',
                      bgColor: cardBgColor,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.access_time_filled_rounded,
                      iconColor: Colors.grey.shade600,
                      label: 'Closing Check',
                      bgColor: cardBgColor,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.notifications_active_rounded,
                      iconColor: const Color(0xFFDCA134),
                      label: 'Send Alert',
                      bgColor: cardBgColor,
                      onTap: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
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
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
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
              icon: Icon(Icons.account_balance_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              label: 'Occupancy',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label, Color countColor) {
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 105,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
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
