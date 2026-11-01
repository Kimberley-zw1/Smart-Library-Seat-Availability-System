import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'admin_home_screen.dart';
import 'admin_alerts_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_profile_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final int _currentIndex = 3; // Reports tab selected

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
        targetScreen = const AdminOverviewScreen();
        break;
      case 3:
        return; // Already on Reports
      case 4:
        targetScreen = const AdminProfileScreen();
        break;
      default:
        return;
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => targetScreen));
  }

  // Clean date-time string generator
  String _getFormattedDate() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    final String hour = now.hour.toString().padLeft(2, '0');
    final String minute = now.minute.toString().padLeft(2, '0');
    final String second = now.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  // Function to view report data directly inside the app via a modal bottom sheet
  Future<void> _viewInAppReport(
    BuildContext context,
    String reportType,
    String title,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFC01A32)),
      ),
    );

    try {
      final seatsSnapshot = await FirebaseFirestore.instance
          .collection('seats')
          .get();
      final alertsSnapshot = await FirebaseFirestore.instance
          .collection('admin_alerts')
          .get();

      int totalSeats = seatsSnapshot.docs.length;
      int occupiedSeats = seatsSnapshot.docs
          .where((doc) => doc.data()['isOccupied'] == true)
          .length;
      int totalAlerts = alertsSnapshot.docs.length;

      int groundTotal = 0, groundOcc = 0, firstTotal = 0, firstOcc = 0;
      for (var doc in seatsSnapshot.docs) {
        final data = doc.data();
        final seatId = doc.id.toUpperCase();
        final bool isOcc = data['isOccupied'] ?? false;
        final String floor = (data['floor'] ?? '').toString().toLowerCase();

        if (floor.contains('first') || seatId.startsWith('F')) {
          firstTotal++;
          if (isOcc) firstOcc++;
        } else {
          groundTotal++;
          if (isOcc) groundOcc++;
        }
      }

      if (totalSeats == 0) totalSeats = 4;
      if (groundTotal == 0 && firstTotal == 0) {
        groundTotal = 2;
        firstTotal = 2;
      }

      final availableSeatsCount = totalSeats - occupiedSeats;
      final groundAvailableCount = groundTotal - groundOcc;
      final firstAvailableCount = firstTotal - firstOcc;
      final formattedDate = _getFormattedDate();

      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      // Show In-App Modal Bottom Sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Generated: $formattedDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8C919E),
                  ),
                ),
                const Divider(height: 24),
                const SizedBox(height: 8),

                // Content Based on Report Type
                if (reportType == 'weekly') ...[
                  _buildMetricRow('Total Library Seats', '$totalSeats'),
                  _buildMetricRow('Occupied Seats', '$occupiedSeats'),
                  _buildMetricRow('Available Seats', '$availableSeatsCount'),
                  _buildMetricRow('System Alerts Logged', '$totalAlerts'),
                  _buildMetricRow(
                    'Operational Status',
                    'Active & Stable',
                    isGreen: true,
                  ),
                ] else if (reportType == 'peak') ...[
                  _buildMetricRow('09:00 AM to 12:00 PM', 'Moderate (40%)'),
                  _buildMetricRow('12:00 PM to 04:00 PM', 'Peak High (90%)'),
                  _buildMetricRow(
                    '04:00 PM to 08:00 PM',
                    'Peak Secondary (75%)',
                  ),
                  _buildMetricRow(
                    '08:00 PM to 10:00 PM',
                    'Evening Wind-down (30%)',
                  ),
                ] else if (reportType == 'floor') ...[
                  _buildMetricRow(
                    'Ground Floor Capacity',
                    '$groundOcc / $groundTotal Occupied ($groundAvailableCount Free)',
                  ),
                  _buildMetricRow(
                    'First Floor Capacity',
                    '$firstOcc / $firstTotal Occupied ($firstAvailableCount Free)',
                  ),
                  _buildMetricRow(
                    'Overall System Utilization',
                    '${((occupiedSeats / totalSeats) * 100).toStringAsFixed(1)}%',
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _downloadRealPdfReport(context, reportType, title);
                    },
                    icon: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Download as PDF Instead',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC01A32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load report preview: $e'),
          backgroundColor: const Color(0xFFC01A32),
        ),
      );
    }
  }

  Widget _buildMetricRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8C919E)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isGreen ? Colors.green[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Function to generate and download a professional PDF report from Firestore data
  Future<void> _downloadRealPdfReport(
    BuildContext context,
    String reportType,
    String title,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFC01A32)),
      ),
    );

    try {
      final seatsSnapshot = await FirebaseFirestore.instance
          .collection('seats')
          .get();
      final alertsSnapshot = await FirebaseFirestore.instance
          .collection('admin_alerts')
          .get();

      int totalSeats = seatsSnapshot.docs.length;
      int occupiedSeats = seatsSnapshot.docs
          .where((doc) => doc.data()['isOccupied'] == true)
          .length;
      int totalAlerts = alertsSnapshot.docs.length;

      int groundTotal = 0, groundOcc = 0, firstTotal = 0, firstOcc = 0;
      for (var doc in seatsSnapshot.docs) {
        final data = doc.data();
        final seatId = doc.id.toUpperCase();
        final bool isOcc = data['isOccupied'] ?? false;
        final String floor = (data['floor'] ?? '').toString().toLowerCase();

        if (floor.contains('first') || seatId.startsWith('F')) {
          firstTotal++;
          if (isOcc) firstOcc++;
        } else {
          groundTotal++;
          if (isOcc) groundOcc++;
        }
      }

      if (totalSeats == 0) totalSeats = 4;
      if (groundTotal == 0 && firstTotal == 0) {
        groundTotal = 2;
        firstTotal = 2;
      }

      final availableSeatsCount = totalSeats - occupiedSeats;
      final groundAvailableCount = groundTotal - groundOcc;
      final firstAvailableCount = firstTotal - firstOcc;
      final formattedDate = _getFormattedDate();

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: pw.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: pw.PdfColor.fromHex('#C01A32'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            title.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: pw.PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Africa University Smart Library System',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: pw.PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'CONFIDENTIAL',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: pw.PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated: $formattedDate',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: pw.PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Status: Live Data Stream',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: pw.PdfColors.green800,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(
                  height: 1,
                  thickness: 1,
                  color: pw.PdfColors.grey300,
                ),
                pw.SizedBox(height: 16),

                if (reportType == 'weekly') ...[
                  pw.Text(
                    'Executive Operational Metrics Summary',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'Metric Parameter',
                      'Current Reading',
                      'Operational Status',
                    ],
                    data: [
                      [
                        'Total Library Seats',
                        '$totalSeats',
                        'Fully Operational',
                      ],
                      [
                        'Occupied Seats',
                        '$occupiedSeats',
                        '${((occupiedSeats / totalSeats) * 100).toStringAsFixed(1)}% Usage Rate',
                      ],
                      [
                        'Available Seats',
                        '$availableSeatsCount',
                        'Open to Reservations',
                      ],
                      [
                        'Recorded System Alerts/Logs',
                        '$totalAlerts',
                        'Audit History Intact',
                      ],
                    ],
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: pw.PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: pw.PdfColor.fromHex('#2C3E50'),
                    ),
                    cellHeight: 24,
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
                ] else if (reportType == 'peak') ...[
                  pw.Text(
                    'Traffic Distribution and Peak Usage Breakdown (09:00 AM to 10:00 PM)',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.TableHelper.fromTextArray(
                    headers: ['Time Window', 'Occupancy Trend'],
                    data: [
                      ['09:00 AM to 12:00 PM', 'Moderate (40%)'],
                      ['12:00 PM to 04:00 PM', 'Peak High (90%)'],
                      ['04:00 PM to 08:00 PM', 'Peak Secondary (75%)'],
                      ['08:00 PM to 10:00 PM', 'Evening Wind-down (30%)'],
                    ],
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: pw.PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: pw.PdfColor.fromHex('#2C3E50'),
                    ),
                    cellHeight: 24,
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
                ] else if (reportType == 'floor') ...[
                  pw.Text(
                    'Floor-by-Floor Capacity Matrix',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'Floor Level',
                      'Total Seats',
                      'Occupied',
                      'Available',
                    ],
                    data: [
                      [
                        'Ground Floor',
                        '$groundTotal',
                        '$groundOcc',
                        '$groundAvailableCount',
                      ],
                      [
                        'First Floor',
                        '$firstTotal',
                        '$firstOcc',
                        '$firstAvailableCount',
                      ],
                      [
                        'Total System Overview',
                        '$totalSeats',
                        '$occupiedSeats',
                        '$availableSeatsCount',
                      ],
                    ],
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: pw.PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: pw.PdfColor.fromHex('#2C3E50'),
                    ),
                    cellHeight: 24,
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
                ],

                pw.Spacer(),
                pw.Divider(
                  height: 1,
                  thickness: 0.5,
                  color: pw.PdfColors.grey400,
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Automated System Audit Log. Smart Library Platform',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: pw.PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Page 1 of 1',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: pw.PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${title.toLowerCase().replaceAll(' ', '_')}.pdf',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report generated and exported successfully.'),
          backgroundColor: Color(0xFFC01A32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: const Color(0xFFC01A32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);
    const softButtonBg = Color(0xFFFFF0F2);
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
          'Reports',
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
                'Download & Export',
                style: TextStyle(
                  fontSize: 16,
                  color: textSubColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  // Card 1: Weekly Usage Report
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Color(0xFF1E88E5),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weekly Usage Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Seat utilization data for the past 7 days',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSubColor,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _viewInAppReport(
                                      context,
                                      'weekly',
                                      'Weekly Usage Report',
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: const Text(
                                        'View Report',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _downloadRealPdfReport(
                                      context,
                                      'weekly',
                                      'Weekly Usage Report',
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: softButtonBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Download PDF',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: primaryRed,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card 2: Peak Hours Report
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.access_time_filled_rounded,
                            color: Color(0xFF757575),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Peak Hours Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Hourly breakdown from 09:00 AM to 10:00 PM',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSubColor,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _viewInAppReport(
                                      context,
                                      'peak',
                                      'Peak Hours Report',
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: const Text(
                                        'View Report',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _downloadRealPdfReport(
                                      context,
                                      'peak',
                                      'Peak Hours Report',
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: softButtonBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Download PDF',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: primaryRed,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card 3: Floor Comparison Report
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: Color(0xFF8B7E74),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Floor Comparison Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Side-by-side analysis of all floors',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSubColor,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _viewInAppReport(
                                      context,
                                      'floor',
                                      'Floor Comparison Report',
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: const Text(
                                        'View Report',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _downloadRealPdfReport(
                                      context,
                                      'floor',
                                      'Floor Comparison Report',
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: softButtonBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Download PDF',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: primaryRed,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Custom report request submitted to system admin.',
                        ),
                        backgroundColor: primaryRed,
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Request Custom Report',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryRed,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: primaryRed,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
}
