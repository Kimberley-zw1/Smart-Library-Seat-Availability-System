import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/library_time.dart';
import '../shared/reservation_cleanup.dart';
import 'reservation_success_screen.dart';
import '../shared/seat_out_of_order.dart';

/// Thrown inside the reservation transaction when the seat can't be booked.
class _ReserveException implements Exception {
  final String message;
  _ReserveException(this.message);
}

class SeatDetailScreen extends StatefulWidget {
  final String seatId;
  final String floorName;

  /// Availability when the screen was opened. It is only used until the live
  /// seat data arrives; after that the screen follows the seat document.
  final bool isAvailable;

  const SeatDetailScreen({
    super.key,
    required this.seatId,
    required this.floorName,
    required this.isAvailable,
  });

  @override
  State<SeatDetailScreen> createState() => _SeatDetailScreenState();
}

class _SeatDetailScreenState extends State<SeatDetailScreen> {
  bool _isLoading = false;
  bool _isReporting = false;

  // Reservation window: 9:00 AM up to (but not including) 10:00 PM CAT.
  // Hours and the UTC+2 offset live in library_time.dart.
  Timer? _clockTimer;

  // Live view of this seat (occupied / out of order), so the screen updates
  // the moment a librarian changes the seat.
  late final Stream<DocumentSnapshot> _seatStream;

  // Live view of the "reported out of order" alert for this seat. While that
  // alert is unresolved, nobody can book the seat.
  late final Stream<DocumentSnapshot> _reportStream;

  bool get _isWithinReservationHours {
    final int hour = nowCat().hour;
    return hour >= kOpenHour && hour < kCloseHour;
  }

  @override
  void initState() {
    super.initState();
    _seatStream = FirebaseFirestore.instance
        .collection('seats')
        .doc(widget.seatId)
        .snapshots();
    _reportStream = FirebaseFirestore.instance
        .collection('admin_alerts')
        .doc('report_${widget.seatId}')
        .snapshots();

    // Re-check regularly so the button updates when the clock crosses
    // 9:00 AM or 10:00 PM while the screen is open.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleReservation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to make a reservation.'),
          backgroundColor: Color(0xFFC01A32),
        ),
      );
      return;
    }

    if (!_isWithinReservationHours) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservations are only available between 9:00 AM and 10:00 PM.',
          ),
          backgroundColor: Color(0xFFC01A32),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Free up anything left over from yesterday (or an earlier session)
      // before checking availability.
      await ReservationCleanup.run();
      if (!mounted) return;

      final db = FirebaseFirestore.instance;
      final seatRef = db.collection('seats').doc(widget.seatId);
      final reservationRef = db.collection('reservations').doc(user.uid);
      final reportAlertRef = db
          .collection('admin_alerts')
          .doc('report_${widget.seatId}');
      final historyRef = db.collection('reservation_history').doc();
      final notificationRef = db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc();

      // The reservation lapses automatically at 10:15 PM CAT today.
      final expiresAt = Timestamp.fromDate(todaysClearTimeUtc());

      // A transaction re-checks the seat at the moment of booking, so two
      // students tapping the same seat can no longer both succeed.
      await db.runTransaction((tx) async {
        // All reads first
        final seatSnap = await tx.get(seatRef);
        final resSnap = await tx.get(reservationRef);
        final reportSnap = await tx.get(reportAlertRef);
        final seat = seatSnap.data() ?? <String, dynamic>{};

        if (seat['isOutOfOrder'] == true) {
          throw _ReserveException(
            "This seat is out of order and can't be booked until the "
            'librarian clears it.',
          );
        }
        final reportData = reportSnap.data() as Map<String, dynamic>?;
        if (reportData != null && reportData['resolved'] != true) {
          throw _ReserveException(
            "This seat was reported as out of order and can't be booked "
            'until the librarian has checked it.',
          );
        }
        if (seat['isOccupied'] == true) {
          throw _ReserveException(
            'Someone just reserved this seat. Please pick another one.',
          );
        }
        if (resSnap.exists) {
          throw _ReserveException('You already have an active reservation.');
        }

        // 1. Mark seat as occupied
        tx.set(seatRef, {'isOccupied': true}, SetOptions(merge: true));

        // 2. Active reservation under the student's UID
        tx.set(reservationRef, {
          'userId': user.uid,
          'userEmail': user.email,
          'seatNumber': widget.seatId,
          'sectionName': widget.floorName,
          'reservedAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt,
          'historyId':
              historyRef.id, // lets cancel / auto-clear close the record
          'status': 'active',
        });

        // 3. Permanent historical record (powers Overview and Reports)
        tx.set(historyRef, {
          'userId': user.uid,
          'seatNumber': widget.seatId,
          'floorName': widget.floorName,
          'reservedAt': FieldValue.serverTimestamp(),
        });

        // 4. Notification for the student
        tx.set(notificationRef, {
          'title': 'Seat Reserved',
          'message':
              'Your reservation for seat ${widget.seatId} on ${widget.floorName} is confirmed.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 5. Navigate to success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const ReservationSuccessScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final String msg = e is _ReserveException
            ? e.message
            : 'Failed to reserve seat: $e';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFC01A32),
          ),
        );
      }
    }
  }

  // Asks the student to confirm, then reports the seat as out of order.
  Future<void> _confirmAndReportOutOfOrder() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Report seat as out of order?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'The librarian will be alerted that seat ${widget.seatId.toUpperCase()} '
          'on ${widget.floorName} is not usable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF7E8494)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Report',
              style: TextStyle(
                color: Color(0xFFC01A32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _reportOutOfOrder();
    }
  }

  Future<void> _reportOutOfOrder() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to report a seat.'),
          backgroundColor: Color(0xFFC01A32),
        ),
      );
      return;
    }

    setState(() {
      _isReporting = true;
    });

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final String seatLabel = widget.seatId.toUpperCase();
      final String reporter = user.email ?? user.uid;
      final String details =
          '${widget.floorName} • Reported by ${user.email ?? 'a student'}';

      // 1. Live alert for the librarian / admin. The document ID is fixed per
      // seat, so repeated reports of the same seat update one alert instead
      // of creating a pile of duplicates.
      final alertRef = db
          .collection('admin_alerts')
          .doc('report_${widget.seatId}');
      batch.set(alertRef, {
        'type': 'report',
        'title': 'Seat $seatLabel reported out of order',
        'subtitle': details,
        'description': details,
        'seatId': widget.seatId,
        'floor': widget.floorName,
        'reportedBy': reporter,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Permanent record of every report
      final reportRef = db.collection('seat_reports').doc();
      batch.set(reportRef, {
        'seatId': widget.seatId,
        'floorName': widget.floorName,
        'reason': 'out_of_order',
        'reportedByUid': user.uid,
        'reportedByEmail': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _isReporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks! The librarian has been alerted.'),
          backgroundColor: Color(0xFF2EC4B6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isReporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send report: $e'),
          backgroundColor: const Color(0xFFC01A32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const availableGreen = Color(0xFF2EC4B6);
    final Color outOfOrderGrey = Colors.grey.shade600;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryRed, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Seat ${widget.seatId}',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          // Live seat state (occupied / out of order)
          stream: _seatStream,
          builder: (context, seatSnapshot) {
            final seatData = seatSnapshot.data?.data() as Map<String, dynamic>?;

            // Until the live data arrives, fall back to what the seat list said
            final bool isOutOfOrder = seatData?['isOutOfOrder'] == true;
            final bool isOccupied = seatData == null
                ? !widget.isAvailable
                : seatData['isOccupied'] == true;
            final bool isSeatFree = !isOutOfOrder && !isOccupied;

            // Status shown on the card: out of order wins over occupied
            final Color statusColor = isOutOfOrder
                ? outOfOrderGrey
                : (isOccupied ? primaryRed : availableGreen);
            final String statusText = isOutOfOrder
                ? 'Out of Order'
                : (isOccupied ? 'Occupied' : 'Available');

            return StreamBuilder<DocumentSnapshot>(
              // Is this seat currently reported as out of order?
              stream: _reportStream,
              builder: (context, reportSnapshot) {
                final reportData =
                    reportSnapshot.data?.data() as Map<String, dynamic>?;
                final bool isReported =
                    reportData != null && reportData['resolved'] != true;

                return StreamBuilder<DocumentSnapshot>(
                  // Listen in real-time to check if user already has an active reservation
                  stream: currentUser != null
                      ? FirebaseFirestore.instance
                            .collection('reservations')
                            .doc(currentUser.uid)
                            .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    final bool hasActiveReservation =
                        snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.exists;

                    final bool withinHours = _isWithinReservationHours;

                    // Determine button active state
                    final bool isButtonEnabled =
                        isSeatFree &&
                        !hasActiveReservation &&
                        !isReported &&
                        !_isLoading &&
                        withinHours;

                    // No point reporting a seat that is already out of order
                    final bool reportDisabled =
                        _isReporting || isReported || isOutOfOrder;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),

                          // Seat Overview Card
                          Container(
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  isSeatFree
                                      ? Icons.event_seat_rounded
                                      : Icons.event_seat_outlined,
                                  size: 80,
                                  color: statusColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Seat ${widget.seatId}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.floorName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Notice when the seat is out of order
                          if (isOutOfOrder)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                "This seat is out of order and can't be reserved until the librarian clears it.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: outOfOrderGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          // Notice when outside reservation hours
                          if (!withinHours)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                'Reservations are open daily from 9:00 AM to 10:00 PM.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: primaryRed.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          // Notice when the seat has been reported (and the
                          // librarian hasn't checked it yet)
                          if (isReported && !isOutOfOrder)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                "This seat was reported as out of order, so it can't be reserved until the librarian has checked it.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: primaryRed.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          // Warning notice if user already holds a seat
                          if (hasActiveReservation)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                'You already have an active reservation. Cancel your current reservation to reserve another seat.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: primaryRed.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          // Reserve Action Button
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isButtonEnabled
                                  ? _handleReservation
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                disabledBackgroundColor: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      isOutOfOrder
                                          ? 'Seat Out of Order'
                                          : !withinHours
                                          ? 'Reservations Closed'
                                          : isReported
                                          ? 'Seat Reported Out of Order'
                                          : isOccupied
                                          ? 'Seat Currently Unavailable'
                                          : hasActiveReservation
                                          ? 'You Already Have a Seat Reserved'
                                          : 'Reserve Seat ${widget.seatId}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isButtonEnabled
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Report Out of Order Button
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: reportDisabled
                                  ? null
                                  : _confirmAndReportOutOfOrder,
                              icon: _isReporting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: primaryRed,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      (isReported || isOutOfOrder)
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.report_problem_outlined,
                                      size: 20,
                                    ),
                              label: Text(
                                isOutOfOrder
                                    ? 'Marked Out of Order'
                                    : isReported
                                    ? 'Report Sent'
                                    : 'Report as Out of Order',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryRed,
                                disabledForegroundColor: Colors.grey.shade600,
                                side: BorderSide(
                                  color: reportDisabled
                                      ? Colors.grey.shade300
                                      : primaryRed,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
