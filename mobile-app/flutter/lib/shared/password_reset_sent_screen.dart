import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/general_login_screen.dart';

class PasswordResetSentScreen extends StatefulWidget {
  final String email;

  /// Expects 'student', 'librarian', or 'admin'
  final String role;

  const PasswordResetSentScreen({
    super.key,
    required this.email,
    required this.role,
  });

  @override
  State<PasswordResetSentScreen> createState() =>
      _PasswordResetSentScreenState();
}

class _PasswordResetSentScreenState extends State<PasswordResetSentScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // Auto-navigate back to GeneralLoginScreen after 4 seconds
    _navigationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _goToLogin();
      }
    });
  }

  void _goToLogin() {
    _navigationTimer?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GeneralLoginScreen(role: widget.role.toLowerCase()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Mail Icon Circle
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F3),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('📬', style: TextStyle(fontSize: 54)),
                ),
              ),

              const SizedBox(height: 36),

              // Title
              const Text(
                'Check Your Email',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'We have sent a password reset link to:\n${widget.email}\n\nPlease check your inbox and follow the instructions.',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6C757D),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Return to Login Button
              TextButton(
                onPressed: _goToLogin,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Back to Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryRed,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: primaryRed,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
