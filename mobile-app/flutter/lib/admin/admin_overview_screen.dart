import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_home_screen.dart';
import 'admin_alerts_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_profile_screen.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  int _currentIndex = 2; // Overview tab selected

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    Widget targetScreen;
    switch (index) {
      case 0:
        targetScreen = const AdminHomeScreen();
        break;
      case 1:
        targetScreen = const AdminAlertsScreen();
        break;
      case 2:
        return; // Already on Overview
      case 3:
        targetScreen = const AdminReportsScreen();
        break;
      case 4:
        targetScreen = const AdminProfileScreen();
        break;
      default:
        return;
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => targetScreen));
  }

  // Helper method to compute dynamic peak hours window from student reservation history
  String _calculatePeakHours(List<QueryDocumentSnapshot> reservationDocs) {
    if (reservationDocs.isEmpty) return '10am–1pm';

    Map<String, int> timeSlots = {
      '8am–11am': 0,
      '11am–2pm': 0,
      '2pm–5pm': 0,
      '5pm–8pm': 0,
    };

    for (var doc in reservationDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? timestamp =
          (data['reservedAt'] ?? data['timestamp']) as Timestamp?;
      if (timestamp != null) {
        int hour = timestamp.toDate().hour;
        if (hour >= 8 && hour < 11) {
          timeSlots['8am–11am'] = (timeSlots['8am–11am'] ?? 0) + 1;
        } else if (hour >= 11 && hour < 14) {
          timeSlots['11am–2pm'] = (timeSlots['11am–2pm'] ?? 0) + 1;
        } else if (hour >= 14 && hour < 17) {
          timeSlots['2pm–5pm'] = (timeSlots['2pm–5pm'] ?? 0) + 1;
        } else if (hour >= 17 && hour < 20) {
          timeSlots['5pm–8pm'] = (timeSlots['5pm–8pm'] ?? 0) + 1;
        }
      }
    }

    String peakSlot = '10am–1pm';
    int maxCount = -1;
    timeSlots.forEach((slot, count) {
      if (count > maxCount) {
        maxCount = count;
        peakSlot = slot;
      }
    });

    return maxCount <= 0 ? '10am–1pm' : peakSlot;
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);
    const textSubColor = Color(0xFF8C919E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryRed),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Executive Overview',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Smart Library Analytics',
                style: TextStyle(
                  fontSize: 16,
                  color: textSubColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 24),

              // Real-Time Metrics & Dynamic Peak Hours Stream Builders
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('seats')
                    .snapshots(),
                builder: (context, seatSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reservation_history')
                        .snapshots(),
                    builder: (context, reservationSnapshot) {
                      int totalSeats = 0;
                      int occupiedCount = 0;
                      int groundTotal = 0;
                      int groundOccupied = 0;
                      int firstTotal = 0;
                      int firstOccupied = 0;

                      if (seatSnapshot.hasData && seatSnapshot.data != null) {
                        final docs = seatSnapshot.data!.docs;
                        totalSeats = docs.length;

                        for (var doc in docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final bool isOccupied =
                              data['isOccupied'] as bool? ?? false;
                          final seatId = doc.id.toUpperCase();
                          final String floor = (data['floor'] ?? '')
                              .toString()
                              .toLowerCase();

                          if (isOccupied) occupiedCount++;

                          if (floor.contains('first') ||
                              seatId.startsWith('F')) {
                            firstTotal++;
                            if (isOccupied) firstOccupied++;
                          } else {
                            groundTotal++;
                            if (isOccupied) groundOccupied++;
                          }
                        }
                      }

                      if (totalSeats == 0) totalSeats = 4;

                      final int utilizationPercent =
                          ((occupiedCount / totalSeats) * 100).round();
                      final double groundRatio = groundTotal > 0
                          ? groundOccupied / groundTotal
                          : 0.0;
                      final double firstRatio = firstTotal > 0
                          ? firstOccupied / firstTotal
                          : 0.0;
                      final String busiestFloor = firstRatio > groundRatio
                          ? 'First Floor'
                          : 'Ground Floor';

                      // Compute dynamic peak hours from permanent reservation history
                      String peakHoursText = '10am–1pm';
                      if (reservationSnapshot.hasData &&
                          reservationSnapshot.data != null) {
                        peakHoursText = _calculatePeakHours(
                          reservationSnapshot.data!.docs,
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Utilization Rate',
                                  value: '$utilizationPercent%',
                                  icon: Icons.show_chart_rounded,
                                  iconColor: primaryRed,
                                  borderColor: cardBorderColor,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Peak Hours',
                                  value: peakHoursText,
                                  icon: Icons.access_time_filled_rounded,
                                  iconColor: const Color(0xFF9E9E9E),
                                  borderColor: cardBorderColor,
                                  valueFontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Busiest Floor',
                                  value: busiestFloor,
                                  icon: Icons.account_balance_rounded,
                                  iconColor: const Color(0xFF8B7E74),
                                  borderColor: cardBorderColor,
                                  valueFontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Total Seats',
                                  value: '$totalSeats',
                                  icon: Icons.chair_rounded,
                                  iconColor: const Color(0xFFA0522D),
                                  borderColor: cardBorderColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // Weekly Usage Trend Card with Permanent History Stream & Numerical Y-Axis
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Usage Trend',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dynamic StreamBuilder feeding reservation history to the Line Chart
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('reservation_history')
                          .snapshots(),
                      builder: (context, snapshot) {
                        List<double> weeklyData = [0, 0, 0, 0, 0, 0, 0];

                        if (snapshot.hasData && snapshot.data != null) {
                          List<int> counts = [0, 0, 0, 0, 0, 0, 0];
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final Timestamp? timestamp =
                                (data['reservedAt'] ?? data['timestamp'])
                                    as Timestamp?;
                            if (timestamp != null) {
                              DateTime dt = timestamp.toDate();
                              int index = dt.weekday - 1; // 0 = Mon, 6 = Sun
                              if (index >= 0 && index < 7) {
                                counts[index]++;
                              }
                            }
                          }
                          weeklyData = counts.map((c) => c.toDouble()).toList();
                        }

                        return SizedBox(
                          height: 150,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: TrendChartPainter(dataPoints: weeklyData),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.only(left: 36.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Mon',
                            style: TextStyle(fontSize: 12, color: textSubColor),
                          ),
                          Text(
                            'Tue',
                            style: TextStyle(fontSize: 12, color: textSubColor),
                          ),
                          Text(
                            'Wed',
                            style: TextStyle(fontSize: 12, color: textSubColor),
                          ),
                          Text(
                            'Thu',
                            style: TextStyle(fontSize: 12, color: textSubColor),
                          ),
                          Text(
                            'Fri',
                            style: TextStyle(fontSize: 12, color: textSubColor),
                          ),
                          Text(
                            'Sat',
                            style: TextStyle(fontSize: 12, color: textSubColor),
                          ),
                          Text(
                            'Sun',
                            style: TextStyle(fontSize: 12, color: textSubColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1.0)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryRed,
          unselectedItemColor: const Color(0xFF9E9E9E),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              activeIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
              label: 'Overview',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_drive_file_outlined),
              activeIcon: Icon(Icons.insert_drive_file_rounded),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    double valueFontSize = 24,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8C919E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, size: 20, color: iconColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class TrendChartPainter extends CustomPainter {
  final List<double> dataPoints;

  TrendChartPainter({required this.dataPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1.0;

    double leftPadding = 40.0;
    double rightPadding = 10.0;
    double bottomPadding = 15.0;
    double topPadding = 10.0;

    double usableWidth = size.width - leftPadding - rightPadding;
    double usableHeight = size.height - bottomPadding - topPadding;

    if (dataPoints.isEmpty) return;

    double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    if (maxVal < 5) maxVal = 5.0;

    for (int i = 0; i <= 3; i++) {
      double y = topPadding + (usableHeight / 3) * i;
      double labelVal = maxVal - ((maxVal / 3) * i);

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: labelVal.round().toString(),
          style: const TextStyle(fontSize: 10, color: Color(0xFF8C919E)),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding - 32, y - 6));
    }

    final redPathPaint = Paint()
      ..color = const Color(0xFFC01A32)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final areaStrokePaint = Paint()
      ..color = const Color(0xFFFDE8E9)
      ..strokeWidth = 12.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final innerRedPaint = Paint()
      ..color = const Color(0xFFC01A32)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final axisPath = Path();
    axisPath.moveTo(leftPadding, topPadding);
    axisPath.lineTo(leftPadding, size.height - bottomPadding);
    axisPath.lineTo(size.width - rightPadding, size.height - bottomPadding);
    canvas.drawPath(axisPath, redPathPaint);

    final wavePath = Path();
    for (int i = 0; i < dataPoints.length; i++) {
      double x = leftPadding + (usableWidth / (dataPoints.length - 1)) * i;
      double normalizedY =
          size.height -
          bottomPadding -
          ((dataPoints[i] / maxVal) * usableHeight);

      if (i == 0) {
        wavePath.moveTo(x, normalizedY);
      } else {
        wavePath.lineTo(x, normalizedY);
      }
    }

    canvas.drawPath(wavePath, areaStrokePaint);
    canvas.drawPath(wavePath, innerRedPaint);
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints;
  }
}
