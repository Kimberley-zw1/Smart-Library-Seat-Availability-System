import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Helper function to convert numeric/string floor values to readable labels
String _getFloorLabel(dynamic floorValue) {
  if (floorValue == null) return 'Ground Floor';
  final String str = floorValue.toString().trim();
  if (str == '0') return 'Ground Floor';
  if (str == '1') return 'First Floor';
  if (str.toLowerCase().contains('first')) return 'First Floor';
  if (str.toLowerCase().contains('ground')) return 'Ground Floor';
  return str;
}

// 1. Librarian Alerts & History Screen
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
                          onPressed: () => onNavigateTab!(0),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Text(
                        'Alerts & History',
                        style: TextStyle(
                          fontSize: 26,
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

            // Combined Content Scroll View (Live Alerts + Closing History)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                children: [
                  // --- SECTION 1: LIVE ALERTS ---
                  const Text(
                    'Live System Alerts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('admin_alerts')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: primaryRed),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            'No active alerts at this time.',
                            style: TextStyle(color: textSubColor, fontSize: 14),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final String title =
                              data['title']?.toString() ?? 'System Alert';
                          final String subtitle =
                              data['subtitle']?.toString() ??
                              _getFloorLabel(data['floor']);

                          final Timestamp? timestamp =
                              data['timestamp'] as Timestamp?;
                          final String timeString = _formatTimestamp(timestamp);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // --- SECTION 2: CLOSING ALERTS HISTORY ---
                  const Text(
                    'Closing Alerts History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('closing_alerts_history')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, historySnapshot) {
                      if (historySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: primaryRed),
                          ),
                        );
                      }

                      if (!historySnapshot.hasData ||
                          historySnapshot.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            'No closing alerts sent yet.',
                            style: TextStyle(color: textSubColor, fontSize: 14),
                          ),
                        );
                      }

                      final historyDocs = historySnapshot.data!.docs;

                      return Column(
                        children: historyDocs.map((hDoc) {
                          final hData = hDoc.data() as Map<String, dynamic>;
                          final String sender =
                              hData['sentBy']?.toString() ?? 'Librarian';
                          final int count =
                              hData['recipientCount'] as int? ?? 0;
                          final Timestamp? hTime =
                              hData['timestamp'] as Timestamp?;
                          final String formattedTime = _formatExactTimestamp(
                            hTime,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9FB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '10-Min Closing Warning Sent',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Notified $count student(s) • By: $sender',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: textSubColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textSubColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
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

// 2. Librarian Closing Check Screen with Closing Alert Broadcast & History
class LibrarianClosingCheckScreen extends StatefulWidget {
  const LibrarianClosingCheckScreen({super.key});

  @override
  State<LibrarianClosingCheckScreen> createState() =>
      _LibrarianClosingCheckScreenState();
}

class _LibrarianClosingCheckScreenState
    extends State<LibrarianClosingCheckScreen> {
  bool _isSendingAlert = false;

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

  Future<void> _sendClosingAlertToOccupants(List<String> userIds) async {
    if (userIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students currently occupying seats to notify.'),
        ),
      );
      return;
    }

    setState(() {
      _isSendingAlert = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final currentUser = FirebaseAuth.instance.currentUser;

      for (String userId in userIds) {
        final notifRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();

        batch.set(notifRef, {
          'title': 'Library Closing Soon!',
          'message': 'The library is closing in 10 minutes. Please pack your belongings and vacate your seat.',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      final historyRef = FirebaseFirestore.instance
          .collection('closing_alerts_history')
          .doc();
      batch.set(historyRef, {
        'sentBy': currentUser?.email ?? currentUser?.uid ?? 'Librarian',
        'recipientCount': userIds.length,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Library closing in 10 minutes warning broadcasted.',
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Closing alert sent successfully and logged to history!',
          ),
          backgroundColor: Color(0xFF2EC4B6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send alerts: $e'),
          backgroundColor: const Color(0xFFC01A32),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingAlert = false;
        });
      }
    }
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
                      List<String> activeUserIds = [];

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
                          String? currentUserId;

                          if (activeReservations.containsKey(seatId)) {
                            final res = activeReservations[seatId]!;
                            resTimestamp = res['reservedAt'] as Timestamp?;
                            currentUserId = res['userId']?.toString();
                            fallbackEmailOrId =
                                res['userEmail']?.toString() ??
                                currentUserId ??
                                'Unknown User';
                          }

                          if (isOccupied && currentUserId != null) {
                            activeUserIds.add(currentUserId);
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
                                            future: currentUserId != null
                                                ? FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(currentUserId)
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

                      List<Widget> contentWidgets = [];

                      // 1. Send Closing Alert Card
                      if (activeUserIds.isNotEmpty) {
                        contentWidgets.add(
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8EC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF7E2BD),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Send closing alert',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCA134),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${activeUserIds.length} Occupied',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Students still occupying seats:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSubColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...activeUserIds.map(
                                  (uid) => FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .get(),
                                    builder: (context, uSnap) {
                                      String studentIdText = uid;
                                      if (uSnap.hasData &&
                                          uSnap.data != null &&
                                          uSnap.data!.exists) {
                                        final uData =
                                            uSnap.data!.data()
                                                as Map<String, dynamic>?;
                                        if (uData != null) {
                                          studentIdText =
                                              '${uData['fullName'] ?? 'Student'} (ID: ${uData['studentId'] ?? 'N/A'})';
                                        }
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4.0,
                                        ),
                                        child: Text(
                                          '• $studentIdText',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _isSendingAlert
                                        ? null
                                        : () => _sendClosingAlertToOccupants(
                                            activeUserIds,
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDCA134),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isSendingAlert
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Notify Closing in 10 Mins',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // 2. Seats Status List Header
                      contentWidgets.add(
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12.0, top: 4.0),
                          child: Text(
                            'Seat Occupancy Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      );

                      contentWidgets.addAll(seatCards);

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        children: contentWidgets,
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
