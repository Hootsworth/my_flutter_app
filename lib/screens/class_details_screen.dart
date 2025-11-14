import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:url_launcher/url_launcher.dart';

class ClassDetailsScreen extends StatefulWidget {
  final String classId;
  final String className;
  final String userRole;
  final String currentUserLiHandle;

  const ClassDetailsScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.userRole,
    required this.currentUserLiHandle,
  });

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  String? _classCode; // State variable to hold the code

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Fetch the code when the screen loads
    _fetchClassCode();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- NEW: Function to fetch the class code ---
  Future<void> _fetchClassCode() async {
    if (widget.userRole != 'admin') return; // Only admins need the code

    try {
      final doc = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .get();
      if (doc.exists && doc.data()!.containsKey('classCode')) {
        if (mounted) {
          setState(() {
            _classCode = doc.data()!['classCode'] as String;
          });
        }
      }
    } catch (e) {
      // Handle error if needed
      print("Error fetching class code: $e");
    }
  }

  // --- NEW: Dialog to show the class code ---
  void _showInviteCodeDialog() {
    if (_classCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading code... try again in a moment.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Class Invite Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share this code with members you want to join:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SelectableText(
                _classCode!,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy Code'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _classCode!));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class code copied!')),
                  );
                },
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // --- Archive Tab Logic ---

  Stream<QuerySnapshot> _getArchiveStream() {
    return _firestore
        .collection('classes')
        .doc(widget.classId)
        .collection('archive')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _showAddArchiveItemDialog() async {
    final titleController = TextEditingController();
    final linkController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Archive'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                  value!.trim().isEmpty ? 'Please enter a title' : null,
                ),
                TextFormField(
                  controller: linkController,
                  decoration:
                  const InputDecoration(labelText: 'URL (e.g., http...)'),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value!.trim().isEmpty) {
                      return 'Please enter a URL';
                    }
                    // FIX: Added parentheses.
                    // We must check nullability first (?? false)
                    // *before* we negate the expression (!).
                    if (!(Uri.tryParse(value)?.isAbsolute ?? false)) {
                      return 'Please enter a valid URL';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _firestore
                        .collection('classes')
                        .doc(widget.classId)
                        .collection('archive')
                        .add({
                      'title': titleController.text.trim(),
                      'link': linkController.text.trim(),
                      'addedByHandle': widget.currentUserLiHandle,
                      'createdAt': FieldValue.serverTimestamp(),
                      'type': 'link', // For future use (e.g., 'timer')
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link added to archive!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add link: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArchiveTab() {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _getArchiveStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('The archive is empty.'));
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index].data() as Map<String, dynamic>;
              final uri = Uri.tryParse(item['link'] ?? '');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(item['title'] ?? 'No Title'),
                  subtitle: Text('Added by @${item['addedByHandle']}'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: (uri != null)
                      ? () => launchUrl(uri,
                      mode: LaunchMode.externalApplication)
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddArchiveItemDialog,
        tooltip: 'Add to Archive',
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- Members Tab Logic ---

  Stream<QuerySnapshot> _getMembersStream() {
    return _firestore
        .collection('classes')
        .doc(widget.classId)
        .collection('members')
        .snapshots();
  }

  Future<void> _kickMember(String memberId, String memberHandle) async {
    // Confirmation Dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kick @$memberHandle?'),
        content: Text(
            'Are you sure you want to remove @$memberHandle from this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kick', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Use a batch write to remove from both locations
      WriteBatch batch = _firestore.batch();

      // 1. Remove from class's member list
      batch.delete(_firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('members')
          .doc(memberId));

      // 2. Remove from user's membership list
      batch.delete(_firestore
          .collection('users')
          .doc(memberId)
          .collection('classMemberships')
          .doc(widget.classId));

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('@$memberHandle has been kicked.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to kick member: $e')),
      );
    }
  }

  Widget _buildAdminMenu(String memberId, String memberHandle) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'kick':
            _kickMember(memberId, memberHandle);
            break;
          case 'shush':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Shush feature (WIP)')),
            );
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'kick',
          child: ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: Text('Kick Member'),
          ),
        ),
        const PopupMenuItem(
          value: 'shush',
          child: ListTile(
            leading: Icon(Icons.mic_off_outlined),
            title: Text('Shush (WIP)'),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getMembersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No members found.'));
        }

        final members = snapshot.data!.docs;

        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index].data() as Map<String, dynamic>;
            final memberId = members[index].id;
            final memberHandle = member['liHandle'] ?? 'unknown';
            final memberRole = member['role'] ?? 'member';

            // Check if admin tools should be shown
            final bool showAdminTools = widget.userRole == 'admin' &&
                memberId != _currentUser.uid;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(memberRole == 'admin'
                    ? Icons.shield
                    : Icons.person_outline),
                title: Text('@$memberHandle'),
                subtitle: Text(memberRole),
                trailing: showAdminTools
                    ? _buildAdminMenu(memberId, memberHandle)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        // --- NEW: Add invite code button for admins ---
        actions: [
          if (widget.userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Invite Code',
              onPressed: _showInviteCodeDialog,
            ),
        ],
        // --- END NEW ---
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.archive_outlined), text: 'Archive'),
            Tab(icon: Icon(Icons.people_outlined), text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildArchiveTab(),
          _buildMembersTab(),
        ],
      ),
    );
  }
}