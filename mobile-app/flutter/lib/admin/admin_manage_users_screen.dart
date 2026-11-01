import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageUsersScreen extends StatefulWidget {
  const AdminManageUsersScreen({super.key});

  @override
  State<AdminManageUsersScreen> createState() => _AdminManageUsersScreenState();
}

class _AdminManageUsersScreenState extends State<AdminManageUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Student', 'Librarian'

  Future<void> _logUserDeletion({
    required String targetUserName,
    required String targetUserEmail,
    required String targetRole,
  }) async {
    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      final adminName = adminUser?.displayName ?? 'Admin';

      await FirebaseFirestore.instance.collection('admin_alerts').add({
        'title': 'User Account Removed',
        'description':
            'Admin ($adminName) deleted $targetRole account: $targetUserName ($targetUserEmail)',
        'type': 'deletion',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error writing deletion audit log: $e');
    }
  }

  void _showUserOptionsModal(BuildContext context, DocumentSnapshot userDoc) {
    const primaryRed = Color(0xFFC01A32);
    final data = userDoc.data() as Map<String, dynamic>;
    final String userId = userDoc.id;
    final String fullName = data['fullName'] ?? data['name'] ?? 'Unknown User';
    final String email = data['email'] ?? 'No email';
    final String role = data['role']?.toString().toLowerCase() ?? 'student';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(fontSize: 14, color: Color(0xFF7E8494)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: role == 'librarian'
                      ? const Color(0xFFFFF0F2)
                      : const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Role: ${role.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: role == 'librarian' ? primaryRed : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Delete User Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    bool? confirm = await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete User'),
                        content: Text(
                          'Are you sure you want to remove $fullName?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      // 1. Delete user from Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .delete();

                      // 2. Automatically write deletion event to admin_alerts history
                      await _logUserDeletion(
                        targetUserName: fullName,
                        targetUserEmail: email,
                        targetRole: role.toUpperCase(),
                      );

                      if (!mounted) return;
                      Navigator.pop(context); // close bottom sheet
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User deleted and logged successfully'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  label: const Text(
                    'Delete User Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
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
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: primaryRed,
            size: 26,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Manage Users',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or ID...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF7E8494),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9F9FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Role Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 6.0,
              ),
              child: Row(
                children: ['All', 'Student', 'Librarian'].map((filter) {
                  bool isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: primaryRed,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      backgroundColor: const Color(0xFFF9F9FB),
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),

            // Users List Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryRed),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users found in database.',
                        style: TextStyle(color: Color(0xFF7E8494)),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  // Filter by Search Query and Role Filter
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['fullName'] ?? data['name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final email = (data['email'] ?? '')
                        .toString()
                        .toLowerCase();
                    final studentId = (data['studentId'] ?? '')
                        .toString()
                        .toLowerCase();
                    final role = (data['role'] ?? 'student')
                        .toString()
                        .toLowerCase();

                    bool matchesSearch =
                        name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        studentId.contains(_searchQuery);

                    bool matchesRole = true;
                    if (_selectedFilter == 'Student') {
                      matchesRole = role == 'student';
                    } else if (_selectedFilter == 'Librarian') {
                      matchesRole = role == 'librarian';
                    }

                    return matchesSearch && matchesRole;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No matching users found.',
                        style: TextStyle(color: Color(0xFF7E8494)),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final userDoc = filteredDocs[index];
                      final data = userDoc.data() as Map<String, dynamic>;
                      final String name =
                          data['fullName'] ?? data['name'] ?? 'Unnamed User';
                      final String email = data['email'] ?? 'No email provided';
                      final String role =
                          data['role']?.toString().toUpperCase() ?? 'STUDENT';
                      final String idNum =
                          data['studentId'] ?? data['id'] ?? 'N/A';

                      bool isLibrarian = role == 'LIBRARIAN';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cardBorderColor,
                            width: 1.2,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _showUserOptionsModal(context, userDoc),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isLibrarian
                                ? const Color(0xFFFFF0F2)
                                : const Color(0xFFF0F5FF),
                            child: Icon(
                              isLibrarian
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.person_rounded,
                              color: isLibrarian ? primaryRed : Colors.blue,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7E8494),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: $idNum | Role: $role',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Color(0xFF7E8494),
                          ),
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
    );
  }
}
