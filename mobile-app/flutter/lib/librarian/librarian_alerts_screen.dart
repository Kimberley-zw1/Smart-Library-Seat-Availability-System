import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper function to convert numeric/string floor values to readable labels
String _getFloorLabel(dynamic floorValue) {
  if (floorValue == null) return 'Ground Floor';
  final String str = floorValue.toString().trim();
  if (str == '0') return 'Ground Floor';
  if (str == '1') return 'First Floor';
  if (str.toLowerCase().contains('first')) return 'First Floor';
  if (str.toLowerCase().contains('ground')) return 'Ground Floor';
  return str; // Fallback to raw string if another value is passed
}

// 1. Librarian Alerts Screen
class LibrarianAlertsScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const LibrarianAlertsScreen({super.key, this.onNavigateTab});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  Future<void> _resolveAlert(String docId) async {
    await FirebaseFirestore.instance
        .collection('admin_alerts')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);
    const textSubColor = Color(0xFF7E8494);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Header Section with Back Button & Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                        'Alerts',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('admin_alerts')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int newAlertsCount = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCA134),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$newAlertsCount New',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Live Alerts List from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('admin_alerts')
                    .orderBy('timestamp', descending: true)
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
                        'No alerts at this time.',
                        style: TextStyle(color: textSubColor, fontSize: 15),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String title =
                          data['title']?.toString() ?? 'System Alert';

                      // Map floor 0 or 1 dynamically
                      final String subtitle =
                          data['subtitle']?.toString() ??
                          _getFloorLabel(data['floor']);

                      final Timestamp? timestamp =
                          data['timestamp'] as Timestamp?;
                      final String timeString = _formatTimestamp(timestamp);

                      return Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cardBorderColor,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDCA134),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: textSubColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  timeString,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textSubColor,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _resolveAlert(doc.id),
                                  child: const Text(
                                    'Resolve',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: primaryRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Closing Check Navigation Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const LibrarianClosingCheckScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Closing Check',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. Librarian Closing Check Screen with Reservation & User Student ID lookups
class LibrarianClosingCheckScreen extends StatelessWidget {
  const LibrarianClosingCheckScreen({super.key});

  String _formatExactTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Not recorded';
    final DateTime dt = timestamp.toDate();
    final String day = dt.day.toString().padLeft(2, '0');
    final String month = dt.month.toString().padLeft(2, '0');
    final String year = dt.year.toString();
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);
    const textSubColor = Color(0xFF7E8494);
    const safeGreen = Color(0xFF2EC4B6);

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
          'Closing Check',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
                    .snapshots(),
                builder: (context, seatSnapshot) {
                  if (seatSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryRed),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reservations')
                        .where('status', isEqualTo: 'active')
                        .snapshots(),
                    builder: (context, reservationSnapshot) {
                      Map<String, Map<String, dynamic>> activeReservations = {};
                      if (reservationSnapshot.hasData) {
                        for (var resDoc in reservationSnapshot.data!.docs) {
                          final resData = resDoc.data() as Map<String, dynamic>;
                          final seatNum =
                              resData['seatNumber']?.toString().toUpperCase() ??
                              '';
                          if (seatNum.isNotEmpty) {
                            activeReservations[seatNum] = resData;
                          }
                        }
                      }

                      List<Widget> seatCards = [];

                      if (seatSnapshot.hasData && seatSnapshot.data != null) {
                        final docs = seatSnapshot.data!.docs;
                        for (var doc in docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final bool isOccupied =
                              data['isOccupied'] as bool? ?? false;
                          final seatId = doc.id.toUpperCase();
                          final String floorLabel = _getFloorLabel(
                            data['floor'],
                          );

                          Timestamp? resTimestamp;
                          String fallbackEmailOrId = 'Unknown User';

                          if (activeReservations.containsKey(seatId)) {
                            final res = activeReservations[seatId]!;
                            resTimestamp = res['reservedAt'] as Timestamp?;
                            fallbackEmailOrId =
                                res['userEmail']?.toString() ??
                                res['userId']?.toString() ??
                                'Unknown User';
                          }

                          final String timeStr = _formatExactTimestamp(
                            resTimestamp ?? (data['updatedAt'] as Timestamp?),
                          );

                          seatCards.add(
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: cardBorderColor,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isOccupied
                                              ? 'Seat $seatId is occupied'
                                              : 'Seat $seatId is clear',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$floorLabel • Updated: $timeStr',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: textSubColor,
                                          ),
                                        ),
                                        if (isOccupied) ...[
                                          const SizedBox(height: 6),
                                          FutureBuilder<DocumentSnapshot>(
                                            future:
                                                activeReservations.containsKey(
                                                      seatId,
                                                    ) &&
                                                    activeReservations[seatId]!['userId'] !=
                                                        null
                                                ? FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(
                                                        activeReservations[seatId]!['userId'],
                                                      )
                                                      .get()
                                                : null,
                                            builder: (context, userSnap) {
                                              String displayId =
                                                  fallbackEmailOrId;
                                              if (userSnap.hasData &&
                                                  userSnap.data != null &&
                                                  userSnap.data!.exists) {
                                                final userData =
                                                    userSnap.data!.data()
                                                        as Map<
                                                          String,
                                                          dynamic
                                                        >?;
                                                if (userData != null &&
                                                    userData['studentId'] !=
                                                        null) {
                                                  displayId =
                                                      userData['studentId']
                                                          .toString();
                                                }
                                              }

                                              return Text(
                                                'Student ID: $displayId',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: primaryRed,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isOccupied
                                          ? const Color(0xFFDCA134)
                                          : safeGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      }

                      if (seatCards.isEmpty) {
                        seatCards.add(
                          const Center(
                            child: Text(
                              'No seats registered in system.',
                              style: TextStyle(color: textSubColor),
                            ),
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        children: seatCards,
                      );
                    },
                  );
                },
              ),
            ),

            // Dynamic Safety Status Banner at Bottom
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('seats')
                  .snapshots(),
              builder: (context, snapshot) {
                bool hasOccupiedSeats = false;
                if (snapshot.hasData && snapshot.data != null) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['isOccupied'] == true) {
                      hasOccupiedSeats = true;
                      break;
                    }
                  }
                }

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(24.0),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: hasOccupiedSeats ? primaryRed : safeGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    hasOccupiedSeats
                        ? 'NOT SAFE TO\nCLOSE!'
                        : 'SAFE TO\nCLOSE!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
