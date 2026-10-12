import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'student_profile_screen.dart';
import 'floor_selection_screen.dart';
import 'student_alerts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Home selected

  // Helper method to handle reservation cancellation with notification logging
  Future<void> _cancelReservation(String userId, String? seatNumber) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Delete user reservation record
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(userId);
      batch.delete(reservationRef);

      // 2. Reset seat availability in seats collection
      if (seatNumber != null && seatNumber.isNotEmpty) {
        final seatRef = FirebaseFirestore.instance
            .collection('seats')
            .doc(seatNumber);
        batch.set(seatRef, {'isOccupied': false}, SetOptions(merge: true));
      }

      // 3. Add cancellation entry to user's notifications history subcollection
      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(); // Auto-generate unique ID

      batch.set(notificationRef, {
        'title': 'Reservation Cancelled',
        'message': seatNumber != null && seatNumber.isNotEmpty
            ? 'Your reservation for seat $seatNumber has been cancelled.'
            : 'Your seat reservation has been cancelled.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation cancelled successfully.'),
          backgroundColor: Color(0xFFC01A32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel reservation: $e'),
          backgroundColor: const Color(0xFFC01A32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Header Row: Greeting (Back button removed)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: currentUser != null
                          ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        String name = 'Student';
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          if (data != null && data['fullName'] != null) {
                            name = (data['fullName'] as String)
                                .split(' ')
                                .first;
                          }
                        } else if (currentUser?.displayName != null &&
                            currentUser!.displayName!.isNotEmpty) {
                          name = currentUser.displayName!.split(' ').first;
                        }

                        return Text(
                          'Hello $name 👋',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: primaryRed,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Subtitle
              const Padding(
                padding: EdgeInsets.only(left: 0.0),
                child: Text(
                  'Find an available seat and enjoy your study time!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C757D),
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Real-Time Seat Availability Card (Filtered with isOccupied)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
                    .snapshots(),
                builder: (context, snapshot) {
                  int totalSeats = 0;
                  int availableSeats = 0;
                  bool isLoading =
                      snapshot.connectionState == ConnectionState.waiting;

                  if (snapshot.hasData && snapshot.data != null) {
                    final docs = snapshot.data!.docs;
                    totalSeats = docs.length;

                    // Seats are available if isOccupied is false
                    availableSeats = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isOccupied = data['isOccupied'] as bool? ?? false;
                      return !isOccupied;
                    }).length;
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28.0,
                      horizontal: 20.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFF0F0F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryRed.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.account_balance_rounded,
                              color: Color(0xFF8B7E74),
                              size: 32,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Main Library',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: primaryRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isLoading)
                          const SizedBox(
                            height: 36,
                            width: 36,
                            child: CircularProgressIndicator(
                              color: primaryRed,
                              strokeWidth: 3,
                            ),
                          )
                        else
                          Text(
                            '$availableSeats',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              height: 1.0,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          isLoading
                              ? 'Fetching live seat data...'
                              : 'of ${totalSeats == 0 ? 4 : totalSeats} seats available',
                          style: const TextStyle(
                            fontSize: 15,
                            color: primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Real-Time Active Reservation Card
              StreamBuilder<DocumentSnapshot>(
                stream: currentUser != null
                    ? FirebaseFirestore.instance
                          .collection('reservations')
                          .doc(currentUser.uid)
                          .snapshots()
                    : null,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(color: primaryRed),
                      ),
                    );
                  }

                  if (snapshot.hasData &&
                      snapshot.data != null &&
                      snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryRed.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.bookmark_added_rounded,
                                    color: primaryRed,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Your Reserved Seat',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    data['seatNumber'] ?? 'A1',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: primaryRed,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['sectionName'] ??
                                          'Main Reading Floor',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Account: ${data['userEmail'] ?? currentUser?.email}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6C757D),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () {
                                if (currentUser != null) {
                                  _cancelReservation(
                                    currentUser.uid,
                                    data['seatNumber'] as String?,
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryRed,
                                side: const BorderSide(
                                  color: primaryRed,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Cancel Reservation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Default state when no active reservation exists
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF0F3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.event_seat_rounded,
                            color: primaryRed,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Active Reservation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Find and reserve a study seat around campus.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6C757D),
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

              const SizedBox(height: 28),

              // Action Cards (View Library & Notifications)
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      title: 'View Library',
                      icon: Icons.menu_book_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      bgColor: const Color(0xFFEFF6FF),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const FloorSelectionScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      title: 'Notifications',
                      icon: Icons.notifications_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      bgColor: const Color(0xFFFFFBEB),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const StudentAlerts(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 1.0)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex) return;

            setState(() {
              _currentIndex = index;
            });

            switch (index) {
              case 0:
                // Already on Home
                break;
              case 1:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FloorSelectionScreen(),
                  ),
                );
                break;
              case 2:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StudentAlerts(),
                  ),
                );
                break;
              case 3:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StudentProfileScreen(),
                  ),
                );
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryRed,
          unselectedItemColor: const Color(0xFF9CA3AF),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
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

  // Action Card Builder
  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 130,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 38, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
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
