// Shared time rules for the library.
//
// Zimbabwe uses CAT (UTC+2, no daylight saving), so a fixed offset is safe and
// gives the same result whatever time zone the phone is set to.

const Duration kCatOffset = Duration(hours: 2);

const int kOpenHour = 9; // reservations open at 9:00 AM
const int kCloseHour = 22; // reservations close at 10:00 PM (exclusive)

// Reservations still open at this time are cleared automatically.
const int kClearHour = 22;
const int kClearMinute = 15; // 10:15 PM

/// Current wall-clock time in CAT.
/// Read .hour / .weekday / .day from it; don't treat it as a true instant.
DateTime nowCat() => DateTime.now().toUtc().add(kCatOffset);

/// Converts any instant to CAT wall-clock time (same convention as nowCat()).
DateTime toCat(DateTime instant) => instant.toUtc().add(kCatOffset);

/// The real instant (in UTC) of today's 10:15 PM CAT.
DateTime todaysClearTimeUtc() {
  final c = nowCat();
  return DateTime.utc(
    c.year,
    c.month,
    c.day,
    kClearHour,
    kClearMinute,
  ).subtract(kCatOffset);
}

/// "2:10 PM" for a CAT wall-clock time (use with toCat()).
String formatClock(DateTime catTime) {
  final int h12 = catTime.hour % 12 == 0 ? 12 : catTime.hour % 12;
  final String mm = catTime.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${catTime.hour >= 12 ? 'PM' : 'AM'}';
}

/// "1h 12m", "35m" or "under 1m" for a length of time.
String formatStay(Duration d) {
  final int minutes = d.inMinutes;
  if (minutes < 1) return 'under 1m';
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}
