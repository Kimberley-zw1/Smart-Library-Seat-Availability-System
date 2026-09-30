import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'seat_detail_screen.dart';

class GroundFloorScreen extends StatelessWidget {
  const GroundFloorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const availableGreen = Color(0xFF2EC4B6);
    const tableColor = Color(0xFFE0BB95);

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
                    'Ground floor',
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
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.circle, color: availableGreen, size: 10),
                      SizedBox(width: 6),
                      Text(
                        'Available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8C919E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.circle, color: primaryRed, size: 10),
                      SizedBox(width: 6),
                      Text(
                        'Occupied',
                        style: TextStyle(
                          fontSize: 14,
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

            // StreamBuilder listening to Firestore document IDs: 'G-01' & 'G-02'
            // StreamBuilder listening directly to Firestore without aggressive timeouts
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      debugPrint("Doc ID: ${doc.id} => Data: ${doc.data()}");
                    }
                  }
                  // 1. Handle actual Firestore stream errors (e.g., auth, network failure)
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: primaryRed,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Firestore stream error:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 2. Initial loading state while waiting for first emission
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

                  // 3. Process data when snapshot is ready
                  final docs = snapshot.data?.docs ?? [];

                  bool isG01Available = true;
                  bool isG02Available = true;

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (doc.id == 'G-01') {
                      // If isOccupied is true, availability is false
                      final isOccupied = data['isOccupied'] ?? false;
                      isG01Available = !isOccupied;
                    }

                    if (doc.id == 'G-02') {
                      final isOccupied = data['isOccupied'] ?? false;
                      isG02Available = !isOccupied;
                    }
                  }

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
                          // Stairs Text Top Center
                          const Positioned(
                            top: 36,
                            left: 140,
                            child: Text(
                              'Stairs',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
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
                              painter: LibrarianSectionPainter(),
                              child: const SizedBox(
                                width: 80,
                                height: 140,
                                child: Center(
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
                          ),

                          // Entrance & Exit Labels
                          const Positioned(
                            top: 300,
                            left: 0,
                            child: Text(
                              '→Entrance',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const Positioned(
                            bottom: 180,
                            left: 0,
                            child: Text(
                              '←Exit',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          // Seat G-02 (Block 2)
                          Positioned(
                            top: 220,
                            right: 20,
                            child: _buildSeatBlock(
                              label: '2',
                              indicatorColor: isG02Available
                                  ? availableGreen
                                  : primaryRed,
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
                            ),
                          ),

                          // Seat G-01 (Block 1)
                          Positioned(
                            bottom: 150,
                            right: 20,
                            child: _buildSeatBlock(
                              label: '1',
                              indicatorColor: isG01Available
                                  ? availableGreen
                                  : primaryRed,
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
            width: 70,
            height: 36,
            decoration: BoxDecoration(
              color: tableColor,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LibrarianSectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
