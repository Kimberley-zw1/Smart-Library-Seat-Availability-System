import 'package:flutter/material.dart';

import 'librarian_home_screen.dart';

class LibrarianLoginScreen extends StatefulWidget {
  const LibrarianLoginScreen({super.key});

  @override
  State<LibrarianLoginScreen> createState() => _LibrarianLoginScreenState();
}

class _LibrarianLoginScreenState extends State<LibrarianLoginScreen> {
  final _usernameEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    // Navigate to the main seat map screen upon successful login
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LibrarianHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32); // Figma primary red accent

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Back Arrow
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: primaryRed,
                    size: 26,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              const SizedBox(height: 16),

              // Book Icon Container
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 55,
                  color: Colors.blue.shade600,
                ),
              ),

              const SizedBox(height: 28),

              // Title & Subtitle
              const Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Log in to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8C919E),
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 36),

              // Username / Email Input
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Username / Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryRed,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'librarian@africau.edu',
                  hintStyle: const TextStyle(color: Color(0xFFA0A5B1)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: primaryRed, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Password Input
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryRed,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(color: Color(0xFFA0A5B1)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF8C919E),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: primaryRed, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Log In Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Forgot Password Link
              GestureDetector(
                onTap: () {
                  // Handle forgot password action
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryRed,
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
