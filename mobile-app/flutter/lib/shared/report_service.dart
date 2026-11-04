import 'package:cloud_firestore/cloud_firestore.dart';

import 'library_time.dart';

const int kReportWeeks = 8;
const int kSeasonWeeks = 16;

/// Monday 00:00 (CAT wall-clock, UTC-flagged) of the week containing [catTime].
DateTime weekStartOf(DateTime catTime) => DateTime.utc(
  catTime.year,
  catTime.month,
  catTime.day,
).subtract(Duration(days: catTime.weekday - 1));

/// One reservation from `reservation_history`, with times already in CAT.
class Booking {
  final DateTime at;
  final String floor;
  final DateTime? releasedAt;
  final bool
  autoReleased; // true = student never cancelled; cleared at 10:15 PM

  const Booking({
    required this.at,
    required this.floor,
    this.releasedAt,
    this.autoReleased = false,
  });

  bool get isFirstFloor => floor.toLowerCase().contains('first');

  DateTime get week => weekStartOf(at);

  Duration? get stay {
    final r = releasedAt;
    if (r == null) return null;
    final d = r.difference(at);
    return d.isNegative ? null : d;
  }
}

class ReportService {
  CollectionReference<Map<String, dynamic>> get _history =>
      FirebaseFirestore.instance.collection('reservation_history');

  /// Everything from the start of the earliest of [weeks] calendar weeks (CAT).
  Query<Map<String, dynamic>> _query(int weeks) {
    final sinceUtc = weekStartOf(nowCat())
        .subtract(Duration(days: 7 * (weeks - 1)))
        .subtract(kCatOffset);
    return _history
        .where(
          'reservedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(sinceUtc),
        )
        .orderBy('reservedAt');
  }

  Stream<List<Booking>> watch({int weeks = kReportWeeks}) =>
      _query(weeks).snapshots().map(_toBookings);

  Future<List<Booking>> fetch({int weeks = kReportWeeks}) async =>
      _toBookings(await _query(weeks).get());

  List<Booking> _toBookings(QuerySnapshot<Map<String, dynamic>> snap) {
    final out = <Booking>[];
    for (final d in snap.docs) {
      final m = d.data();
      final reserved = m['reservedAt'];
      if (reserved is! Timestamp) continue; // server timestamp still pending
      final released = m['releasedAt'];
      out.add(
        Booking(
          at: toCat(reserved.toDate()),
          floor: (m['floorName'] ?? '').toString(),
          releasedAt: released is Timestamp ? toCat(released.toDate()) : null,
          autoReleased: m['releasedBy'] == 'auto_close',
        ),
      );
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Aggregations
  // ---------------------------------------------------------------------------

  /// Bookings for each of the last [n] weeks (oldest first), including weeks
  /// with no bookings. [firstFloor]: null = all floors, true/false = one floor.
  List<MapEntry<DateTime, int>> lastWeeks(
    List<Booking> b,
    int n, {
    bool? firstFloor,
  }) {
    final counts = <DateTime, int>{};
    for (final x in b) {
      if (firstFloor != null && x.isFirstFloor != firstFloor) continue;
      counts.update(x.week, (v) => v + 1, ifAbsent: () => 1);
    }
    final thisWeek = weekStartOf(nowCat());
    return List.generate(n, (i) {
      final w = thisWeek.subtract(Duration(days: 7 * (n - 1 - i)));
      return MapEntry(w, counts[w] ?? 0);
    });
  }

  /// Bookings per opening hour (9 to 21), zero-filled.
  Map<int, int> hourCounts(List<Booking> b) {
    final m = <int, int>{for (var h = kOpenHour; h < kCloseHour; h++) h: 0};
    for (final x in b) {
      final h = x.at.hour;
      if (m.containsKey(h)) m[h] = m[h]! + 1;
    }
    return m;
  }

  /// Bookings per weekday, index 0 = Monday ... 6 = Sunday.
  List<int> weekdayCounts(List<Booking> b) {
    final m = List<int>.filled(7, 0);
    for (final x in b) {
      m[x.at.weekday - 1]++;
    }
    return m;
  }

  /// Busiest 3-hour window, or null when there is no data yet.
  String? peakWindow(List<Booking> b) {
    const slots = <String, List<int>>{
      '9am-12pm': [9, 12],
      '12pm-3pm': [12, 15],
      '3pm-6pm': [15, 18],
      '6pm-10pm': [18, 22],
    };
    String? best;
    var bestCount = 0;
    slots.forEach((label, r) {
      final c = b.where((x) => x.at.hour >= r[0] && x.at.hour < r[1]).length;
      if (c > bestCount) {
        bestCount = c;
        best = label;
      }
    });
    return best;
  }

  /// Average stay in minutes for students who cancelled themselves.
  /// (Auto-cleared bookings are excluded: their stay would just be "until closing".)
  int? avgStayMinutes(List<Booking> b) {
    final stays = b
        .where((x) => !x.autoReleased)
        .map((x) => x.stay)
        .whereType<Duration>()
        .toList();
    if (stays.isEmpty) return null;
    final total = stays.fold<int>(0, (s, d) => s + d.inMinutes);
    return (total / stays.length).round();
  }
}
