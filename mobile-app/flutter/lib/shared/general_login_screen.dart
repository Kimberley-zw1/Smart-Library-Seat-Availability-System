import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'forgot_password_screen.dart';
import '../shared/role_selection_screen.dart';
import '../student/home_screen.dart';
import '../librarian/librarian_home_screen.dart';
import '../admin/admin_home_screen.dart';

class GeneralLoginScreen extends StatefulWidget {
  /// Expects 'student', 'librarian', or 'admin'
  final String role;

  const GeneralLoginScreen({super.key, required this.role});

  @override
  State<GeneralLoginScreen> createState() => _GeneralLoginScreenState();
}

class _GeneralLoginScreenState extends State<GeneralLoginScreen> {
  final _emailOrIdentifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _isStudent => widget.role.toLowerCase() == 'student';

  String get _roleTitle {
    switch (widget.role.toLowerCase()) {
      case 'librarian':
        return 'Librarian';
      case 'admin':
        return 'Administrator';
      case 'student':
      default:
        return 'Student';
    }
  }

  IconData get _roleIcon {
    switch (widget.role.toLowerCase()) {
      case 'librarian':
        return Icons.collections_bookmark_rounded;
      case 'admin':
        return Icons.settings_rounded;
      case 'student':
      default:
        return Icons.school_rounded;
    }
  }

  Future<void> _handleSubmit() async {
    final input = _emailOrIdentifierController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final studentId = _studentIdController.text.trim();

    // Validation
    if (input.isEmpty ||
        password.isEmpty ||
        (_isSignUp &&
            (fullName.isEmpty ||
                (_isStudent && studentId.isEmpty) ||
                confirmPassword.isEmpty))) {
      _showSnackBar('Please fill in all required fields.');
      return;
    }

    if (_isSignUp && password != confirmPassword) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // --- 1. SIGN UP PROCESS ---
        if (_isStudent) {
          final existingCheck = await FirebaseFirestore.instance
              .collection('users')
              .where('studentId', isEqualTo: studentId)
              .get();

          if (existingCheck.docs.isNotEmpty) {
            _showSnackBar('This student ID is already registered.');
            setState(() => _isLoading = false);
            return;
          }
        }

        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: input, password: password);

        final user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(fullName);

          Map<String, dynamic> userData = {
            'uid': user.uid,
            'fullName': fullName,
            'email': user.email,
            'role': widget.role.toLowerCase(),
            'createdAt': FieldValue.serverTimestamp(),
          };

          if (_isStudent) {
            userData['studentId'] = studentId;
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(userData);

          if (!mounted) return;
          _routeToDashboard(widget.role.toLowerCase());
        }
      } else {
        // --- 2. LOG IN PROCESS ---
        String targetEmail = input;

        if (_isStudent && !input.contains('@')) {
          final query = await FirebaseFirestore.instance
              .collection('users')
              .where('studentId', isEqualTo: input)
              .limit(1)
              .get();

          if (query.docs.isEmpty) {
            _showSnackBar('No account found with this student ID.');
            setState(() => _isLoading = false);
            return;
          }

          final userData = query.docs.first.data();
          targetEmail = userData['email'] ?? '';
          if (targetEmail.isEmpty) {
            _showSnackBar('Associated email address not found.');
            setState(() => _isLoading = false);
            return;
          }
        }

        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: targetEmail, password: password);

        final uid = userCredential.user?.uid;
        if (uid == null) return;

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          final String storedRole = (data?['role'] ?? 'student')
              .toString()
              .toLowerCase();

          if (storedRole != widget.role.toLowerCase()) {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            _showSnackBar(
              'Access denied. This account is registered as a $storedRole, not a $_roleTitle.',
            );
            return;
          }

          if (!mounted) return;
          _routeToDashboard(storedRole);
        } else {
          _showSnackBar('User record not found in database.');
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'An authentication error occurred.');
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _routeToDashboard(String role) {
    Widget destination;
    switch (role) {
      case 'librarian':
        destination = const LibrarianHomeScreen();
        break;
      case 'admin':
        destination = const AdminHomeScreen();
        break;
      case 'student':
      default:
        destination = const HomeScreen();
        break;
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => destination));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFC01A32),
      ),
    );
  }

  @override
  void dispose() {
    _emailOrIdentifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _studentIdController.dispose();
    super.dispose();
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
          icon: const Icon(Icons.arrow_back, color: primaryRed, size: 28),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const RoleSelectionScreen(),
              ),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.power_settings_new_rounded,
              color: primaryRed,
              size: 26,
            ),
            tooltip: 'Exit App',
            onPressed: () => SystemNavigator.pop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // Dynamic Role Graphic Icon
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_roleIcon, size: 50, color: primaryRed),
                ),
              ),

              const SizedBox(height: 20),

              // Title & Subtitle
              Text(
                _isSignUp ? 'Create $_roleTitle Account' : '$_roleTitle Portal',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? 'Fill in your details to register as a $_roleTitle'
                    : (_isStudent
                          ? 'Sign in with your email or student ID'
                          : 'Sign in with your email address'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),

              const SizedBox(height: 36),

              // Full Name (Sign Up only)
              if (_isSignUp) ...[
                TextField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Student ID (Sign Up only, and ONLY for students)
                if (_isStudent) ...[
                  TextField(
                    controller: _studentIdController,
                    decoration: InputDecoration(
                      labelText: 'Student ID',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Email or Student ID Field
              TextField(
                controller: _emailOrIdentifierController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: _isSignUp
                      ? 'Email Address'
                      : (_isStudent ? 'Email or Student ID' : 'Email Address'),
                  prefixIcon: Icon(
                    _isSignUp
                        ? Icons.email_outlined
                        : (_isStudent
                              ? Icons.person_search_outlined
                              : Icons.email_outlined),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password Field with Show/Hide Toggle
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
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

              // Confirm Password Field (Visible only during Sign Up mode)
              if (_isSignUp) ...[
                const SizedBox(height: 16),
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
              ],

              // Forgot Password link (Visible only during Log In mode)
              if (!_isSignUp) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ForgotPasswordScreen(role: widget.role),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: primaryRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 12),

              // Submit Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isSignUp ? 'Register' : 'Log In',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Toggle Sign In / Sign Up Mode
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? 'Already have an account? '
                        : "Don't have an account? ",
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Log In' : 'Register',
                      style: const TextStyle(
                        color: primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
