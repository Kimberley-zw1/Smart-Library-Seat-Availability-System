import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'admin_home_screen.dart';
import 'admin_alerts_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_profile_screen.dart';
import '../shared/library_time.dart';
import '../shared/report_service.dart';
import '../shared/reservation_cleanup.dart';

// -----------------------------------------------------------------------------
// Small models: every report is built ONCE into a _ReportDoc, and the same
// object is used for the in-app view and the PDF, so the two never disagree.
// (Plain ASCII text is used on purpose: the PDF's default font has no arrows
// or special dashes.)
// -----------------------------------------------------------------------------

class _ReportTable {
  final String heading;
  final List<String> headers;
  final List<List<String>> rows;
  const _ReportTable(this.heading, this.headers, this.rows);
}

class _ReportDoc {
  final String title;
  final String period;
  final List<String> summary;
  final List<_ReportTable> tables;
  final String? note;
  const _ReportDoc({
    required this.title,
    required this.period,
    required this.summary,
    required this.tables,
    this.note,
  });
}

class _ReportDef {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int weeks;
  const _ReportDef({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.weeks = kReportWeeks,
  });
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _hourLabel(int h) {
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12 $suffix';
}

String _share(int part, int total) =>
    total == 0 ? '0%' : '${(part * 100 / total).round()}%';

String _change(int prev, int cur) {
  if (prev == 0) return cur == 0 ? '0%' : 'New';
  final d = ((cur - prev) * 100 / prev).round();
  return d > 0 ? '+$d%' : '$d%';
}

String _vsAverage(int value, double avg) {
  if (avg == 0) return '-';
  final d = ((value - avg) * 100 / avg).round();
  return d > 0 ? '+$d%' : '$d%';
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final int _currentIndex = 3; // Reports tab selected
  final ReportService _reports = ReportService();

  static const Color _primaryRed = Color(0xFFC01A32);

  static const List<_ReportDef> _defs = [
    _ReportDef(
      type: 'weekly',
      title: 'Weekly Usage Report',
      subtitle: 'Bookings week by week, with change and average stay',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF1E88E5),
    ),
    _ReportDef(
      type: 'peak',
      title: 'Peak Hours Report',
      subtitle: 'Hourly breakdown from 09:00 AM to 10:00 PM',
      icon: Icons.access_time_filled_rounded,
      color: Color(0xFF757575),
    ),
    _ReportDef(
      type: 'floor',
      title: 'Floor Comparison Report',
      subtitle: 'Ground vs first floor, week by week',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF8B7E74),
    ),
    _ReportDef(
      type: 'season',
      title: 'Peak Season Report',
      subtitle: 'Busiest weeks and weekdays over the last 16 weeks',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF2E7D32),
      weeks: kSeasonWeeks,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Free any reservations left open past 10:15 PM so reports are up to date.
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

  String _generatedAt() {
    final n = nowCat();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)} ${two(n.hour)}:${two(n.minute)} (CAT)';
  }

  // ---------------------------------------------------------------------------
  // Building the report content (from reservation_history)
  // ---------------------------------------------------------------------------

  _ReportDoc _buildReport(_ReportDef def, List<Booking> b) {
    final weeks = _reports.lastWeeks(b, def.weeks);
    final period =
        '${_day(weeks.first.key)} to ${_day(nowCat())} (last ${def.weeks} weeks)';

    if (b.isEmpty) {
      return _ReportDoc(
        title: def.title,
        period: period,
        summary: const [
          'No bookings have been recorded in this period yet. '
              'Reports fill in automatically as students reserve seats.',
        ],
        tables: const [],
      );
    }

    switch (def.type) {
      case 'weekly':
        return _weeklyReport(def, period, b);
      case 'peak':
        return _peakReport(def, period, b);
      case 'floor':
        return _floorReport(def, period, b);
      default:
        return _seasonReport(def, period, b);
    }
  }

  _ReportDoc _weeklyReport(_ReportDef def, String period, List<Booking> b) {
    final weeks = _reports.lastWeeks(b, def.weeks);
    final cur = weeks.last.value;
    final prev = weeks[weeks.length - 2].value;
    final stay = _reports.avgStayMinutes(b);
    final auto = b.where((x) => x.autoReleased).length;

    final rows = <List<String>>[];
    for (var i = 0; i < weeks.length; i++) {
      final w = weeks[i];
      final inWeek = b.where((x) => x.week == w.key).toList();
      final s = _reports.avgStayMinutes(inWeek);
      rows.add([
        i == weeks.length - 1 ? '${_day(w.key)} (so far)' : _day(w.key),
        '${w.value}',
        i == 0 ? '-' : _change(weeks[i - 1].value, w.value),
        s == null ? '-' : '$s min',
      ]);
    }

    return _ReportDoc(
      title: def.title,
      period: period,
      summary: [
        'This week so far: $cur bookings (last week: $prev, ${_change(prev, cur)}).',
        stay == null
            ? 'Average stay: not enough completed bookings yet.'
            : 'Average stay (students who cancelled): $stay min.',
        'Left open until the 10:15 PM auto-clear: $auto of ${b.length} bookings.',
      ],
      tables: [
        _ReportTable('Bookings per week', [
          'Week starting',
          'Bookings',
          'Change',
          'Avg stay',
        ], rows),
      ],
      note:
          'The current week is still in progress, so compare it with caution.',
    );
  }

  _ReportDoc _peakReport(_ReportDef def, String period, List<Booking> b) {
    final counts = _reports.hourCounts(b);
    final total = b.length;
    final maxCount = counts.values.fold<int>(0, (m, v) => v > m ? v : m);

    var busiestHour = kOpenHour;
    final rows = <List<String>>[];
    for (var h = kOpenHour; h < kCloseHour; h++) {
      final c = counts[h] ?? 0;
      final level = maxCount == 0
          ? '-'
          : c >= maxCount * 0.75
          ? 'High'
          : c >= maxCount * 0.4
          ? 'Medium'
          : 'Low';
      rows.add([
        '${_hourLabel(h)} to ${_hourLabel(h + 1)}',
        '$c',
        _share(c, total),
        level,
      ]);
    }
    for (var h = kOpenHour; h < kCloseHour; h++) {
      if ((counts[h] ?? 0) == maxCount) {
        busiestHour = h;
        break;
      }
    }

    final window = _reports.peakWindow(b);

    return _ReportDoc(
      title: def.title,
      period: period,
      summary: [
        'Busiest hour: ${_hourLabel(busiestHour)} to ${_hourLabel(busiestHour + 1)} '
            '(${_share(maxCount, total)} of bookings).',
        if (window != null) 'Busiest 3-hour window: $window.',
        'Based on $total bookings.',
      ],
      tables: [
        _ReportTable('Bookings by hour of day', [
          'Time window',
          'Bookings',
          'Share',
          'Level',
        ], rows),
      ],
    );
  }

  _ReportDoc _floorReport(_ReportDef def, String period, List<Booking> b) {
    final g = _reports.lastWeeks(b, def.weeks, firstFloor: false);
    final f = _reports.lastWeeks(b, def.weeks, firstFloor: true);

    var gTotal = 0;
    var fTotal = 0;
    final rows = <List<String>>[];
    for (var i = 0; i < g.length; i++) {
      gTotal += g[i].value;
      fTotal += f[i].value;
      rows.add([
        _day(g[i].key),
        '${g[i].value}',
        '${f[i].value}',
        g[i].value > f[i].value
            ? 'Ground'
            : f[i].value > g[i].value
            ? 'First'
            : 'Even',
      ]);
    }
    rows.add([
      'Total',
      '$gTotal',
      '$fTotal',
      gTotal > fTotal
          ? 'Ground'
          : fTotal > gTotal
          ? 'First'
          : 'Even',
    ]);

    final all = gTotal + fTotal;
    return _ReportDoc(
      title: def.title,
      period: period,
      summary: [
        'Ground floor: ${_share(gTotal, all)} of bookings ($gTotal).',
        'First floor: ${_share(fTotal, all)} of bookings ($fTotal).',
      ],
      tables: [
        _ReportTable('Bookings per floor, week by week', [
          'Week starting',
          'Ground',
          'First',
          'Busier',
        ], rows),
      ],
    );
  }

  _ReportDoc _seasonReport(_ReportDef def, String period, List<Booking> b) {
    final weeks = _reports.lastWeeks(b, def.weeks);
    final withData = weeks.where((w) => w.value > 0).toList();

    if (withData.isEmpty) {
      return _ReportDoc(
        title: def.title,
        period: period,
        summary: const ['No bookings have been recorded in this period yet.'],
        tables: const [],
      );
    }

    final total = withData.fold<int>(0, (s, w) => s + w.value);
    final avg = total / withData.length;

    final ranked = [...withData]..sort((a, c) => c.value.compareTo(a.value));
    final top = ranked.take(5).toList();
    final rankRows = <List<String>>[
      for (var i = 0; i < top.length; i++)
        [
          '#${i + 1}',
          'Week of ${_day(top[i].key)}',
          '${top[i].value}',
          _vsAverage(top[i].value, avg),
        ],
    ];

    final wd = _reports.weekdayCounts(b);
    final wdTotal = wd.fold<int>(0, (s, v) => s + v);
    var busiestDay = 0;
    for (var i = 1; i < 7; i++) {
      if (wd[i] > wd[busiestDay]) busiestDay = i;
    }
    final wdRows = <List<String>>[
      for (var i = 0; i < 7; i++)
        [_weekdayNames[i], '${wd[i]}', _share(wd[i], wdTotal)],
    ];

    return _ReportDoc(
      title: def.title,
      period: period,
      summary: [
        'Busiest week: week of ${_day(top.first.key)} with ${top.first.value} bookings.',
        'Busiest weekday: ${_weekdayNames[busiestDay]} (${_share(wd[busiestDay], wdTotal)} of bookings).',
        'Average per active week: ${avg.toStringAsFixed(1)} bookings. '
            'Weeks with data: ${withData.length} of ${def.weeks}.',
      ],
      tables: [
        _ReportTable('Busiest weeks (compared with the average)', [
          'Rank',
          'Week',
          'Bookings',
          'Vs average',
        ], rankRows),
        _ReportTable('Bookings by weekday', [
          'Weekday',
          'Bookings',
          'Share',
        ], wdRows),
      ],
      note: withData.length < 4
          ? 'Only ${withData.length} of ${def.weeks} weeks have bookings so far. '
                'Seasonal patterns become reliable after a full semester of data.'
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Running a report: load once, then show in-app or export as PDF
  // ---------------------------------------------------------------------------

  Future<void> _runReport(_ReportDef def, {required bool asPdf}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _primaryRed)),
    );

    var loadingOpen = true;
    try {
      final bookings = await _reports.fetch(weeks: def.weeks);
      final doc = _buildReport(def, bookings);

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      loadingOpen = false;

      if (asPdf) {
        await _exportPdf(doc);
      } else {
        _showReportSheet(doc);
      }
    } catch (e) {
      if (!mounted) return;
      if (loadingOpen) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load report: $e'),
          backgroundColor: _primaryRed,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // In-app view
  // ---------------------------------------------------------------------------

  void _showReportSheet(_ReportDoc doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          doc.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generated: ${_generatedAt()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8C919E),
                    ),
                  ),
                  Text(
                    'Period: ${doc.period}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8C919E),
                    ),
                  ),
                  const Divider(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in doc.summary)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                line,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          for (final t in doc.tables) ...[
                            const SizedBox(height: 12),
                            Text(
                              t.heading,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildTable(t),
                          ],
                          if (doc.note != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              doc.note!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF8C919E),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _exportPdf(doc);
                      },
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Download as PDF',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTable(_ReportTable t) {
    const lineColor = Color(0xFFEEEEEE);

    Widget cell(String text, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: header ? FontWeight.bold : FontWeight.w500,
          color: header ? const Color(0xFF8C919E) : Colors.black87,
        ),
      ),
    );

    TableRow row(List<String> cells, {bool header = false}) => TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor)),
      ),
      children: cells.map((c) => cell(c, header: header)).toList(),
    );

    return Table(
      columnWidths: {
        0: const FlexColumnWidth(2.4),
        for (var i = 1; i < t.headers.length; i++)
          i: const FlexColumnWidth(1.4),
      },
      children: [row(t.headers, header: true), for (final r in t.rows) row(r)],
    );
  }

  // ---------------------------------------------------------------------------
  // PDF export (same content as the in-app view)
  // ---------------------------------------------------------------------------

  Future<void> _exportPdf(_ReportDoc doc) async {
    try {
      final red = PdfColor.fromHex('#C01A32');
      final navy = PdfColor.fromHex('#2C3E50');
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context ctx) => pw.Column(
            children: [
              pw.Divider(height: 1, thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Automated System Audit Log. Smart Library Platform',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          build: (pw.Context ctx) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: red,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        doc.title.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Africa University Smart Library System',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'CONFIDENTIAL',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Generated: ${_generatedAt()}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Period: ${doc.period}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(height: 1, thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 14),
            ...doc.summary.map(
              (s) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Text('- $s', style: const pw.TextStyle(fontSize: 11)),
              ),
            ),
            for (final t in doc.tables) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                t.heading,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: t.headers,
                data: t.rows,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: navy),
                cellHeight: 24,
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
            if (doc.note != null) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                doc.note!,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${doc.title.toLowerCase().replaceAll(' ', '_')}.pdf',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report generated and exported successfully.'),
          backgroundColor: _primaryRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: _primaryRed,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _buildReportCard(_ReportDef def) {
    const cardBorderColor = Color(0xFFF0E4E5);
    const softButtonBg = Color(0xFFFFF0F2);
    const textSubColor = Color(0xFF8C919E);

    return Container(
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
            child: Icon(def.icon, color: def.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  def.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: textSubColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _runReport(def, asPdf: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
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
                      onTap: () => _runReport(def, asPdf: true),
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
                            color: _primaryRed,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    const textSubColor = Color(0xFF8C919E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryRed),
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
              const SizedBox(height: 6),
              const Text(
                'Built from real reservation history, so weeks can be compared.',
                style: TextStyle(fontSize: 13, color: textSubColor),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < _defs.length; i++) ...[
                _buildReportCard(_defs[i]),
                if (i != _defs.length - 1) const SizedBox(height: 16),
              ],
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Custom report request submitted to system admin.',
                        ),
                        backgroundColor: _primaryRed,
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
                          color: _primaryRed,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: _primaryRed,
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
          selectedItemColor: _primaryRed,
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
