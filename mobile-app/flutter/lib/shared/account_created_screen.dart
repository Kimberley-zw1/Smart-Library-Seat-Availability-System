import 'dart:async';

import 'package:flutter/material.dart';

import 'general_login_screen.dart';

class AccountCreatedScreen extends StatefulWidget {
  const AccountCreatedScreen({super.key});

  @override
  State<AccountCreatedScreen> createState() => _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends State<AccountCreatedScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // Auto-navigate to LoginScreen after 3 seconds
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const GeneralLoginScreen(role: 'student'),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
        );
      }
    });
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

              // Party Popper / Celebration Icon Circle
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F3),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 54)),
                ),
              ),

              const SizedBox(height: 36),

              // Title
              const Text(
                'Account Created!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Body Text
              const Text(
                'Your university student account has been successfully verified and registered. You can now log in to book library seats.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6C757D),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Manual continuation button
              TextButton(
                onPressed: () {
                  _navigationTimer?.cancel();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) =>
                          const GeneralLoginScreen(role: 'student'),
                    ),
                    (route) => false,
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue to Login',
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
