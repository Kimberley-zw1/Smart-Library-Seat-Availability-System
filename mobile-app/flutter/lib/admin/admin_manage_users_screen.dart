import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libseat2/shared/activity_logger.dart';

import 'admin_add_staff_screen.dart';

class AdminManageUsersScreen extends StatefulWidget {
  const AdminManageUsersScreen({super.key});

  @override
  State<AdminManageUsersScreen> createState() => _AdminManageUsersScreenState();
}

class _AdminManageUsersScreenState extends State<AdminManageUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Student', 'Librarian'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Flags the account as deleted, frees their seat, cancels their reservation
  // and records who did it, all in ONE atomic batch (so there can never be a
  // removal without an audit entry, or an audit entry without a removal).
  // The app blocks flagged users, and their Firebase login is removed later
  // (automatically on their next app open, by the cleanup script, or by hand
  // in the Firebase console).
  Future<void> _removeUser({
    required String userId,
    required String fullName,
    required String email,
    required String role,
  }) async {
    final db = FirebaseFirestore.instance;
    final actor = await StaffActor.current(role: 'admin');
    final batch = db.batch();

    // Free their seat and remove their active reservation
    final resRef = db.collection('reservations').doc(userId);
    final res = await resRef.get();
    if (res.exists) {
      final resData = res.data() ?? <String, dynamic>{};
      final seat = resData['seatNumber']?.toString();
      if (seat != null && seat.isNotEmpty) {
        batch.set(db.collection('seats').doc(seat), {
          'isOccupied': false,
        }, SetOptions(merge: true));
      }

      // Close the history record so reports can work out the stay length
      final historyId = (resData['historyId'] ?? '').toString();
      if (historyId.isNotEmpty) {
        batch.update(db.collection('reservation_history').doc(historyId), {
          'releasedAt': FieldValue.serverTimestamp(),
          'releasedBy': 'admin',
        });
      }

      batch.delete(resRef);
    }

    // Flag the account instead of hard-deleting it
    batch.update(db.collection('users').doc(userId), {
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // Audit entry shown in Alerts & History (admin and librarian), labelled
    // with the admin who did it
    final String summary = 'Deleted $role account: $fullName ($email)';
    batch.set(db.collection('admin_alerts').doc(), {
      'title': 'User Account Removed',
      'subtitle': summary, // read by LibrarianAlertsScreen
      'description': summary,
      'type': 'deletion',
      ...actor.toFields(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Shared staff activity feed
    ActivityLogger.addToBatch(
      batch,
      actor: actor,
      action: 'user_removed',
      details: summary,
    );

    await batch.commit();
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
                          'Are you sure you want to remove $fullName? '
                          'They will no longer be able to use the app.',
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
                      if (userId == FirebaseAuth.instance.currentUser?.uid) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'You cannot delete your own account.',
                            ),
                          ),
                        );
                        return;
                      }

                      try {
                        // Flag the account, free seat, cancel reservation,
                        // and log who did it, all in one go
                        await _removeUser(
                          userId: userId,
                          fullName: fullName,
                          email: email,
                          role: role.toUpperCase(),
                        );

                        if (!mounted) return;
                        Navigator.pop(context); // close bottom sheet
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'User removed and logged successfully',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete user: $e'),
                            backgroundColor: primaryRed,
                          ),
                        );
                      }
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

            // Add Librarian / Add Admin buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 6.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminAddStaffScreen(role: 'librarian'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Add Librarian',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminAddStaffScreen(role: 'admin'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: primaryRed,
                        size: 20,
                      ),
                      label: const Text(
                        'Add Admin',
                        style: TextStyle(
                          color: primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryRed, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
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

                  // Filter by deleted flag, Search Query and Role Filter
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // Hide accounts that have been flagged as deleted
                    if (data['deleted'] == true) return false;

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
                          (data['studentId'] ?? data['id'] ?? 'N/A').toString();

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
