import 'package:flutter/material.dart';

import 'first_floor_screen.dart';
import 'ground_floor_screen.dart';

class FloorSelectionScreen extends StatefulWidget {
  const FloorSelectionScreen({super.key});

  @override
  State<FloorSelectionScreen> createState() => _FloorSelectionScreenState();
}

class _FloorSelectionScreenState extends State<FloorSelectionScreen> {
  int _currentIndex = 1; // Map tab selected

  void _navigateToSeatMap(String floorName) {
    Widget targetScreen = floorName == 'Ground floor'
        ? const GroundFloorScreen()
        : const FirstFloorScreen();

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => targetScreen));
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardRed = Color(0xFFC81E38);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
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
                onPressed: () => Navigator.of(context).pop(),
              ),

              const SizedBox(height: 24),

              // Library Section Header
              const Text(
                'MAIN LIBRARY',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 4),

              // Main Title
              const Text(
                'Select a floor',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 6),

              // Subtitle
              const Text(
                'Choose a floor to view the seat map',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF7E8494),
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 36),

              // Ground Floor Card
              _buildFloorCard(
                title: 'Ground floor',
                subtitle: '24 seats available',
                cardColor: cardRed,
                onTap: () => _navigateToSeatMap('Ground floor'),
              ),

              const SizedBox(height: 20),

              // First Floor Card
              _buildFloorCard(
                title: 'First floor',
                subtitle: '12 seats available',
                cardColor: cardRed,
                onTap: () => _navigateToSeatMap('First floor'),
              ),

              const Spacer(),
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
            if (index == 0) {
              Navigator.of(context).pop();
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
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              label: 'Map',
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

  Widget _buildFloorCard({
    required String title,
    required String subtitle,
    required Color cardColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF911527),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8B0D21),
                size: 38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
