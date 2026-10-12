import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:math' as math;

class LibrarianOccupancyScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const LibrarianOccupancyScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);
    const textSubColor = Color(0xFF7E8494);
    const availableGreen = Color(0xFF2EC4B6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section with Back Button & Title
              Row(
                children: [
                  if (onNavigateTab != null) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: primaryRed,
                        size: 26,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          onNavigateTab!(0), // Returns to Dashboard tab
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Text(
                    'Occupancy Overview',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(
                  left: 38.0,
                ), // Align under title if back button is present
                child: Text(
                  'Main Library',
                  style: TextStyle(
                    fontSize: 15,
                    color: textSubColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Live Occupancy Circle Card (Driven by Firestore 'seats' collection)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
                    .snapshots(),
                builder: (context, snapshot) {
                  int totalSeats = 0;
                  int occupiedSeats = 0;
                  int groundTotal = 0;
                  int groundOccupied = 0;
                  int firstTotal = 0;
                  int firstOccupied = 0;

                  if (snapshot.hasData && snapshot.data != null) {
                    final docs = snapshot.data!.docs;
                    totalSeats = docs.length;

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final bool isOccupied =
                          data['isOccupied'] as bool? ?? false;
                      final seatId = doc.id.toUpperCase();
                      final String floor = (data['floor'] ?? '')
                          .toString()
                          .toLowerCase();

                      if (isOccupied) occupiedSeats++;

                      if (floor.contains('first') ||
                          floor == '1' ||
                          seatId.startsWith('F')) {
                        firstTotal++;
                        if (isOccupied) firstOccupied++;
                      } else {
                        groundTotal++;
                        if (isOccupied) groundOccupied++;
                      }
                    }
                  }

                  // Fallbacks if empty
                  if (totalSeats == 0) totalSeats = 4;
                  if (groundTotal == 0 && firstTotal == 0) {
                    groundTotal = 2;
                    firstTotal = 2;
                  }

                  int availableSeats = totalSeats - occupiedSeats;
                  if (availableSeats < 0) availableSeats = 0;

                  double occupancyRatio = totalSeats > 0
                      ? (occupiedSeats / totalSeats)
                      : 0.0;
                  int occupancyPercent = (occupancyRatio * 100).round();

                  int groundAvailable = groundTotal - groundOccupied;
                  int firstAvailable = firstTotal - firstOccupied;

                  return Column(
                    children: [
                      // Circular Graph Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cardBorderColor,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 170,
                              height: 170,
                              child: CustomPaint(
                                painter: CircularProgressPainter(
                                  progress: occupancyRatio,
                                  progressColor: primaryRed,
                                  backgroundColor: const Color(0xFFEFEFF2),
                                  strokeWidth: 20,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$occupancyPercent%',
                                        style: const TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Occupied',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSubColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: primaryRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$occupiedSeats Occupied',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE2E4EB),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$availableSeats Available',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Floor Breakdown Section Title
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Floor Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Ground Floor Card
                      _buildFloorCard(
                        title: 'Ground Floor',
                        subtitle:
                            '$groundOccupied occupied / $groundTotal total',
                        availabilityText: '$groundAvailable available',
                        availabilityColor: availableGreen,
                        borderColor: cardBorderColor,
                      ),

                      const SizedBox(height: 14),

                      // First Floor Card
                      _buildFloorCard(
                        title: 'First Floor',
                        subtitle: '$firstOccupied occupied / $firstTotal total',
                        availabilityText: '$firstAvailable available',
                        availabilityColor: availableGreen,
                        borderColor: cardBorderColor,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloorCard({
    required String title,
    required String subtitle,
    required String availabilityText,
    required Color availabilityColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7E8494),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Text(
            availabilityText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: availabilityColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the Circular Percentage Graph
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Paint progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Draw background circle track
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw active progress arc (starting from top -90 degrees)
    double sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
