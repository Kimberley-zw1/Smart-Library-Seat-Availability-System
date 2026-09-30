import 'package:flutter/material.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  int _currentIndex = 2; // Overview tab selected

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);
    const textSubColor = Color(0xFF8C919E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Header Section
              const Text(
                'Executive Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Smart Library Analytics',
                style: TextStyle(
                  fontSize: 16,
                  color: textSubColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 24),

              // Metrics Grid (2x2)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Utilization Rate',
                      value: '80%',
                      icon: Icons.show_chart_rounded,
                      iconColor: primaryRed,
                      borderColor: cardBorderColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Peak Hours',
                      value: '10am–1pm',
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
                      value: 'Ground Floor',
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
                      value: '4',
                      icon: Icons.chair_rounded,
                      iconColor: const Color(0xFFA0522D),
                      borderColor: cardBorderColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Weekly Usage Trend Card
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

                    // Custom Painted Line Chart Graphic
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: CustomPaint(painter: TrendChartPainter()),
                    ),
                    const SizedBox(height: 12),

                    // Days Row
                    Row(
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
          onTap: (index) {
            if (index == 0) {
              Navigator.of(context).pop();
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
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

// Custom Painter to render grid lines and trend paths
class TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    for (int i = 0; i <= 3; i++) {
      double y = (size.height / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Chart Lines Paint
    final redPathPaint = Paint()
      ..color = const Color(0xFFC01A32)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final areaStrokePaint = Paint()
      ..color = const Color(0xFFFDE8E9)
      ..strokeWidth = 12.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final innerRedPaint = Paint()
      ..color = const Color(0xFFC01A32)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Outer Axis Line
    final axisPath = Path();
    axisPath.moveTo(20, 10);
    axisPath.lineTo(20, size.height - 10);
    axisPath.lineTo(size.width - 20, size.height - 10);
    canvas.drawPath(axisPath, redPathPaint);

    // Dynamic Wave Trend Path
    final wavePath = Path();
    wavePath.moveTo(size.width * 0.32, size.height * 0.52);
    wavePath.lineTo(size.width * 0.44, size.height * 0.38);
    wavePath.lineTo(size.width * 0.58, size.height * 0.58);
    wavePath.lineTo(size.width * 0.72, size.height * 0.32);

    canvas.drawPath(wavePath, areaStrokePaint);
    canvas.drawPath(wavePath, innerRedPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
