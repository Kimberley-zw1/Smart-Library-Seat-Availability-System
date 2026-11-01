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
      LibrarianOccupancyScreen(onNavigateTab: _onTabTapped),
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

            // Quick Actions 2-in-a-row Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _buildQuickActionCard(
                  icon: Icons.chair_rounded,
                  iconColor: primaryRed,
                  label: 'Manage Seats',
                  bgColor: cardBgColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const LibrarianManageSeatsScreen(),
                      ),
                    );
                  },
                ),
                _buildQuickActionCard(
                  icon: Icons.bar_chart_rounded,
                  iconColor: Colors.blue.shade600,
                  label: 'View Occupancy',
                  bgColor: cardBgColor,
                  onTap: () => onNavigateTab(1),
                ),
                _buildQuickActionCard(
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
                _buildQuickActionCard(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFFDCA134),
                  label: 'Send Alert',
                  bgColor: cardBgColor,
                  onTap: () => onNavigateTab(2),
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
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: iconColor),
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

// -------------------------------------------------------------
// NEW: Librarian Manage Seats Screen
// -------------------------------------------------------------
class LibrarianManageSeatsScreen extends StatefulWidget {
  const LibrarianManageSeatsScreen({super.key});

  @override
  State<LibrarianManageSeatsScreen> createState() =>
      _LibrarianManageSeatsScreenState();
}

class _LibrarianManageSeatsScreenState
    extends State<LibrarianManageSeatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _getFloorLabel(dynamic floorValue) {
    if (floorValue == null) return 'Ground Floor';
    final String str = floorValue.toString().trim();
    if (str == '0') return 'Ground Floor';
    if (str == '1') return 'First Floor';
    if (str.toLowerCase().contains('first')) return 'First Floor';
    if (str.toLowerCase().contains('ground')) return 'Ground Floor';
    return str;
  }

  void _showSeatOptionsModal(BuildContext context, DocumentSnapshot seatDoc) {
    const primaryRed = Color(0xFFC01A32);
    final data = seatDoc.data() as Map<String, dynamic>;
    final seatNumber = seatDoc.id.toUpperCase();
    final bool isOutOfOrder = data['isOutOfOrder'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Seat $seatNumber',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Floor: ${_getFloorLabel(data['floor'])}\nStatus: ${isOutOfOrder ? "Out of Order" : (data['isOccupied'] == true ? "Occupied" : "Available")}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF7E8494)),
              ),
              const SizedBox(height: 24),
              if (!isOutOfOrder)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('seats')
                          .doc(seatDoc.id)
                          .update({'isOutOfOrder': true});
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Seat $seatNumber marked as Out of Order',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.block_rounded, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    label: const Text(
                      'Mark as Out of Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('seats')
                          .doc(seatDoc.id)
                          .update({'isOutOfOrder': false});
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Out of Order mark removed'),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2EC4B6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    label: const Text(
                      'Remove Out of Order Mark',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: primaryRed,
            size: 26,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Manage Seats',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search seat number (e.g. G-01)...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF7E8494),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9F9FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Seats List Categorized by Floor
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
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
                        'No seats found in database.',
                        style: TextStyle(color: Color(0xFF7E8494)),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  // Filter by search query if any
                  final filteredDocs = docs.where((doc) {
                    final seatId = doc.id.toLowerCase();
                    return seatId.contains(_searchQuery);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No matching seats found.',
                        style: TextStyle(color: Color(0xFF7E8494)),
                      ),
                    );
                  }

                  // Group by Floor
                  Map<String, List<QueryDocumentSnapshot>> floorsMap = {};
                  for (var doc in filteredDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final floor = _getFloorLabel(data['floor']);
                    if (!floorsMap.containsKey(floor)) {
                      floorsMap[floor] = [];
                    }
                    floorsMap[floor]!.add(doc);
                  }

                  final floors = floorsMap.keys.toList()..sort();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    itemCount: floors.length,
                    itemBuilder: (context, index) {
                      final floorName = floors[index];
                      final floorSeats = floorsMap[floorName]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              floorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryRed,
                              ),
                            ),
                          ),
                          ...floorSeats.map((seatDoc) {
                            final data = seatDoc.data() as Map<String, dynamic>;
                            final seatNum = seatDoc.id.toUpperCase();
                            final bool isOccupied = data['isOccupied'] == true;
                            final bool isOutOfOrder =
                                data['isOutOfOrder'] == true;

                            Color statusColor = const Color(0xFF2EC4B6);
                            String statusText = 'Available';

                            if (isOutOfOrder) {
                              statusColor = Colors.grey;
                              statusText = 'Out of Order';
                            } else if (isOccupied) {
                              statusColor = primaryRed;
                              statusText = 'Occupied';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: cardBorderColor,
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                onTap: () =>
                                    _showSeatOptionsModal(context, seatDoc),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.chair_rounded,
                                    color: statusColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'Seat $seatNum',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Text(
                                  'Status: $statusText',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Color(0xFF7E8494),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
