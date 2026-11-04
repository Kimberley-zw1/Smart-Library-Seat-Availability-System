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
