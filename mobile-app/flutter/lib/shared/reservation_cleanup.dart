import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'library_time.dart';

/// Closes reservations that were never cancelled, at 10:15 PM CAT.
///
/// Every reservation carries an `expiresAt` timestamp (10:15 PM CAT on the day
/// it was made). Any signed-in client can run [run]; it frees the seat, deletes
/// the reservation and closes the matching reservation_history record with
/// `releasedAt` = the closing time and `releasedBy` = 'auto_close'.
///
/// How stay time is recorded, for every way a reservation can end:
///   - the history record keeps `reservedAt` (set by the server when booked)
///   - whoever ends the reservation stamps `releasedAt` and `releasedBy`
///       student cancels       -> releasedBy 'student'   (home_screen.dart)
///       librarian cancels     -> releasedBy 'librarian' (librarian_home_screen.dart)
///       admin removes a user  -> releasedBy 'admin'     (admin_manage_users_screen.dart)
///       left open at 10:15 PM -> releasedBy 'auto_close' (this file)
///   - stay time = releasedAt - reservedAt. Both are server timestamps, so the
///     result doesn't depend on the clock of anyone's phone.
///   - auto-closed bookings are reported separately ("forgot to cancel"), and
///     are left out of the average stay, because their stay is just "until
///     closing time" rather than how long the student really used the seat.
///
/// This works on the free Spark plan because it needs no Cloud Function. It runs:
///  - when the student home screen / librarian / admin screens open
///  - when a student starts a reservation
///  - once a minute while the student home screen is open (only does real work
///    the first time the clock passes 10:15 PM)
class ReservationCleanup {
  static DateTime? _lastRun;
  static bool _running = false;

  // Protects against small differences between the phone clock and the server.
  static const Duration _margin = Duration(minutes: 1);

  /// Closes every expired reservation. Never throws. Returns how many were closed.
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
          _addClear(batch, db, doc, withHistory: true);
        }

        try {
          await batch.commit();
          cleared += chunk.length;
        } catch (e) {
          // One bad record (for example a history entry that was already
          // closed by a student at the same moment) fails the whole batch.
          // Fall back to one reservation at a time so the rest still clear.
          debugPrint('Reservation cleanup batch failed, going one by one: $e');
          for (final doc in chunk) {
            if (await _clearOne(db, doc)) cleared++;
          }
        }
      }

      return cleared;
    } catch (e) {
      debugPrint('Reservation cleanup skipped: $e');
      return 0;
    } finally {
      _running = false;
    }
  }

  /// Adds the writes that close one reservation to [batch].
  static void _addClear(
    WriteBatch batch,
    FirebaseFirestore db,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool withHistory,
  }) {
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
    if (withHistory) {
      final historyId = (m['historyId'] ?? '').toString();
      if (historyId.isNotEmpty) {
        batch.update(db.collection('reservation_history').doc(historyId), {
          'releasedAt': m['expiresAt'],
          'releasedBy': 'auto_close',
        });
      }
    }
  }

  /// Closes a single reservation. The seat and reservation are what matter, so
  /// they are saved first; closing the history record is then best-effort.
  static Future<bool> _clearOne(
    FirebaseFirestore db,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final batch = db.batch();
      _addClear(batch, db, doc, withHistory: false);
      await batch.commit();
    } catch (e) {
      debugPrint('Could not clear reservation ${doc.id}: $e');
      return false;
    }

    final m = doc.data();
    final historyId = (m['historyId'] ?? '').toString();
    if (historyId.isNotEmpty) {
      try {
        await db.collection('reservation_history').doc(historyId).update({
          'releasedAt': m['expiresAt'],
          'releasedBy': 'auto_close',
        });
      } catch (_) {
        // Already closed, or missing. Nothing more to do.
      }
    }
    return true;
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
