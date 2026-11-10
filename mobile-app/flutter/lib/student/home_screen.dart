import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libseat2/shared/app_theme.dart';
import 'package:libseat2/shared/booking_confirmation.dart';
import 'package:libseat2/shared/library_time.dart';
import 'package:libseat2/shared/reservation_cleanup.dart';

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
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  Timer? _cleanupTimer;
  Timer? _sweepTimer;

  // IDs of notifications already shown as a banner in this session.
  // Notifications are NOT marked as read here; they become read when the
  // student leaves the Alerts screen (see student_alerts.dart).
  final Set<String> _bannerShownIds = {};

  @override
  void initState() {
    super.initState();
    _startListeningToNotifications();

    // Close any reservations left open past 10:15 PM (from yesterday, or from
    // earlier today), then keep checking once a minute so a screen left open
    // overnight also clears. The timer only does real work the first time the
    // clock passes 10:15 PM. It does not rebuild this screen.
    ReservationCleanup.run();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ReservationCleanup.runIfClosingPassed(),
    );

    // Bookings must be confirmed within 5 minutes. Measure the phone-vs-
    // Firebase clock difference first, then free any seat whose booking was
    // never confirmed (for example the student closed the app). Repeats every
    // 30 seconds. This does not rebuild the screen.
    BookingConfirmation.syncClock().then(
      (_) => BookingConfirmation.sweepExpired(),
    );
    _sweepTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => BookingConfirmation.sweepExpired(),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _cleanupTimer?.cancel();
    _sweepTimer?.cancel();
    super.dispose();
  }

  // Real-time listener for incoming notifications
  void _startListeningToNotifications() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>?;
              if (data == null) continue;

              // Skip anything already bannered in this session
              if (!_bannerShownIds.add(change.doc.id)) continue;

              // Only banner fresh notifications. A null timestamp means the
              // server timestamp is still pending, so it is brand new.
              // The window is generous (10 min) so a skewed device clock
              // doesn't cause the banner to be skipped.
              final DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
              final bool isFresh =
                  ts == null || DateTime.now().difference(ts).inMinutes < 10;

              if (isFresh) {
                final String title =
                    data['title']?.toString() ?? 'Library Alert';
                final String message = data['message']?.toString() ?? '';
                _showInAppBanner(title, message);
              }
            }
          }
        });
  }

  // Beautiful sliding in-app banner alert
  void _showInAppBanner(String title, String message) {
    if (!mounted) return;

    OverlayState overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * -60),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFC01A32).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.colors.softPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: Color(0xFFC01A32),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    // Automatically remove the banner after 6 seconds
    Future.delayed(const Duration(milliseconds: 6000), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  // Cancels the student's reservation.
  //
  // Stay time: the matching reservation_history record is closed with
  // `releasedAt` (a server timestamp). Its `reservedAt` was also set by the
  // server when the seat was booked, so stay time = releasedAt - reservedAt
  // is exact and doesn't depend on this phone's clock. The reports read it
  // from there. The student is also told how long they used the seat.
  Future<void> _cancelReservation(
    String userId,
    String? seatNumber,
    String? historyId,
    Timestamp? reservedAt,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Delete user reservation record
      final reservationRef = db.collection('reservations').doc(userId);
      batch.delete(reservationRef);

      // 2. Reset seat availability in seats collection
      if (seatNumber != null && seatNumber.isNotEmpty) {
        final seatRef = db.collection('seats').doc(seatNumber);
        batch.set(seatRef, {'isOccupied': false}, SetOptions(merge: true));
      }

      // 3. Close the history record so the stay time is recorded.
      // Reservations made before historyId existed simply skip this.
      if (historyId != null && historyId.isNotEmpty) {
        batch.update(db.collection('reservation_history').doc(historyId), {
          'releasedAt': FieldValue.serverTimestamp(),
          'releasedBy': 'student',
        });
      }

      // How long they used the seat, for the message only (the record itself
      // uses the server timestamps above).
      String stayNote = '';
      if (reservedAt != null) {
        final Duration stay = DateTime.now().difference(reservedAt.toDate());
        if (stay.inMinutes >= 1) {
          stayNote = ' You used the seat for ${formatStay(stay)}.';
        }
      }

      // 4. Add cancellation entry to user's notifications history subcollection.
      // Marked as already read: the student triggered this themselves and
      // already sees a snackbar, so no banner or unread highlight is needed.
      final notificationRef = db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(); // Auto-generate unique ID

      batch.set(notificationRef, {
        'title': 'Reservation Cancelled',
        'message': seatNumber != null && seatNumber.isNotEmpty
            ? 'Your reservation for seat $seatNumber has been cancelled.$stayNote'
            : 'Your seat reservation has been cancelled.$stayNote',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation cancelled.$stayNote'),
          backgroundColor: const Color(0xFFC01A32),
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

  // Pushes a page and resets the bottom bar to Home when the student returns
  void _openPage(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => page))
        .then((_) {
          if (mounted) {
            setState(() {
              _currentIndex = 0;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.colors.background,
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
              Padding(
                padding: const EdgeInsets.only(left: 0.0),
                child: Text(
                  'Find an available seat and enjoy your study time!',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Real-Time Seat Availability Card.
              // Out-of-order seats are not counted as usable seats.
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
                    .snapshots(),
                builder: (context, snapshot) {
                  int totalSeats = 0; // seats in service
                  int availableSeats = 0;
                  bool isLoading =
                      snapshot.connectionState == ConnectionState.waiting;

                  if (snapshot.hasData && snapshot.data != null) {
                    for (final doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['isOutOfOrder'] == true) continue;

                      totalSeats++;
                      if (data['isOccupied'] != true) availableSeats++;
                    }
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28.0,
                      horizontal: 20.0,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryRed.withValues(alpha: 0.05),
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
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                              height: 1.0,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          isLoading
                              ? 'Fetching live seat data...'
                              : totalSeats == 0
                              ? 'No seat data available'
                              : 'of $totalSeats seats available',
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

                    // True until the student taps "Confirm Booking"
                    final bool isPending = BookingConfirmation.isPending(data);

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryRed.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withValues(alpha: 0.08),
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
                                children: [
                                  const Icon(
                                    Icons.bookmark_added_rounded,
                                    color: primaryRed,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your Reserved Seat',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.textPrimary,
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
                                  color:
                                      (isPending
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF2E7D32))
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isPending ? 'Pending' : 'Active',
                                  style: TextStyle(
                                    color: isPending
                                        ? (context.isDark
                                              ? const Color(0xFFFBBF24)
                                              : const Color(0xFFB45309))
                                        : (context.isDark
                                              ? const Color(0xFF66BB6A)
                                              : const Color(0xFF2E7D32)),
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
                                  color: context.colors.softPink,
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
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Account: ${data['userEmail'] ?? currentUser?.email}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.colors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // How long the seat has been reserved (updates by
                          // itself; only this line rebuilds)
                          const SizedBox(height: 12),
                          _ReservedFor(
                            reservedAt: data['reservedAt'] as Timestamp?,
                          ),

                          const SizedBox(height: 14),

                          // Until confirmed: 5-minute countdown + Confirm
                          // button. After confirming: the reminder to cancel
                          // when leaving.
                          if (isPending)
                            _ConfirmBookingBanner(
                              userId: currentUser?.uid ?? '',
                              reservedAt: data['reservedAt'] as Timestamp?,
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Remember to cancel your reservation when you leave the library so other students can use the seat. Reservations still open at 10:15 PM are closed automatically.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: context.colors.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () {
                                if (currentUser != null) {
                                  _cancelReservation(
                                    currentUser.uid,
                                    data['seatNumber'] as String?,
                                    data['historyId'] as String?,
                                    data['reservedAt'] as Timestamp?,
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
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.softPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.event_seat_rounded,
                            color: primaryRed,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Active Reservation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Find and reserve a study seat around campus.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary,
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
                      onTap: () => _openPage(const FloorSelectionScreen()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      title: 'Notifications',
                      icon: Icons.notifications_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      onTap: () => _openPage(const StudentAlerts()),
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
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.colors.border, width: 1.0),
          ),
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
                _openPage(const FloorSelectionScreen());
                break;
              case 2:
                _openPage(const StudentAlerts());
                break;
              case 3:
                _openPage(const StudentProfileScreen());
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: context.colors.surface,
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

  // Action Card Builder. The card tint is the icon color at low opacity, so
  // it looks right in both light and dark mode.
  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: iconColor.withValues(alpha: 0.12),
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
                  color: context.colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.15),
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// "Reserved at 2:10 PM  •  1h 12m so far". It has its own timer, so only this
// one line rebuilds every 30 seconds (not the whole home screen, which would
// restart its live Firestore streams each time).
// -----------------------------------------------------------------------------
class _ReservedFor extends StatefulWidget {
  final Timestamp? reservedAt;

  const _ReservedFor({required this.reservedAt});

  @override
  State<_ReservedFor> createState() => _ReservedForState();
}

class _ReservedForState extends State<_ReservedFor> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Timestamp? ts = widget.reservedAt;
    // The server timestamp can still be pending for a moment after booking
    if (ts == null) return const SizedBox.shrink();

    final DateTime start = ts.toDate();
    final Duration elapsed = DateTime.now().difference(start);

    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 16,
          color: context.colors.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Reserved at ${formatClock(toCat(start))}  •  '
            '${formatStay(elapsed)} so far',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// "Confirm your booking within 5 minutes or it will be cancelled
// automatically" with a live countdown and a Confirm button. It has its own
// 1-second timer, so only this box rebuilds. When the countdown reaches zero
// it cancels the booking (frees the seat and notifies the student).
// -----------------------------------------------------------------------------
class _ConfirmBookingBanner extends StatefulWidget {
  final String userId;
  final Timestamp? reservedAt;

  const _ConfirmBookingBanner({required this.userId, required this.reservedAt});

  @override
  State<_ConfirmBookingBanner> createState() => _ConfirmBookingBannerState();
}

class _ConfirmBookingBannerState extends State<_ConfirmBookingBanner> {
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFC01A32);

  Timer? _timer;
  bool _isConfirming = false;
  bool _expiryHandled = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _cancelIfTimeIsUp();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Time left, measured against Firebase's clock (reservedAt is a server time)
  Duration _remaining() {
    final Timestamp? ts = widget.reservedAt;
    // The server timestamp can still be pending for a moment after booking
    if (ts == null) return kConfirmWindow;

    final Duration left = ts
        .toDate()
        .add(kConfirmWindow)
        .difference(BookingConfirmation.now());
    if (left.isNegative) return Duration.zero;
    return left > kConfirmWindow ? kConfirmWindow : left;
  }

  void _cancelIfTimeIsUp() {
    if (_expiryHandled || widget.reservedAt == null) return;
    if (_remaining() == Duration.zero) {
      _expiryHandled = true;
      // The reservation card disappears by itself once this succeeds.
      BookingConfirmation.cancelIfExpired(widget.userId);
    }
  }

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    try {
      final bool ok = await BookingConfirmation.confirm(widget.userId);
      if (!mounted) return;
      if (!ok) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This reservation was already cancelled.'),
            backgroundColor: _red,
          ),
        );
      }
      // On success the card refreshes by itself and this box is replaced
      // by the usual reminder.
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm: $e'), backgroundColor: _red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration left = _remaining();
    final bool urgent = left.inSeconds <= 60;
    final Color accent = urgent ? _red : _amber;

    final String minutes = left.inMinutes.toString();
    final String seconds = (left.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm your booking within ${kConfirmWindow.inMinutes} '
                  'minutes or it will be cancelled automatically.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$minutes:$seconds left',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: _isConfirming ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EC4B6),
                    disabledBackgroundColor: context.colors.neutralFill,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isConfirming
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm Booking',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
