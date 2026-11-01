import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'seat_detail_screen.dart';

class FirstFloorScreen extends StatelessWidget {
  const FirstFloorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const availableGreen = Color(0xFF2EC4B6);
    const tableColor = Color(0xFFE0BB95);
    const outOfOrderGrey = Colors.grey;

    return Scaffold(
      backgroundColor: Colors.white,
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
                  const Text(
                    'First floor',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Legend Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.circle, color: availableGreen, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'Available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8C919E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.circle, color: primaryRed, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'Occupied',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8C919E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.circle, color: outOfOrderGrey, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'Out of Order',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8C919E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Live Firestore Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading live data:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: primaryRed),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryRed),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  bool isF01Available = true; // Seat 3
                  bool isF01OutOfOrder = false;

                  bool isF02Available = true; // Seat 4
                  bool isF02OutOfOrder = false;

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (doc.id == 'F-01') {
                      final isOccupied = data['isOccupied'] ?? false;
                      isF01OutOfOrder = data['isOutOfOrder'] ?? false;
                      isF01Available = !isOccupied && !isF01OutOfOrder;
                    }
                    if (doc.id == 'F-02') {
                      final isOccupied = data['isOccupied'] ?? false;
                      isF02OutOfOrder = data['isOutOfOrder'] ?? false;
                      isF02Available = !isOccupied && !isF02OutOfOrder;
                    }
                  }

                  // Determine colors based on Out of Order status
                  Color f01IndicatorColor = isF01OutOfOrder
                      ? outOfOrderGrey
                      : (isF01Available ? availableGreen : primaryRed);

                  Color f02IndicatorColor = isF02OutOfOrder
                      ? outOfOrderGrey
                      : (isF02Available ? availableGreen : primaryRed);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black87, width: 1.5),
                      ),
                      child: Stack(
                        children: [
                          // 1. Stairs Label (Top Left)
                          const Positioned(
                            top: 40,
                            left: 60,
                            child: Text(
                              'Stairs',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          // 2. Librarian Section Box (Right Side)
                          Positioned(
                            top: 80,
                            right: 0,
                            child: Container(
                              width: 80,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.black87,
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Librarian\n\nSection',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 3. Seat 4 (Top Left - F-02)
                          Positioned(
                            top: 250,
                            left: 10,
                            child: _buildSeatBlock(
                              label: '4',
                              subLabel: isF02OutOfOrder ? 'Out of Order' : null,
                              indicatorColor: f02IndicatorColor,
                              tableColor: tableColor,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => SeatDetailScreen(
                                      seatId: 'F-02',
                                      floorName: 'First Floor',
                                      isAvailable: isF02Available,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // 4. Seat 3 (Bottom Left - F-01)
                          Positioned(
                            bottom: 80,
                            left: 10,
                            child: _buildSeatBlock(
                              label: '3',
                              subLabel: isF01OutOfOrder ? 'Out of Order' : null,
                              indicatorColor: f01IndicatorColor,
                              tableColor: tableColor,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => SeatDetailScreen(
                                      seatId: 'F-01',
                                      floorName: 'First Floor',
                                      isAvailable: isF01Available,
                                    ),
                                  ),
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
