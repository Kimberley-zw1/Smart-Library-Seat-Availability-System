import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'library_time.dart';

/// Clears reservations that were never cancelled.
///
/// Every reservation carries an `expiresAt` timestamp (10:15 PM CAT on the day
/// it was made). Any signed-in client can run [run]; it frees the seat, deletes
/// the reservation and stamps `releasedAt` (= the closing time) on the matching
/// reservation_history record, so stay lengths are not inflated.
///
/// This works on the free Spark plan because it needs no Cloud Function. It runs:
///  - when the student home screen / admin screens open
///  - when a student starts a reservation
///  - once a minute while the student home screen is open (only does real work
///    the first time the clock passes 10:15 PM)
class ReservationCleanup {
  static DateTime? _lastRun;
  static bool _running = false;

  // Protects against small differences between the phone clock and the server.
  static const Duration _margin = Duration(minutes: 1);

  /// Clears every expired reservation. Never throws. Returns how many were cleared.
  static Future<int> run() async {
    if (_running) return 0;
    _running = true;
    _lastRun = DateTime.now();

    try {
      final db = FirebaseFirestore.instance;
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(_margin));

      final expired = await db
          .collection('reservations')
          .where('expiresAt', isLessThanOrEqualTo: cutoff)
          .get();

      if (expired.docs.isEmpty) return 0;

      var cleared = 0;
      const chunkSize = 100; // up to 3 writes each, well under the 500 limit

      for (var i = 0; i < expired.docs.length; i += chunkSize) {
        final end = (i + chunkSize < expired.docs.length)
            ? i + chunkSize
            : expired.docs.length;
        final chunk = expired.docs.sublist(i, end);
        final batch = db.batch();

        for (final doc in chunk) {
          final m = doc.data();

          // 1. Remove the reservation
          batch.delete(doc.reference);

          // 2. Free the seat
          final seat = (m['seatNumber'] ?? '').toString();
          if (seat.isNotEmpty) {
            batch.set(db.collection('seats').doc(seat), {
              'isOccupied': false,
            }, SetOptions(merge: true));
          }

          // 3. Close the history record at the closing time
          final historyId = (m['historyId'] ?? '').toString();
          if (historyId.isNotEmpty) {
            batch.update(db.collection('reservation_history').doc(historyId), {
              'releasedAt': m['expiresAt'],
              'releasedBy': 'auto_close',
            });
          }
        }

        await batch.commit();
        cleared += chunk.length;
      }

      return cleared;
    } catch (e) {
      debugPrint('Reservation cleanup skipped: $e');
      return 0;
    } finally {
      _running = false;
    }
  }

  /// Cheap check meant for a timer: only runs once the clock has passed
  /// today's 10:15 PM and no run has happened since then.
  static Future<void> runIfClosingPassed() async {
    final closing = todaysClearTimeUtc();
    final now = DateTime.now().toUtc();
    final last = _lastRun?.toUtc();

    if (now.isAfter(closing.add(_margin)) &&
        (last == null || last.isBefore(closing))) {
      await run();
    }
  }
}
