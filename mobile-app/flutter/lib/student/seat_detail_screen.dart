import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      // Direct update to Firebase Firestore
      await FirebaseFirestore.instance
          .collection('seats')
          .doc(widget.seatId)
          .set({'isOccupied': true}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seat ${widget.seatId} successfully reserved!'),
            backgroundColor: const Color(0xFF2EC4B6),
          ),
        );

        Navigator.of(context).pop();
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(
                      widget.isAvailable
                          ? Icons.event_seat_rounded
                          : Icons.event_seat_outlined,
                      size: 80,
                      color: widget.isAvailable ? availableGreen : primaryRed,
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
                            (widget.isAvailable ? availableGreen : primaryRed)
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

              // Reserve Action Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (widget.isAvailable && !_isLoading)
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
                          widget.isAvailable
                              ? 'Reserve Seat ${widget.seatId}'
                              : 'Seat Currently Unavailable',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.isAvailable
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
