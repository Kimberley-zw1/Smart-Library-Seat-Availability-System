import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libseat2/shared/activity_logger.dart';

/// Lets an admin create a librarian or admin account.
/// [role] must be 'librarian' or 'admin'.
class AdminAddStaffScreen extends StatefulWidget {
  final String role;

  const AdminAddStaffScreen({super.key, required this.role});

  @override
  State<AdminAddStaffScreen> createState() => _AdminAddStaffScreenState();
}

class _AdminAddStaffScreenState extends State<AdminAddStaffScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _isAdminRole => widget.role.toLowerCase() == 'admin';

  String get _roleTitle => _isAdminRole ? 'Administrator' : 'Librarian';

  IconData get _roleIcon => _isAdminRole
      ? Icons.settings_rounded
      : Icons.collections_bookmark_rounded;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color color = const Color(0xFFC01A32)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  Future<void> _createAccount() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar('Please fill in all required fields.');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showSnackBar('Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    // A second Firebase app instance is used to create the account so the
    // admin stays signed in (creating a user normally signs that user in).
    FirebaseApp? secondaryApp;

    try {
      // Who is creating the account (the signed-in admin). Looked up first so
      // nothing is created if it fails.
      final actor = await StaffActor.current(role: 'admin');

      try {
        secondaryApp = Firebase.app('staffCreation');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'staffCreation',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUser = credential.user;
      if (newUser == null) {
        throw Exception('Account could not be created.');
      }

      try {
        await newUser.updateDisplayName(fullName);

        // Written with the ADMIN's session (default Firestore instance).
        // The profile, the audit alert and the activity entry are saved in
        // one batch, so there is never a staff account without a record of
        // who created it.
        final db = FirebaseFirestore.instance;
        final batch = db.batch();
        final summary = 'Created $_roleTitle account: $fullName ($email)';

        batch.set(db.collection('users').doc(newUser.uid), {
          'uid': newUser.uid,
          'fullName': fullName,
          'email': email,
          'role': widget.role.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch.set(db.collection('admin_alerts').doc(), {
          'title': 'Staff Account Created',
          'subtitle': summary,
          'description': summary,
          'type': 'creation',
          ...actor.toFields(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        ActivityLogger.addToBatch(
          batch,
          actor: actor,
          action: 'staff_added',
          details: summary,
        );

        await batch.commit();
      } catch (e) {
        // Don't leave a login with no profile behind
        await newUser.delete();
        rethrow;
      }

      await secondaryAuth.signOut();

      if (!mounted) return;
      _showSnackBar(
        '$_roleTitle account created for $fullName.',
        color: const Color(0xFF2EC4B6),
      );
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_authMessage(e));
    } catch (e) {
      _showSnackBar('Failed to create account: $e');
    } finally {
      try {
        await secondaryApp?.delete();
      } catch (_) {}
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
          'Add $_roleTitle',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // Role graphic
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_roleIcon, size: 44, color: primaryRed),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'New $_roleTitle Account',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'They can log in right away from the portal for this role.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),

              const SizedBox(height: 28),

              // Full name
              TextField(
                controller: _fullNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Temporary Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Confirm password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Share the password securely, and ask them to change it with '
                '"Forgot Password" after their first login.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7E8494)),
              ),

              const SizedBox(height: 28),

              // Create button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Create $_roleTitle Account',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
