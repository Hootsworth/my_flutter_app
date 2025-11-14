import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsDrawer extends StatefulWidget {
  final String currentUserId;
  final bool isPrivate;

  const NotificationsDrawer({
    super.key,
    required this.currentUserId,
    required this.isPrivate,
  });

  @override
  State<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends State<NotificationsDrawer>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<Tab> _tabs = [
    const Tab(
      icon: Icon(Icons.favorite),
      text: 'Likes',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isPrivate) {
      _tabs.add(
        const Tab(
          icon: Icon(Icons.person_add),
          text: 'Requests',
        ),
      );
    }
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: _tabs,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // --- Likes Tab ---
                  _buildLikesList(context),
                  // --- Follow Requests Tab (if private) ---
                  if (widget.isPrivate) _buildFollowRequestsList(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: LIKES LIST ---
  Widget _buildLikesList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // ASSUMPTION: You have a 'notifications' collection
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: widget.currentUserId)
          .where('type', isEqualTo: 'like') // As requested, no rewhispers
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No new like notifications.'),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final actorLiHandle = data['actorLiHandle'] ?? 'Someone';
            final whisperSnippet = data['whisperTextSnippet'] ?? 'your post';
            final timestamp = data['createdAt'] as Timestamp?;
            final timeAgo = timestamp != null
                ? timeago.format(timestamp.toDate())
                : 'just now';

            return ListTile(
              leading: const Icon(Icons.favorite, color: Colors.pink),
              title: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: actorLiHandle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' liked $whisperSnippet'),
                  ],
                ),
              ),
              subtitle: Text(timeAgo),
              onTap: () {
                // TODO: Navigate to the whisper detail screen
                // Navigator.pop(context); // Close drawer
                // Navigator.push( ... WhisperDetailScreen ... )
              },
            );
          },
        );
      },
    );
  }

  // --- WIDGET: FOLLOW REQUESTS LIST ---
  Widget _buildFollowRequestsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // ASSUMPTION: You store requests in users/{id}/followRequests
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('followRequests')
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No pending follow requests.'),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final requestingUserId = doc.id;
            final liHandle = data['liHandle'] ?? '...';

            return ListTile(
              title: Text(liHandle),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _denyFollowRequest(requestingUserId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _acceptFollowRequest(requestingUserId),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- ACTION: Accept Follow Request ---
  Future<void> _acceptFollowRequest(String requestingUserId) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Add follower to current user's list
    final currentUserDocRef =
    FirebaseFirestore.instance.collection('users').doc(widget.currentUserId);
    batch.update(currentUserDocRef, {
      'followers': FieldValue.arrayUnion([requestingUserId]),
      'followerCount': FieldValue.increment(1),
    });

    // 2. Add current user to requester's following list
    final requesterDocRef =
    FirebaseFirestore.instance.collection('users').doc(requestingUserId);
    batch.update(requesterDocRef, {
      'following': FieldValue.arrayUnion([widget.currentUserId]),
      'followingCount': FieldValue.increment(1),
    });

    // 3. Delete the follow request
    final requestDocRef = currentUserDocRef
        .collection('followRequests')
        .doc(requestingUserId);
    batch.delete(requestDocRef);

    try {
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting request: $e')),
        );
      }
    }
  }

  // --- ACTION: Deny Follow Request ---
  Future<void> _denyFollowRequest(String requestingUserId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('followRequests')
          .doc(requestingUserId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error denying request: $e')),
        );
      }
    }
  }
}