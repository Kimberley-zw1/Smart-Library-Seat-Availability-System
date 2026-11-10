import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libseat2/shared/app_theme.dart';

/// Form where a student describes an issue. The request is saved to the
/// 'admin_alerts' collection so it appears in the admin's alerts.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const List<String> _categories = [
    'Seat problem',
    'Reservation issue',
    'Account or login',
    'Notifications',
    'Other',
  ];

  String _selectedCategory = _categories.first;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color color = const Color(0xFFC01A32)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please log in to send a support request.');
      return;
    }

    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      _showSnackBar('Please fill in the subject and describe your issue.');
      return;
    }

    if (message.length < 10) {
      _showSnackBar('Please describe the issue in a bit more detail.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Pull the student's details so the admin knows who sent it
      String name = user.displayName ?? 'Student';
      String studentId = 'N/A';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      if (data != null) {
        name = (data['fullName'] ?? data['name'] ?? name).toString();
        studentId = (data['studentId'] ?? 'N/A').toString();
      }

      await FirebaseFirestore.instance.collection('admin_alerts').add({
        'title': 'Support Request: $_selectedCategory',
        // 'subtitle' is what the alerts screens display under the title
        'subtitle': '$subject — from $name (ID: $studentId)',
        'type': 'support',
        'category': _selectedCategory,
        'subject': subject,
        'message': message,
        'userId': user.uid,
        'studentName': name,
        'studentId': studentId,
        'userEmail': user.email,
        'status': 'open',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar(
        'Your request has been sent. We will look into it.',
        color: const Color(0xFF2EC4B6),
      );
      Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar('Failed to send request: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        // Background and icon colors come from the app theme
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: primaryRed,
            size: 26,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Help & Support',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us what went wrong and an administrator will look into it.',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // Category
              Text(
                'What is this about?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  final bool isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: primaryRed,
                    backgroundColor: context.colors.card,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : context.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Subject
              TextField(
                controller: _subjectController,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Description
              TextField(
                controller: _messageController,
                maxLength: 500,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Describe your issue',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Send Request',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  'You can also contact IT Services at africau.edu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
