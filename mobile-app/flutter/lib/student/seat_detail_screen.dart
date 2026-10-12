import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reservation_success_screen.dart';

class SeatDetailScreen extends StatefulWidget {
  final String seatId;
  final String floorName;
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

    setState(() {
      _isLoading = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Mark seat as occupied in 'seats' collection
      final seatRef = FirebaseFirestore.instance
          .collection('seats')
          .doc(widget.seatId);
      batch.set(seatRef, {'isOccupied': true}, SetOptions(merge: true));

      // 2. Save active reservation under student's UID in 'reservations' collection
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(user.uid);
      batch.set(reservationRef, {
        'userId': user.uid,
        'userEmail': user.email,
        'seatNumber': widget.seatId,
        'sectionName': widget.floorName,
        'reservedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // 3. Permanent Historical Record (Powers Overview Charts & Peak Hours Analytics)
      final historyRef = FirebaseFirestore.instance
          .collection('reservation_history')
          .doc();
      batch.set(historyRef, {
        'userId': user.uid,
        'seatNumber': widget.seatId,
        'floorName': widget.floorName,
        'reservedAt': FieldValue.serverTimestamp(),
      });

      // 4. Add entry to user's notifications history subcollection
      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(); // Auto-generate unique ID

      batch.set(notificationRef, {
        'title': 'Seat Reserved',
        'message':
            'Your reservation for seat ${widget.seatId} on ${widget.floorName} is confirmed.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Execute all Firestore writes together atomically
      await batch.commit();

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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reserve seat: $e'),
            backgroundColor: const Color(0xFFC01A32),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const availableGreen = Color(0xFF2EC4B6);
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

            // Determine button active state
            final bool isButtonEnabled =
                widget.isAvailable && !hasActiveReservation && !_isLoading;

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
                          widget.isAvailable
                              ? Icons.event_seat_rounded
                              : Icons.event_seat_outlined,
                          size: 80,
                          color: widget.isAvailable
                              ? availableGreen
                              : primaryRed,
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
                            color:
                                (widget.isAvailable
                                        ? availableGreen
                                        : primaryRed)
                                    .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: widget.isAvailable
                                    ? availableGreen
                                    : primaryRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isAvailable ? 'Available' : 'Occupied',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isAvailable
                                      ? availableGreen
                                      : primaryRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Warning notice if user already holds a seat
                  if (hasActiveReservation)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'You already have an active reservation. Cancel your current reservation to reserve another seat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryRed.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Reserve Action Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isButtonEnabled ? _handleReservation : null,
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
                              !widget.isAvailable
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
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
