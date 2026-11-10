import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Tells its builder whether a student has reported this seat as out of order
/// and the librarian hasn't checked it yet (the report alert is unresolved).
///
/// Uses the same document the seat detail screen watches:
/// admin_alerts/report_<seatId>.
class ReportedSeatBuilder extends StatelessWidget {
  final String seatId;
  final Widget Function(BuildContext context, bool isReported) builder;

  const ReportedSeatBuilder({
    super.key,
    required this.seatId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_alerts')
          .doc('report_$seatId')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final bool isReported = data != null && data['resolved'] != true;
        return builder(context, isReported);
      },
    );
  }
}
