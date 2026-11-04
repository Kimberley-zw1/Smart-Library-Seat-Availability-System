import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:libseat2/shared/activity_logger.dart';

/// One place for "mark a seat out of order", so the Manage Seats screen and
/// the alerts screen behave identically.
///
/// In a single atomic batch it:
///  - flags the seat as out of order (and not occupied)
///  - cancels any active reservation on the seat and notifies the student
///  - closes the reservation_history record and logs the cancellation
///  - resolves any open student report alert for the seat
///  - writes the staff activity log entries
class SeatOutOfOrder {
  /// Returns how many reservations were cancelled.
  static Future<int> mark({
    required String seatId,
    required StaffActor actor,
    String? alertId,
    String? details,
  }) async {
    final db = FirebaseFirestore.instance;
    final librarian = FirebaseAuth.instance.currentUser;
    final String seatLabel = seatId.toUpperCase();

    // Active reservation(s) on this seat
    final reservations = await db
        .collection('reservations')
        .where('seatNumber', isEqualTo: seatId)
        .get();

    // Open student report alerts for this seat
    final Set<String> alertIds = {'report_$seatId', ?alertId};
    final List<DocumentReference<Map<String, dynamic>>> openAlerts = [];
    for (final id in alertIds) {
      final ref = db.collection('admin_alerts').doc(id);
      final snap = await ref.get();
      if (snap.exists && snap.data()?['resolved'] != true) {
        openAlerts.add(ref);
      }
    }

    final batch = db.batch();

    // 1. Seat is out of order and no longer "occupied"
    batch.set(db.collection('seats').doc(seatId), {
      'isOutOfOrder': true,
      'isOccupied': false,
    }, SetOptions(merge: true));

    // 2. Cancel each active reservation on the seat
    for (final resDoc in reservations.docs) {
      final resData = resDoc.data();
      final String studentUid = (resData['userId'] ?? resDoc.id).toString();
      final String studentEmail = (resData['userEmail'] ?? '').toString();

      batch.delete(resDoc.reference);

      // Close the history record so reports can work out how long they stayed
      final String historyId = (resData['historyId'] ?? '').toString();
      if (historyId.isNotEmpty) {
        batch.set(db.collection('reservation_history').doc(historyId), {
          'releasedAt': FieldValue.serverTimestamp(),
          'releasedBy': 'librarian',
        }, SetOptions(merge: true));
      }

      // Tell the student (isRead: false => shows the in-app banner)
      batch.set(
        db
            .collection('users')
            .doc(studentUid)
            .collection('notifications')
            .doc(),
        {
          'title': 'Reservation Cancelled',
          'message':
              'Seat $seatLabel was marked out of order, so your reservation '
              'has been cancelled. Please choose another seat.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        },
      );

      // Shows in the librarian "Cancelled" tab
      batch.set(db.collection('reservation_cancellations_history').doc(), {
        'seatNumber': seatLabel,
        'studentId': studentUid,
        'studentEmail': studentEmail,
        'actionType': 'cancelled',
        'reason': 'seat_out_of_order',
        'cancelledBy': librarian?.email ?? librarian?.uid ?? 'Librarian',
        'cancelledByName': actor.name,
        'cancelledByUid': actor.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ActivityLogger.addToBatch(
        batch,
        actor: actor,
        action: 'reservation_cancelled',
        seatId: seatLabel,
        details:
            'Student: ${studentEmail.isNotEmpty ? studentEmail : studentUid} '
            '(seat marked out of order)',
      );
    }

    // 3. Resolve any open report alert so it leaves Live Alerts
    for (final ref in openAlerts) {
      batch.update(ref, {
        'resolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedByUid': actor.uid,
        'resolvedByName': actor.name,
        'resolvedByRole': actor.role,
      });
    }

    // 4. Staff activity log
    ActivityLogger.addToBatch(
      batch,
      actor: actor,
      action: 'seat_marked_out_of_order',
      seatId: seatLabel,
      details:
          details ??
          (reservations.docs.isEmpty
              ? 'Seat $seatLabel marked out of order'
              : 'Seat $seatLabel marked out of order; '
                    '${reservations.docs.length} reservation(s) cancelled'),
    );

    await batch.commit();
    return reservations.docs.length;
  }
}
