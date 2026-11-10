import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_home_screen.dart';
import 'admin_alerts_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_profile_screen.dart';
import '../shared/report_service.dart';
import '../shared/reservation_cleanup.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final int _currentIndex = 2; // Overview tab selected

  final ReportService _reports = ReportService();

  // One date-bounded stream (last 8 weeks) feeds both the Peak Hours card and
  // the weekly chart, instead of two listeners on the whole collection.
  late final Stream<List<Booking>> _bookingStream = _reports.watch(
    weeks: kReportWeeks,
  );

  @override
  void initState() {
    super.initState();
    // Free any reservations left open past 10:15 PM so the numbers are right.
    ReservationCleanup.run();
  }

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

              StreamBuilder<List<Booking>>(
                stream: _bookingStream,
                builder: (context, bookingSnap) {
                  final bookings = bookingSnap.data ?? const <Booking>[];
                  final weeks = _reports.lastWeeks(bookings, kReportWeeks);
                  final String peakHoursText = bookingSnap.hasError
                      ? 'Unavailable'
                      : (_reports.peakWindow(bookings) ?? 'No data yet');

                  return Column(
                    children: [
                      // Live seat metrics
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('seats')
                            .snapshots(),
                        builder: (context, seatSnapshot) {
                          int totalSeats = 0; // seats in service
                          int occupiedCount = 0;
                          int groundTotal = 0;
                          int groundOccupied = 0;
                          int firstTotal = 0;
                          int firstOccupied = 0;

                          if (seatSnapshot.hasData &&
                              seatSnapshot.data != null) {
                            for (var doc in seatSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;

                              // Broken seats are not usable capacity
                              if (data['isOutOfOrder'] == true) continue;

                              final bool isOccupied =
                                  data['isOccupied'] as bool? ?? false;
                              final seatId = doc.id.toUpperCase();
                              final String floor = (data['floor'] ?? '')
                                  .toString()
                                  .toLowerCase();

                              totalSeats++;
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

                          final int utilizationPercent = totalSeats == 0
                              ? 0
                              : ((occupiedCount / totalSeats) * 100).round();
                          final double groundRatio = groundTotal > 0
                              ? groundOccupied / groundTotal
                              : 0.0;
                          final double firstRatio = firstTotal > 0
                              ? firstOccupied / firstTotal
                              : 0.0;
                          final String busiestFloor = firstRatio > groundRatio
                              ? 'First Floor'
                              : groundRatio > firstRatio
                              ? 'Ground Floor'
                              : 'Even';

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
                                      title: 'Seats In Service',
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
                      ),

                      const SizedBox(height: 24),

                      // Weekly bookings trend: last 8 weeks, comparable week to week
                      _buildTrendCard(weeks, cardBorderColor, textSubColor),
                    ],
                  );
                },
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

  Widget _buildTrendCard(
    List<MapEntry<DateTime, int>> weeks,
    Color borderColor,
    Color textSubColor,
  ) {
    MapEntry<DateTime, int>? busiest;
    for (final w in weeks) {
      if (w.value > 0 && (busiest == null || w.value > busiest.value)) {
        busiest = w;
      }
    }
    final b = busiest;
    final String caption = b == null
        ? 'No bookings recorded in this period yet.'
        : 'Busiest week: week of ${b.key.day}/${b.key.month} with ${b.value} bookings.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last $kReportWeeks weeks, by week starting (day/month)',
            style: TextStyle(fontSize: 12, color: textSubColor),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: TrendChartPainter(
                dataPoints: weeks.map((e) => e.value.toDouble()).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 36.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weeks
                  .map(
                    (e) => Text(
                      '${e.key.day}/${e.key.month}',
                      style: TextStyle(fontSize: 10, color: textSubColor),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          Text(caption, style: TextStyle(fontSize: 13, color: textSubColor)),
        ],
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
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8C919E),
                    fontWeight: FontWeight.w500,
                  ),
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

    if (dataPoints.length < 2) return;

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
