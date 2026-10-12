import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LibrarianProfileScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const LibrarianProfileScreen({super.key, required this.onNavigateTab});

  @override
  State<LibrarianProfileScreen> createState() => _LibrarianProfileScreenState();
}

class _LibrarianProfileScreenState extends State<LibrarianProfileScreen> {
  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _showChangePasswordDialog(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'moyo@africau.edu';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Send a password reset link to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset email sent successfully.'),
                    backgroundColor: Color(0xFFC01A32),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: const Color(0xFFC01A32),
                  ),
                );
              }
            },
            child: const Text(
              'Send',
              style: TextStyle(
                color: Color(0xFFC01A32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC01A32);
    final currentUser = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: currentUser != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .snapshots()
              : null,
          builder: (context, snapshot) {
            String name = currentUser?.displayName ?? 'Mr. Moyo';
            String email = currentUser?.email ?? 'moyo@africau.edu';
            String roleTitle = 'Librarian';

            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                name = data['fullName'] ?? data['name'] ?? name;
                email = data['email'] ?? email;
                final r = (data['role'] ?? 'Librarian').toString();
                roleTitle = r[0].toUpperCase() + r.substring(1);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row with Back Button and Profile Title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: primaryRed,
                        size: 26,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => widget.onNavigateTab(
                        0,
                      ), // Switches back to Dashboard tab (index 0)
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Avatar and Bio Details Card
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFF7ECEE),
                        child: Icon(
                          Icons.person_rounded,
                          size: 60,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleTitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Action Menu Buttons
                _buildMenuButton(
                  title: 'Personal Information',
                  icon: Icons.badge_outlined,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logged in as $name ($email)')),
                    );
                  },
                  color: primaryRed,
                ),
                const SizedBox(height: 14),
                _buildMenuButton(
                  title: 'Change Password',
                  icon: Icons.lock_outline_rounded,
                  onPressed: () => _showChangePasswordDialog(context),
                  color: primaryRed,
                ),
                const SizedBox(height: 14),
                _buildMenuButton(
                  title: 'App Settings',
                  icon: Icons.settings_outlined,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'System is running on latest build version.',
                        ),
                      ),
                    );
                  },
                  color: primaryRed,
                ),
                const SizedBox(height: 14),
                _buildMenuButton(
                  title: 'Help & Support',
                  icon: Icons.help_outline_rounded,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Librarian Support'),
                        content: const Text(
                          'For system escalations, contact IT Services at africau.edu.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'OK',
                              style: TextStyle(color: primaryRed),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  color: primaryRed,
                ),
                const SizedBox(height: 14),
                _buildMenuButton(
                  title: 'Log Out',
                  icon: Icons.logout_rounded,
                  onPressed: () => _handleLogout(context),
                  color: Colors.black87,
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12.0),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: double.infinity,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
