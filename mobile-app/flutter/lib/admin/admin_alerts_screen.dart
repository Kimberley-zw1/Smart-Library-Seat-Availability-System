import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:libseat2/shared/activity_feed.dart';
import 'package:libseat2/shared/activity_logger.dart';

import 'admin_home_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_profile_screen.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  final int _currentIndex = 1; // Alerts tab selected

  // false = Alerts & History (admin_alerts), true = Staff Activity feed
  bool _showActivity = false;

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    Widget targetScreen;
    switch (index) {
      case 0:
        targetScreen = const AdminHomeScreen();
        break;
      case 1:
        return; // Already on Alerts
      case 2:
        targetScreen = const AdminOverviewScreen();
        break;
      case 3:
        targetScreen = const AdminReportsScreen();
        break;
      case 4:
        targetScreen = const AdminProfileScreen();
        break;
      default:
        return;
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => targetScreen));
  }

  // Exact date and time formatter method
  String _formatExactTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final DateTime dt = timestamp.toDate();
    final String year = dt.year.toString();
    final String month = dt.month.toString().padLeft(2, '0');
    final String day = dt.day.toString().padLeft(2, '0');
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String second = dt.second.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:$second';
  }

  // Friendly maintenance date/time, e.g. "Fri, 7 Nov 2026 at 2:00 PM"
  String _formatMaintenanceTime(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String period = dt.hour >= 12 ? 'PM' : 'AM';
    final String minute = dt.minute.toString().padLeft(2, '0');
    return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} '
        '${dt.year} at $hour12:$minute $period';
  }

  // Sends the maintenance notice to every user's notifications, and logs it
  // in admin_alerts (labelled with the admin who sent it) and in the shared
  // staff activity feed. Returns the number of users notified.
  Future<int> _sendMaintenanceNotice(DateTime when, String note) async {
    final db = FirebaseFirestore.instance;
    final admin = FirebaseAuth.instance.currentUser;
    final actor = await StaffActor.current(role: 'admin');
    final String whenText = _formatMaintenanceTime(when);

    final String message =
        'Scheduled library maintenance will take place on $whenText.'
        '${note.isNotEmpty ? ' $note' : ''}'
        ' Please plan your study time accordingly.';

    final usersSnap = await db.collection('users').get();
    final recipients = usersSnap.docs
        .where((doc) => doc.id != admin?.uid)
        .toList();

    // Firestore allows 500 writes per batch, so send in chunks of 400.
    for (int i = 0; i < recipients.length; i += 400) {
      final batch = db.batch();
      for (final userDoc in recipients.skip(i).take(400)) {
        final notifRef = userDoc.reference.collection('notifications').doc();
        batch.set(notifRef, {
          'title': 'Library Maintenance Notice',
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
      await batch.commit();
    }

    // The alert and its activity entry are saved together
    final logBatch = db.batch();
    logBatch.set(db.collection('admin_alerts').doc(), {
      'type': 'maintenance',
      'title': 'Library maintenance scheduled',
      'subtitle': 'Scheduled for $whenText',
      'description':
          'Scheduled for $whenText • Notice sent to ${recipients.length} user(s)'
          '${note.isNotEmpty ? '\nNote: $note' : ''}',
      'maintenanceAt': Timestamp.fromDate(when),
      'sentBy': admin?.email ?? admin?.uid ?? 'Admin',
      ...actor.toFields(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    ActivityLogger.addToBatch(
      logBatch,
      actor: actor,
      action: 'maintenance_notice_sent',
      details: 'Scheduled for $whenText. Sent to ${recipients.length} user(s)',
    );
    await logBatch.commit();

    return recipients.length;
  }

  // ------------------------------------------------------------------
  // Help request helpers
  // ------------------------------------------------------------------

  // First non-empty value among the given keys (as text), or ''.
  String _field(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  // "studentEmail" / "student_email" -> "Student Email"
  String _prettyKey(String key) {
    final String spaced = key
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        );
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _formatValue(dynamic value) {
    if (value is Timestamp) return _formatExactTimestamp(value);
    return value.toString();
  }

  // A help request is an alert that carries a category from the student's
  // help form (or is typed as help / support).
  bool _isHelpRequest(Map<String, dynamic> data) {
    final String kind = (data['type'] ?? '').toString().toLowerCase();
    final String category = (data['category'] ?? '').toString().toLowerCase();
    if (kind.contains('help') || kind.contains('support')) return true;
    return category.isNotEmpty &&
        !category.contains('delet') &&
        !category.contains('remov');
  }

  // Account / login / password problems also get the "send reset link" option.
  bool _isAccountOrLoginRequest(Map<String, dynamic> data) {
    final String text = '${data['category'] ?? ''} ${data['type'] ?? ''}'
        .toLowerCase();
    return text.contains('account') ||
        text.contains('login') ||
        text.contains('log in') ||
        text.contains('sign in') ||
        text.contains('password');
  }

  // Works out which student a help request belongs to: by user id first,
  // then by email, then by student ID.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findStudentDoc(
    Map<String, dynamic> data,
  ) async {
    final db = FirebaseFirestore.instance;

    final String uid = _field(data, [
      'userId',
      'uid',
      'studentUid',
      'userUid',
      'user_id',
    ]);
    if (uid.isNotEmpty) {
      final snap = await db.collection('users').doc(uid).get();
      if (snap.exists) return snap;
    }

    final String email = _field(data, [
      'userEmail',
      'email',
      'studentEmail',
      'user_email',
    ]);
    if (email.isNotEmpty) {
      final q = await db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first;
    }

    final String studentId = _field(data, ['studentId', 'studentID']);
    if (studentId.isNotEmpty) {
      final q = await db
          .collection('users')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first;
    }

    return null;
  }

  // Opens the "Reply to Student" sheet for a help request.
  Future<void> _openReply(
    Map<String, dynamic> requestData,
    String docId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final studentSnap = await _findStudentDoc(requestData);
      if (!mounted) return;
      if (studentSnap == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't match this request to a student account."),
            backgroundColor: Color(0xFFC01A32),
          ),
        );
        return;
      }

      final student = studentSnap.data() ?? <String, dynamic>{};
      final String name = (student['fullName'] ?? student['name'] ?? '')
          .toString();
      final String email = (student['email'] ?? '').toString();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => _ReplySheet(
          studentUid: studentSnap.id,
          studentName: name,
          studentEmail: email,
          requestId: docId,
          requestTitle: _field(requestData, ['title', 'subject', 'action']),
          isAccountIssue: _isAccountOrLoginRequest(requestData),
          alreadyResolved: requestData['resolved'] == true,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not load the student: $e'),
          backgroundColor: const Color(0xFFC01A32),
        ),
      );
    }
  }

  // Shows the complete help request: the message first, then every field.
  //
  // Plain Text is used here (not SelectableText). SelectableText inside a
  // closing bottom sheet can trigger Flutter's "_dependents.isEmpty" assertion,
  // which was the red error screen when closing this sheet. A Copy button
  // replaces text selection.
  void _showRequestDetails(Map<String, dynamic> data, {required String docId}) {
    const primaryRed = Color(0xFFC01A32);
    const textSubColor = Color(0xFF8C919E);

    const messageKeys = [
      'message',
      'description',
      'details',
      'body',
      'content',
      'issue',
      'text',
    ];
    String messageKey = '';
    for (final k in messageKeys) {
      if (data[k] != null && data[k].toString().trim().isNotEmpty) {
        messageKey = k;
        break;
      }
    }
    final String message = messageKey.isEmpty
        ? ''
        : data[messageKey].toString();
    final String title = _field(data, ['title', 'action', 'subject']);
    final entries = data.entries
        .where((e) => e.key != messageKey && e.value != null)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Help Request' : title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Message',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textSubColor,
                                  ),
                                ),
                                InkWell(
                                  onTap: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      sheetContext,
                                    );
                                    await Clipboard.setData(
                                      ClipboardData(text: message),
                                    );
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Message copied.'),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.copy_rounded,
                                          size: 14,
                                          color: primaryRed,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Copy',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: primaryRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9FB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF0E4E5),
                                ),
                              ),
                              child: Text(
                                message,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          const Text(
                            'All details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textSubColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _prettyKey(e.key),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: textSubColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatValue(e.value),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openReply(data, docId);
                      },
                      icon: const Icon(
                        Icons.reply_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Reply to Student',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMaintenanceSheet() {
    const primaryRed = Color(0xFFC01A32);
    const textSubColor = Color(0xFF8C919E);

    final messenger = ScaffoldMessenger.of(context);

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String? errorText;
    bool isSending = false;
    final TextEditingController noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: selectedDate ?? now,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setSheetState(() {
                  selectedDate = picked;
                  errorText = null;
                });
              }
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: ctx,
                initialTime:
                    selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
              );
              if (picked != null) {
                setSheetState(() {
                  selectedTime = picked;
                  errorText = null;
                });
              }
            }

            Future<void> send() async {
              final date = selectedDate;
              final time = selectedTime;

              if (date == null || time == null) {
                setSheetState(() {
                  errorText = 'Please pick both a date and a time.';
                });
                return;
              }

              final DateTime when = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );

              if (!when.isAfter(DateTime.now())) {
                setSheetState(() {
                  errorText = 'The maintenance time must be in the future.';
                });
                return;
              }

              setSheetState(() {
                errorText = null;
                isSending = true;
              });

              try {
                final int count = await _sendMaintenanceNotice(
                  when,
                  noteController.text.trim(),
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Maintenance notice sent to $count user(s).'),
                    backgroundColor: const Color(0xFF2EC4B6),
                  ),
                );
              } catch (e) {
                setSheetState(() {
                  isSending = false;
                  errorText = 'Failed to send notice: $e';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Library Maintenance Notice',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pick when the maintenance will happen. Every user will '
                      'receive a notification.',
                      style: TextStyle(fontSize: 14, color: textSubColor),
                    ),
                    const SizedBox(height: 20),

                    // Date + Time pickers
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSending ? null : pickDate,
                            icon: const Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                            ),
                            label: Text(
                              selectedDate == null
                                  ? 'Select date'
                                  : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryRed,
                              side: const BorderSide(color: primaryRed),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSending ? null : pickTime,
                            icon: const Icon(
                              Icons.access_time_rounded,
                              size: 20,
                            ),
                            label: Text(
                              selectedTime == null
                                  ? 'Select time'
                                  : selectedTime!.format(ctx),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryRed,
                              side: const BorderSide(color: primaryRed),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Optional note
                    TextField(
                      controller: noteController,
                      enabled: !isSending,
                      maxLines: 2,
                      maxLength: 120,
                      decoration: InputDecoration(
                        hintText: 'Optional note (e.g. 2nd floor closed)',
                        filled: true,
                        fillColor: const Color(0xFFF9F9FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    if (errorText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSending ? null : send,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Send Notice to All Users',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(noteController.dispose);
  }

  Widget _buildViewChip(String label, bool selected, VoidCallback onTap) {
    const primaryRed = Color(0xFFC01A32);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: primaryRed,
        backgroundColor: const Color(0xFFF9F9FB),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    const cardBorderColor = Color(0xFFF0E4E5);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryRed),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Alerts & Deletion History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Header Subtitle
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Live platform events & user deletion history logs',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8C919E),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Send Maintenance Notice Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showMaintenanceSheet,
                  icon: const Icon(
                    Icons.build_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Send Maintenance Notice',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // View switch: alerts & history  |  staff activity
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  _buildViewChip(
                    'Alerts & History',
                    !_showActivity,
                    () => setState(() => _showActivity = false),
                  ),
                  _buildViewChip(
                    'Staff Activity',
                    _showActivity,
                    () => setState(() => _showActivity = true),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _showActivity
                  ? ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      children: const [ActivityFeed()],
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('admin_alerts')
                          .orderBy('timestamp', descending: true)
                          .limit(200)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: primaryRed),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No history logs found.',
                              style: TextStyle(
                                color: Color(0xFF8C919E),
                                fontSize: 15,
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          itemCount: docs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final String docId = docs[index].id;
                            final data =
                                docs[index].data() as Map<String, dynamic>;
                            final String title = _field(data, [
                              'title',
                              'action',
                              'subject',
                            ]);
                            final String description = _field(data, [
                              'description',
                              'details',
                              'message',
                            ]);
                            final bool isHelp = _isHelpRequest(data);
                            final String type =
                                (data['type'] ?? data['category'] ?? '')
                                    .toString()
                                    .toLowerCase();
                            final Timestamp? timestamp =
                                data['timestamp'] as Timestamp?;

                            // Who created / resolved this alert
                            final String byLine = ActivityLogger.byLine(data);
                            final String resolvedLine =
                                ActivityLogger.resolvedLine(data);

                            // Using exact timestamp formatting here
                            final String timeString = _formatExactTimestamp(
                              timestamp,
                            );

                            // Check if this is a deletion log item
                            bool isDeletion =
                                !isHelp &&
                                type != 'creation' &&
                                (type.contains('delete') ||
                                    type.contains('remove') ||
                                    title.toLowerCase().contains('delete') ||
                                    title.toLowerCase().contains('removed') ||
                                    title.toLowerCase().contains('account'));

                            // Styling configuration
                            IconData iconData = Icons.notifications_rounded;
                            Color iconColor = const Color(0xFFDCA134);
                            Color avatarBg = const Color(0xFFFEF3DF);

                            if (isDeletion) {
                              iconData = Icons.person_remove_rounded;
                              iconColor = primaryRed;
                              avatarBg = const Color(0xFFFDE8E9);
                            } else if (type == 'creation') {
                              iconData = Icons.person_add_alt_1_rounded;
                              iconColor = const Color(0xFF2EC4B6);
                              avatarBg = const Color(0xFFE6F8F6);
                            } else if (isHelp) {
                              iconData = Icons.support_agent_rounded;
                              iconColor = const Color(0xFF7C5CBF);
                              avatarBg = const Color(0xFFF1ECFA);
                            } else if (type == 'maintenance') {
                              iconData = Icons.build_rounded;
                              iconColor = const Color(0xFF3B82F6);
                              avatarBg = const Color(0xFFEFF6FF);
                            } else if (type == 'report') {
                              iconData = Icons.report_problem_rounded;
                              iconColor = const Color(0xFFDCA134);
                              avatarBg = const Color(0xFFFEF3DF);
                            } else if (type == 'user') {
                              iconData = Icons.person;
                              iconColor = const Color(0xFF6B8096);
                              avatarBg = const Color(0xFFFDE8E9);
                            } else if (type == 'warning') {
                              iconData = Icons.warning_rounded;
                              iconColor = Colors.black87;
                              avatarBg = const Color(0xFFFEF3DF);
                            }

                            return Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDeletion
                                      ? primaryRed.withValues(alpha: 0.3)
                                      : cardBorderColor,
                                  width: isDeletion ? 1.5 : 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar / Icon Badge
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: avatarBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: iconColor,
                                      size: 24,
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  // Title, Description, who & Time Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDeletion
                                                ? primaryRed
                                                : Colors.black87,
                                            height: 1.3,
                                          ),
                                        ),
                                        if (description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            description,
                                            maxLines: isHelp ? 3 : null,
                                            overflow: isHelp
                                                ? TextOverflow.ellipsis
                                                : null,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                        if (byLine.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            byLine,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                        if (resolvedLine.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            resolvedLine,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2EC4B6),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          timeString,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF9E9E9E),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        if (isHelp) ...[
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _showRequestDetails(
                                                      data,
                                                      docId: docId,
                                                    ),
                                                icon: const Icon(
                                                  Icons.article_outlined,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'View Request',
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: primaryRed,
                                                  side: const BorderSide(
                                                    color: primaryRed,
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  textStyle: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _openReply(data, docId),
                                                icon: const Icon(
                                                  Icons.reply_rounded,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                                label: const Text(
                                                  'Reply to Student',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryRed,
                                                  elevation: 0,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1.0)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryRed,
          unselectedItemColor: const Color(0xFF9E9E9E),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              activeIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
              label: 'Overview',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_drive_file_outlined),
              activeIcon: Icon(Icons.insert_drive_file_rounded),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// "Reply to Student" sheet.
//
// The admin writes a message that is delivered to the student inside the app
// (it shows up as a banner and in their notifications). For login problems the
// admin can also send a password reset link by email. Both actions are recorded
// in the staff activity feed with the admin's name.
//
// This is its own StatefulWidget so the text controller is disposed together
// with the sheet (not while it is still animating closed).
// -----------------------------------------------------------------------------
class _ReplySheet extends StatefulWidget {
  final String studentUid;
  final String studentName;
  final String studentEmail;
  final String requestId;
  final String requestTitle;
  final bool isAccountIssue;
  final bool alreadyResolved;

  const _ReplySheet({
    required this.studentUid,
    required this.studentName,
    required this.studentEmail,
    required this.requestId,
    required this.requestTitle,
    required this.isAccountIssue,
    required this.alreadyResolved,
  });

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final TextEditingController _messageController = TextEditingController();
  bool _markResolved = true;
  bool _busy = false;
  String? _error;
  String? _info;

  static const Color _primaryRed = Color(0xFFC01A32);
  static const Color _textSubColor = Color(0xFF8C919E);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String get _studentLabel {
    if (widget.studentName.isNotEmpty) return widget.studentName;
    if (widget.studentEmail.isNotEmpty) return widget.studentEmail;
    return 'Student';
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _info = null;
        _error = 'Please write a message first.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final actor = await StaffActor.current(role: 'admin');
      final bool resolveNow = _markResolved && !widget.alreadyResolved;

      final batch = db.batch();

      // The message the student sees in the app
      final notifRef = db
          .collection('users')
          .doc(widget.studentUid)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'title': widget.requestTitle.isEmpty
            ? 'Reply to your help request'
            : 'Reply: ${widget.requestTitle}',
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false, // shows as a banner on the student's home screen
      });

      // Optionally close the request, labelled with who did it
      if (resolveNow) {
        batch.update(db.collection('admin_alerts').doc(widget.requestId), {
          'resolved': true,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedByUid': actor.uid,
          'resolvedByName': actor.name,
          'resolvedByRole': actor.role,
        });
      }

      final String preview = text.length > 80
          ? '${text.substring(0, 80)}...'
          : text;
      ActivityLogger.addToBatch(
        batch,
        actor: actor,
        action: 'help_request_replied',
        details:
            'To: $_studentLabel. ${resolveNow ? 'Request resolved. ' : ''}'
            'Message: $preview',
      );

      await batch.commit();

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Message sent to $_studentLabel.'),
          backgroundColor: const Color(0xFF2EC4B6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Failed to send message: $e';
      });
    }
  }

  Future<void> _sendResetLink() async {
    if (widget.studentEmail.isEmpty) {
      setState(() {
        _info = null;
        _error = 'This student has no email on file.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: widget.studentEmail,
      );

      // Record who sent it. A logging problem must not make it look like the
      // email itself failed, so it is handled separately.
      try {
        final actor = await StaffActor.current(role: 'admin');
        await ActivityLogger.log(
          actor: actor,
          action: 'password_reset_sent',
          details: 'Reset link sent to ${widget.studentEmail}',
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _busy = false;
        _info = 'Password reset link sent to ${widget.studentEmail}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send reset link: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reply to Student',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.studentEmail.isEmpty
                  ? _studentLabel
                  : '$_studentLabel  •  ${widget.studentEmail}',
              style: const TextStyle(fontSize: 13, color: _textSubColor),
            ),
            if (widget.requestTitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Re: ${widget.requestTitle}',
                style: const TextStyle(fontSize: 13, color: _textSubColor),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              enabled: !_busy,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Write your reply to the student...',
                filled: true,
                fillColor: const Color(0xFFF9F9FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (!widget.alreadyResolved)
              CheckboxListTile(
                value: _markResolved,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _markResolved = v ?? true),
                title: const Text(
                  'Mark this request as resolved',
                  style: TextStyle(fontSize: 14),
                ),
                activeColor: _primaryRed,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: _primaryRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 8),
              Text(
                _info!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2EC4B6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _sendMessage,
                icon: _busy
                    ? const SizedBox.shrink()
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                label: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Send Message',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryRed,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            if (widget.isAccountIssue) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              const Text(
                'Login problem?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Passwords can't be viewed or set from the app. Send the "
                'student a reset link by email instead.',
                style: TextStyle(fontSize: 13, color: _textSubColor),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _sendResetLink,
                  icon: const Icon(Icons.lock_reset_rounded, size: 20),
                  label: const Text(
                    'Send Password Reset Link',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryRed,
                    side: const BorderSide(color: _primaryRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
