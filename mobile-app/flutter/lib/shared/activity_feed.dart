import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'activity_logger.dart';
import 'library_time.dart';

/// The shared staff activity feed. Every librarian and admin sees exactly the
/// same list; each entry shows what happened and who did it.
///
/// Drop it inside a ListView:  ListView(children: const [ActivityFeed()])
class ActivityFeed extends StatefulWidget {
  final int limit;

  const ActivityFeed({super.key, this.limit = 100});

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      ActivityLogger.recent(limit: widget.limit);

  String _roleFilter = 'All'; // 'All', 'Librarians', 'Admins'

  static const Color _primaryRed = Color(0xFFC01A32);
  static const Color _textSubColor = Color(0xFF7E8494);
  static const Color _cardBorderColor = Color(0xFFF0E4E5);

  String _title(Map<String, dynamic> d) {
    final seat = (d['seatId'] ?? '').toString();
    switch ((d['action'] ?? '').toString()) {
      case 'seat_marked_out_of_order':
        return 'Seat $seat marked out of order';
      case 'seat_out_of_order_cleared':
        return 'Seat $seat returned to service';
      case 'seat_released':
        return 'Seat $seat released';
      case 'reservation_cancelled':
        return 'Reservation cancelled (seat $seat)';
      case 'alert_resolved':
        return 'Alert resolved';
      case 'closing_alert_sent':
        return 'Closing alert sent';
      case 'maintenance_notice_sent':
        return 'Maintenance notice sent';
      case 'user_removed':
        return 'User account removed';
      case 'staff_added':
        return 'Staff account added';
      case 'student_details_edited':
        return 'Student details edited';
      case 'password_reset_sent':
        return 'Password reset link sent';
      case 'student_details_edited':
        return 'Student details edited';
      case 'password_reset_sent':
        return 'Password reset link sent';
      default:
        final a = (d['action'] ?? 'Activity').toString();
        return a.replaceAll('_', ' ');
    }
  }

  IconData _icon(String action) {
    if (action.startsWith('seat_')) return Icons.chair_rounded;
    if (action.startsWith('reservation_')) return Icons.cancel_outlined;
    if (action.startsWith('alert_')) return Icons.check_circle_outline_rounded;
    if (action.startsWith('closing_')) return Icons.access_time_filled_rounded;
    if (action.startsWith('maintenance_')) return Icons.build_rounded;
    if (action.startsWith('password_')) return Icons.lock_reset_rounded;
    if (action.startsWith('user_') ||
        action.startsWith('staff_') ||
        action.startsWith('student_')) {
      return Icons.person_rounded;
    }
    return Icons.history_rounded;
  }

  Color _color(String action) {
    if (action == 'seat_marked_out_of_order' || action == 'user_removed') {
      return _primaryRed;
    }
    if (action.startsWith('maintenance_')) return const Color(0xFF3B82F6);
    if (action == 'seat_out_of_order_cleared' ||
        action == 'alert_resolved' ||
        action == 'staff_added') {
      return const Color(0xFF2EC4B6);
    }
    return const Color(0xFFDCA134);
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return 'Just now'; // server timestamp still pending
    final dt = toCat(ts.toDate());
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: ['All', 'Librarians', 'Admins'].map((f) {
            final selected = _roleFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(f),
                selected: selected,
                selectedColor: _primaryRed,
                backgroundColor: const Color(0xFFF9F9FB),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                onSelected: (_) => setState(() => _roleFilter = f),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not load activity: ${snapshot.error}',
                  style: const TextStyle(color: _primaryRed, fontSize: 13),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: _primaryRed),
                ),
              );
            }

            final docs = (snapshot.data?.docs ?? []).where((doc) {
              final role = (doc.data()['actorRole'] ?? '').toString();
              if (_roleFilter == 'Librarians') return role == 'librarian';
              if (_roleFilter == 'Admins') return role == 'admin';
              return true;
            }).toList();

            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 16),
                child: Text(
                  'No staff activity recorded yet.',
                  style: TextStyle(color: _textSubColor, fontSize: 14),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final action = (d['action'] ?? '').toString();
                final color = _color(action);
                final details = (d['details'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorderColor, width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon(action), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(d),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                details,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: _textSubColor,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'By: ${ActivityLogger.actorLabel(d)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(d['timestamp'] as Timestamp?),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
