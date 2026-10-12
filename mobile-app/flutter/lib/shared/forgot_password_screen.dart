import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'general_login_screen.dart';
import 'password_reset_sent_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  /// Expects 'student', 'librarian', or 'admin'
  final String role;

  const ForgotPasswordScreen({super.key, required this.role});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();

    // 1. Basic validation
    if (email.isEmpty) {
      _showSnackBar(
        'Please enter your registered email address.',
        isError: true,
      );
      return;
    }

    // Basic Email format regex check
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('Please enter a valid email address.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Trigger Firebase Password Reset Email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 3. Navigate to confirmation screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                PasswordResetSentScreen(email: email, role: widget.role),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Handle specific Firebase errors
        String message = 'An error occurred. Please try again.';
        if (e.code == 'user-not-found') {
          message = 'No account exists with this email address.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is formatted incorrectly.';
        } else if (e.code == 'too-many-requests') {
          message = 'Too many attempts. Please try again later.';
        } else if (e.message != null) {
          message = e.message!;
        }

        _showSnackBar(message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to send reset link: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError
            ? const Color(0xFFC01A32)
            : const Color(0xFF2EC4B6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Navigation: Back Button linking to General Login with role
                      InkWell(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => GeneralLoginScreen(
                                  role: widget.role.toLowerCase(),
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 4.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                color: primaryRed,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Back',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: primaryRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Heading
                      const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: primaryRed,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description Text
                      const Text(
                        'Enter your registered email address and we will send you a link to reset your password.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF7C7C7C),
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Input Field Label
                      const Text(
                        'Email address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryRed,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Input Field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'user@africau.edu',
                          hintStyle: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 15,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: primaryRed,
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      const SizedBox(height: 24),

                      // Send Reset Link Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handlePasswordReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            disabledBackgroundColor: primaryRed.withOpacity(
                              0.6,
                            ),
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
                              : const Text(
                                  'Send Reset Link',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Link back to General Login Screen with current role
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => GeneralLoginScreen(
                                  role: widget.role.toLowerCase(),
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Back to Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryRed,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
