import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Who performed an action. Used by both librarian and admin screens.
///
/// The uid is the stable identifier. The name and role are saved as a snapshot
/// on every log entry so the history still reads correctly if the person is
/// later renamed or removed.
class StaffActor {
  final String uid;
  final String name;
  final String? email;
  final String role; // 'librarian' or 'admin'

  const StaffActor({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  /// Fields to stamp on a shared document (e.g. an alert) so it shows who
  /// created it. Same field names as the activity_log entries.
  Map<String, dynamic> toFields() => {
    'actorUid': uid,
    'actorName': name,
    'actorEmail': email,
    'actorRole': role,
  };

  static final Map<String, String> _nameCache = {};

  /// The currently signed-in staff member. [role] is passed by the screen
  /// ('librarian' or 'admin'), so no extra lookup is needed for it.
  static Future<StaffActor> current({required String role}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No signed-in user.');

    final cached = _nameCache[user.uid];
    String name;
    if (cached != null) {
      name = cached;
    } else {
      name = (user.displayName ?? '').trim();
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final d = snap.data();
        final stored = (d?['name'] ?? d?['fullName'] ?? '').toString().trim();
        if (stored.isNotEmpty) name = stored;
      } catch (_) {
        // fall back to display name / email below
      }
      if (name.isEmpty) name = user.email?.split('@').first ?? user.uid;
      _nameCache[user.uid] = name;
    }

    return StaffActor(uid: user.uid, name: name, email: user.email, role: role);
  }
}

/// One shared `activity_log` collection that every librarian and admin reads.
/// Each entry says WHAT happened and WHO did it.
class ActivityLogger {
  static const String collection = 'activity_log';

  /// Adds the log entry to an existing batch, so the action and its log entry
  /// are saved together or not at all.
  static void addToBatch(
    WriteBatch batch, {
    required StaffActor actor,
    required String action,
    String? seatId,
    String? details,
  }) {
    final ref = FirebaseFirestore.instance.collection(collection).doc();
    batch.set(ref, {
      'action': action,
      'seatId': seatId,
      'details': details,
      'actorUid': actor.uid,
      'actorName': actor.name,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// For actions that don't already have a batch.
  static Future<void> log({
    required StaffActor actor,
    required String action,
    String? seatId,
    String? details,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    addToBatch(
      batch,
      actor: actor,
      action: action,
      seatId: seatId,
      details: details,
    );
    await batch.commit();
  }

  /// Newest first. Every staff member gets exactly the same feed.
  static Stream<QuerySnapshot<Map<String, dynamic>>> recent({int limit = 50}) {
    return FirebaseFirestore.instance
        .collection(collection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// "Tendai M. (Librarian)" for display next to an entry.
  static String actorLabel(Map<String, dynamic> d) {
    final name = (d['actorName'] ?? 'Unknown').toString();
    final role = (d['actorRole'] ?? '').toString();
    if (role.isEmpty) return name;
    return '$name (${role[0].toUpperCase()}${role.substring(1)})';
  }

  /// "By: Tendai M. (Librarian)" for an alert document, or '' when the alert
  /// was not created by a staff member (e.g. a student report).
  static String byLine(Map<String, dynamic> d) {
    if ((d['actorName'] ?? '').toString().isNotEmpty) {
      return 'By: ${actorLabel(d)}';
    }
    final sentBy = (d['sentBy'] ?? '').toString();
    return sentBy.isNotEmpty ? 'By: $sentBy' : '';
  }

  /// "Resolved by Tendai M. (Librarian)" for a resolved alert, otherwise ''.
  static String resolvedLine(Map<String, dynamic> d) {
    if (d['resolved'] != true) return '';
    final name = (d['resolvedByName'] ?? 'Unknown').toString();
    final role = (d['resolvedByRole'] ?? '').toString();
    if (role.isEmpty) return 'Resolved by $name';
    return 'Resolved by $name (${role[0].toUpperCase()}${role.substring(1)})';
  }
}
