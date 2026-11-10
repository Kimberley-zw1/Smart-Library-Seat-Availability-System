import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// How long a student has to confirm a new booking before it is cancelled.
const Duration kConfirmWindow = Duration(minutes: 5);

/// Extra wait before one student's phone cancels ANOTHER student's
/// unconfirmed booking. (A student's own phone cancels at exactly 5:00.)
const Duration kSweepGrace = Duration(seconds: 20);

/// A new reservation is saved with `confirmed: false`. The student must tap
/// "Confirm Booking" within [kConfirmWindow] of `reservedAt` (a server
/// timestamp), otherwise it is cancelled automatically.
///
/// Reservations without a `confirmed` field (made before this feature) are
/// treated as already confirmed.
class BookingConfirmation {
  BookingConfirmation._();

  // ---------------------------------------------------------------------------
  // Clock: `reservedAt` comes from Firebase's clock, so the countdown compares
  // it with "Firebase time" (this phone's clock plus a measured offset). That
  // keeps the timer right even if the phone or emulator clock is wrong.
  // ---------------------------------------------------------------------------
  static Duration _clockOffset = Duration.zero;
  static bool _clockSynced = false;
  static bool _syncing = false;

  /// Current time on Firebase's clock (falls back to the phone clock until
  /// [syncClock] has finished).
  static DateTime now() => DateTime.now().add(_clockOffset);

  /// Measures the difference between this phone's clock and Firebase's.
  /// Safe to call many times; it only does the work once per app session.
  static Future<void> syncClock() async {
    if (_clockSynced || _syncing) return;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _syncing = true;
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final DateTime before = DateTime.now();
      await ref.set({
        'lastClockSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final snap = await ref.get(const GetOptions(source: Source.server));
      final DateTime after = DateTime.now();

      final DateTime? server = (snap.data()?['lastClockSync'] as Timestamp?)
          ?.toDate();
      if (server != null) {
        // The server stamped the time somewhere between before and after,
        // so compare it with the middle of that window.
        final DateTime localMid = before.add(
          Duration(microseconds: after.difference(before).inMicroseconds ~/ 2),
        );
        _clockOffset = server.difference(localMid);
        _clockSynced = true;
      }
    } catch (_) {
      // Non-critical: keep using the phone clock
    } finally {
      _syncing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Reading a reservation
  // ---------------------------------------------------------------------------

  /// True while the student still has to confirm this reservation.
  static bool isPending(Map<String, dynamic>? reservation) =>
      reservation != null && reservation['confirmed'] == false;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Marks the student's reservation as confirmed.
  /// Returns false if the reservation no longer exists (already cancelled).
  static Future<bool> confirm(String userId) async {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('reservations').doc(userId);

    return db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      tx.update(ref, {
        'confirmed': true,
        'confirmedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  /// Cancels the reservation if it is still unconfirmed and the time is up.
  /// Frees the seat, closes the history record and tells the student.
  /// Returns true if it cancelled something.
  static Future<bool> cancelIfExpired(
    String userId, {
    Duration grace = Duration.zero,
  }) async {
    final db = FirebaseFirestore.instance;
    final resRef = db.collection('reservations').doc(userId);

    try {
      return await db.runTransaction<bool>((tx) async {
        // All reads first
        final snap = await tx.get(resRef);
        if (!snap.exists) return false;

        final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
        if (data['confirmed'] != false) return false; // confirmed or legacy

        final dynamic reservedAt = data['reservedAt'];
        if (reservedAt is! Timestamp) return false;
        final DateTime deadline = reservedAt.toDate().add(
          kConfirmWindow + grace,
        );
        if (now().isBefore(deadline)) return false;

        final String seatNumber = (data['seatNumber'] ?? '').toString();
        final String historyId = (data['historyId'] ?? '').toString();

        DocumentReference<Map<String, dynamic>>? historyRef;
        bool historyExists = false;
        if (historyId.isNotEmpty) {
          historyRef = db.collection('reservation_history').doc(historyId);
          historyExists = (await tx.get(historyRef)).exists;
        }

        // Writes
        tx.delete(resRef);

        if (seatNumber.isNotEmpty) {
          tx.set(db.collection('seats').doc(seatNumber), {
            'isOccupied': false,
          }, SetOptions(merge: true));
        }

        if (historyRef != null && historyExists) {
          tx.update(historyRef, {
            'releasedAt': FieldValue.serverTimestamp(),
            'releasedBy': 'unconfirmed',
          });
        }

        tx.set(
          db.collection('users').doc(userId).collection('notifications').doc(),
          {
            'title': 'Booking Cancelled',
            'message': seatNumber.isNotEmpty
                ? "Your reservation for seat $seatNumber was cancelled because it wasn't confirmed within ${kConfirmWindow.inMinutes} minutes."
                : "Your reservation was cancelled because it wasn't confirmed within ${kConfirmWindow.inMinutes} minutes.",
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          },
        );

        return true;
      });
    } catch (_) {
      return false;
    }
  }

  /// Cancels every unconfirmed reservation whose time is up. Called from the
  /// student home screen and before a booking, so a seat held by someone who
  /// closed the app is released.
  static Future<void> sweepExpired() async {
    try {
      // Only one field is filtered, so no extra Firestore index is needed.
      final pending = await FirebaseFirestore.instance
          .collection('reservations')
          .where('confirmed', isEqualTo: false)
          .get();

      for (final doc in pending.docs) {
        await cancelIfExpired(doc.id, grace: kSweepGrace);
      }
    } catch (_) {
      // Non-critical: the next sweep tries again
    }
  }
}
