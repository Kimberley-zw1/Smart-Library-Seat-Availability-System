import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libseat2/shared/app_theme.dart';

import 'reported_seat_builder.dart';
import 'seat_detail_screen.dart';

class GroundFloorScreen extends StatelessWidget {
  const GroundFloorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const availableGreen = Color(0xFF2EC4B6);
    const reportedAmber = Color(0xFFDCA134);
    const tableColor = Color(0xFFE0BB95);
    const outOfOrderGrey = Colors.grey;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: primaryRed,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ground floor',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Legend Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 6,
                children: [
                  _legendItem(context, availableGreen, 'Available'),
                  _legendItem(context, primaryRed, 'Occupied'),
                  _legendItem(context, reportedAmber, 'Reported'),
                  _legendItem(context, outOfOrderGrey, 'Out of Order'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // StreamBuilder listening to Firestore seat documents
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Firestore stream error:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: primaryRed),
                          SizedBox(height: 12),
                          Text('Connecting to live seat sensors...'),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Seat States mapping
                  bool isG01Available = true;
                  bool isG01OutOfOrder = false;

                  bool isG02Available = true;
                  bool isG02OutOfOrder = false;

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (doc.id == 'G-01') {
                      final isOccupied = data['isOccupied'] ?? false;
                      isG01OutOfOrder = data['isOutOfOrder'] ?? false;
                      isG01Available = !isOccupied && !isG01OutOfOrder;
                    }

                    if (doc.id == 'G-02') {
                      final isOccupied = data['isOccupied'] ?? false;
                      isG02OutOfOrder = data['isOutOfOrder'] ?? false;
                      isG02Available = !isOccupied && !isG02OutOfOrder;
                    }
                  }

                  // Base colors from the seat itself (out of order wins)
                  Color g01BaseColor = isG01OutOfOrder
                      ? outOfOrderGrey
                      : (isG01Available ? availableGreen : primaryRed);

                  Color g02BaseColor = isG02OutOfOrder
                      ? outOfOrderGrey
                      : (isG02Available ? availableGreen : primaryRed);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.textPrimary,
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Stairs Text Top Center
                          Positioned(
                            top: 36,
                            left: 140,
                            child: Text(
                              'Stairs',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          // Librarian Section Box Top-Left
                          Positioned(
                            top: 50,
                            left: 0,
                            child: CustomPaint(
                              size: const Size(80, 140),
                              painter: LibrarianSectionPainter(
                                color: context.colors.textPrimary,
                              ),
                              child: SizedBox(
                                width: 80,
                                height: 140,
                                child: Center(
                                  child: Text(
                                    'Librarian\n\nSection',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Entrance & Exit Labels
                          Positioned(
                            top: 300,
                            left: 0,
                            child: Text(
                              '→Entrance',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 180,
                            left: 0,
                            child: Text(
                              '←Exit',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),

                          // Seat G-02 (Block 2)
                          Positioned(
                            top: 220,
                            right: 20,
                            child: ReportedSeatBuilder(
                              seatId: 'G-02',
                              builder: (context, isReported) {
                                // Out of order wins over reported
                                final bool showReported =
                                    isReported && !isG02OutOfOrder;
                                return _buildSeatBlock(
                                  label: '2',
                                  subLabel: isG02OutOfOrder
                                      ? 'Out of Order'
                                      : (showReported ? 'Reported' : null),
                                  indicatorColor: showReported
                                      ? reportedAmber
                                      : g02BaseColor,
                                  tableColor: tableColor,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => SeatDetailScreen(
                                          seatId: 'G-02',
                                          floorName: 'Ground Floor',
                                          isAvailable: isG02Available,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // Seat G-01 (Block 1)
                          Positioned(
                            bottom: 150,
                            right: 20,
                            child: ReportedSeatBuilder(
                              seatId: 'G-01',
                              builder: (context, isReported) {
                                final bool showReported =
                                    isReported && !isG01OutOfOrder;
                                return _buildSeatBlock(
                                  label: '1',
                                  subLabel: isG01OutOfOrder
                                      ? 'Out of Order'
                                      : (showReported ? 'Reported' : null),
                                  indicatorColor: showReported
                                      ? reportedAmber
                                      : g01BaseColor,
                                  tableColor: tableColor,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => SeatDetailScreen(
                                          seatId: 'G-01',
                                          floorName: 'Ground Floor',
                                          isAvailable: isG01Available,
                                        ),
                                      ),
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
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // The seat tables are tan in both modes, so their text colors don't change.
  Widget _buildSeatBlock({
    required String label,
    String? subLabel,
    required Color indicatorColor,
    required Color tableColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 10,
            decoration: BoxDecoration(
              color: indicatorColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 85,
            height: 42,
            decoration: BoxDecoration(
              color: tableColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (subLabel != null)
                  Text(
                    subLabel,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Draws the librarian section outline. The line color follows the theme.
class LibrarianSectionPainter extends CustomPainter {
  final Color color;

  LibrarianSectionPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.5, size.height)
      ..moveTo(size.width * 0.3, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LibrarianSectionPainter oldDelegate) =>
      oldDelegate.color != color;
}
