import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:libseat2/shared/activity_logger.dart';
import 'package:libseat2/shared/reservation_cleanup.dart';

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

  @override
  void initState() {
    super.initState();
    // Free any reservations left open past 10:15 PM so the live seat
    // numbers are correct as soon as a librarian opens the app.
    ReservationCleanup.run();
  }

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
                    // Expanded gives the name the space left beside the pill;
                    // FittedBox shrinks it slightly only if it doesn't fit.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Hello, $librarianName 👋',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
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
                    ),
                    const SizedBox(width: 12),
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

            // Live seat card. Out-of-order seats are listed separately and are
            // not counted as occupied, available or part of the capacity.
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('seats')
                  .snapshots(),
              builder: (context, snapshot) {
                int totalCapacity = 0; // seats in service
                int occupiedCount = 0;
                final List<String> outOfOrderSeats = [];

                if (snapshot.hasData && snapshot.data != null) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['isOutOfOrder'] == true) {
                      outOfOrderSeats.add(doc.id.toUpperCase());
                      continue;
                    }

                    totalCapacity++;
                    if (data['isOccupied'] == true) occupiedCount++;
                  }
                }
                outOfOrderSeats.sort();

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
                      if (outOfOrderSeats.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.block_rounded,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Out of order (${outOfOrderSeats.length}): '
                                  '${outOfOrderSeats.join(', ')}. '
                                  'Not counted above.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF5F6472),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
// Librarian Manage Seats Screen
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getFloorLabel(dynamic floorValue) {
    if (floorValue == null) return 'Ground Floor';
    final String str = floorValue.toString().trim();
    if (str == '0') return 'Ground Floor';
    if (str == '1') return 'First Floor';
    if (str.toLowerCase().contains('first')) return 'First Floor';
    if (str.toLowerCase().contains('ground')) return 'Ground Floor';
    return str;
  }

  // Looks up the reservation (if any) for this seat.
  Stream<QuerySnapshot> _reservationStream(String seatId) {
    return FirebaseFirestore.instance
        .collection('reservations')
        .where('seatNumber', isEqualTo: seatId)
        .limit(1)
        .snapshots();
  }

  // Marks a seat out of order (or back in service) and records which
  // librarian did it, in the same atomic batch.
  Future<void> _setOutOfOrder(DocumentSnapshot seatDoc, bool value) async {
    final db = FirebaseFirestore.instance;
    final actor = await StaffActor.current(role: 'librarian');
    final String seatLabel = seatDoc.id.toUpperCase();

    final batch = db.batch();
    batch.update(seatDoc.reference, {'isOutOfOrder': value});

    // Returning a seat to service also closes any open student report for it,
    // so the report can't keep blocking reservations.
    if (!value) {
      final alertRef = db
          .collection('admin_alerts')
          .doc('report_${seatDoc.id}');
      final alertSnap = await alertRef.get();
      if (alertSnap.exists && alertSnap.data()?['resolved'] != true) {
        batch.update(alertRef, {
          'resolved': true,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedByUid': actor.uid,
          'resolvedByName': actor.name,
          'resolvedByRole': actor.role,
        });
      }
    }

    ActivityLogger.addToBatch(
      batch,
      actor: actor,
      action: value ? 'seat_marked_out_of_order' : 'seat_out_of_order_cleared',
      seatId: seatLabel,
      details: value
          ? 'Seat $seatLabel marked out of order'
          : 'Seat $seatLabel returned to service',
    );
    await batch.commit();
  }

  // Frees the seat; if a student holds a reservation, deletes it and
  // sends them a notification, all in one atomic batch. Every release is
  // labelled with the librarian who did it.
  Future<void> _releaseSeat({
    required DocumentSnapshot seatDoc,
    QueryDocumentSnapshot? reservationDoc,
    required String notifTitle,
    required String notifMessage,
    String actionType = 'cancelled', // 'cancelled' or 'released'
  }) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final currentLibrarian = FirebaseAuth.instance.currentUser;
    final actor = await StaffActor.current(role: 'librarian');
    final String seatLabel = seatDoc.id.toUpperCase();

    // 1. Mark the seat available
    batch.set(seatDoc.reference, {
      'isOccupied': false,
    }, SetOptions(merge: true));

    if (reservationDoc != null) {
      final resData = reservationDoc.data() as Map<String, dynamic>;
      // Reservation doc ID is the student's uid (see home_screen.dart)
      final String studentUid = (resData['userId'] ?? reservationDoc.id)
          .toString();

      // 2. Delete the reservation
      batch.delete(reservationDoc.reference);

      // 2b. Close the reservation_history record so reports can work out
      // how long the student stayed.
      final String historyId = (resData['historyId'] ?? '').toString();
      if (historyId.isNotEmpty) {
        batch.update(db.collection('reservation_history').doc(historyId), {
          'releasedAt': FieldValue.serverTimestamp(),
          'releasedBy': 'librarian',
        });
      }

      // 3. Notify the student (isRead: false => triggers the in-app banner)
      final notifRef = db
          .collection('users')
          .doc(studentUid)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'title': notifTitle,
        'message': notifMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 4. Log it so it shows in the librarian Alerts & History screen
      final historyRef = db
          .collection('reservation_cancellations_history')
          .doc();
      batch.set(historyRef, {
        'seatNumber': seatLabel,
        'studentId': studentUid,
        'studentEmail': (resData['userEmail'] ?? '').toString(),
        'actionType': actionType,
        'cancelledBy':
            currentLibrarian?.email ?? currentLibrarian?.uid ?? 'Librarian',
        'cancelledByName': actor.name,
        'cancelledByUid': actor.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 5. Shared staff activity feed (same for every librarian and admin)
      ActivityLogger.addToBatch(
        batch,
        actor: actor,
        action: actionType == 'released'
            ? 'seat_released'
            : 'reservation_cancelled',
        seatId: seatLabel,
        details: 'Student: ${(resData['userEmail'] ?? studentUid).toString()}',
      );
    } else {
      ActivityLogger.addToBatch(
        batch,
        actor: actor,
        action: 'seat_released',
        seatId: seatLabel,
        details: 'No active reservation on this seat',
      );
    }

    await batch.commit();
  }

  void _showSeatOptionsModal(BuildContext context, DocumentSnapshot seatDoc) {
    const primaryRed = Color(0xFFC01A32);
    const tealGreen = Color(0xFF2EC4B6);
    final data = seatDoc.data() as Map<String, dynamic>;
    final seatNumber = seatDoc.id.toUpperCase();
    final bool isOutOfOrder = data['isOutOfOrder'] == true;
    final bool isOccupied = data['isOccupied'] == true;

    final messenger = ScaffoldMessenger.of(context);

    Future<void> run(
      BuildContext sheetContext,
      Future<void> Function() action,
      String successMsg,
    ) async {
      try {
        await action();
        if (sheetContext.mounted) Navigator.pop(sheetContext);
        messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: primaryRed,
          ),
        );
      }
    }

    Widget actionButton({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            label: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StreamBuilder<QuerySnapshot>(
          stream: _reservationStream(seatDoc.id),
          builder: (context, resSnapshot) {
            final QueryDocumentSnapshot? reservationDoc =
                (resSnapshot.hasData && resSnapshot.data!.docs.isNotEmpty)
                ? resSnapshot.data!.docs.first
                : null;
            final resData = reservationDoc?.data() as Map<String, dynamic>?;
            final String? reservedBy = resData == null
                ? null
                : (resData['userEmail'] ?? reservationDoc!.id).toString();

            return SafeArea(
              child: Padding(
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
                      'Floor: ${_getFloorLabel(data['floor'])}\n'
                      'Status: ${isOutOfOrder ? "Out of Order" : (isOccupied ? "Occupied" : "Available")}'
                      '${reservedBy != null ? "\nReserved by: $reservedBy" : ""}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7E8494),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Mark as Available (also evacuates a reserving student)
                    if (!isOutOfOrder && (isOccupied || reservationDoc != null))
                      actionButton(
                        icon: Icons.event_available_rounded,
                        label: 'Mark as Available',
                        color: tealGreen,
                        onPressed: () => run(
                          sheetContext,
                          () => _releaseSeat(
                            seatDoc: seatDoc,
                            reservationDoc: reservationDoc,
                            actionType: 'released',
                            notifTitle: 'Please Vacate Your Seat',
                            notifMessage:
                                'The librarian has released seat $seatNumber. '
                                'Please evacuate the seat as soon as possible.',
                          ),
                          reservationDoc != null
                              ? 'Seat $seatNumber is now available. Student notified.'
                              : 'Seat $seatNumber marked as Available',
                        ),
                      ),

                    // Cancel the student's reservation
                    if (reservationDoc != null)
                      actionButton(
                        icon: Icons.cancel_outlined,
                        label: 'Cancel Reservation & Notify Student',
                        color: const Color(0xFFDCA134),
                        onPressed: () => run(
                          sheetContext,
                          () => _releaseSeat(
                            seatDoc: seatDoc,
                            reservationDoc: reservationDoc,
                            notifTitle: 'Reservation Cancelled by Librarian',
                            notifMessage:
                                'Your reservation for seat $seatNumber was '
                                'cancelled by the librarian.',
                          ),
                          'Reservation cancelled. Student notified.',
                        ),
                      ),

                    // Out of order toggle
                    if (!isOutOfOrder)
                      actionButton(
                        icon: Icons.block_rounded,
                        label: 'Mark as Out of Order',
                        color: primaryRed,
                        onPressed: () => run(
                          sheetContext,
                          () => _setOutOfOrder(seatDoc, true),
                          'Seat $seatNumber marked as Out of Order',
                        ),
                      )
                    else
                      actionButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Remove Out of Order Mark',
                        color: tealGreen,
                        onPressed: () => run(
                          sheetContext,
                          () => _setOutOfOrder(seatDoc, false),
                          'Out of Order mark removed',
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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
