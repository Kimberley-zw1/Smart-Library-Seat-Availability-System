import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart'; // Import your home screen file here

class ReservationSuccessScreen extends StatefulWidget {
  const ReservationSuccessScreen({super.key});

  @override
  State<ReservationSuccessScreen> createState() =>
      _ReservationSuccessScreenState();
}

class _ReservationSuccessScreenState extends State<ReservationSuccessScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Automatically navigate to Home Page after 2 seconds
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false, // Clears the entire navigation stack
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Prevents memory leaks if the widget is unmounted early
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const successGreen = Color(0xFF8CD3A8);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  color: successGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 110,
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Process Complete',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
