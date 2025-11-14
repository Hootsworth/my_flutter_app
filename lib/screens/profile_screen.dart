import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:littlebird/widgets/whisper_card.dart'; // Assuming path

/// This screen displays the profile and whispers for *any* user.
class ProfileScreen extends StatefulWidget {
  final String userId; // The user ID of the profile being viewed
  final String currentUserLiHandle;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.currentUserLiHandle,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  /// Handles the logic for following or unfollowing a user
  Future<void> _toggleFollow(bool isCurrentlyFollowing) async {
    if (_currentUserId == null) return;

    final currentUserDocRef =
    FirebaseFirestore.instance.collection('users').doc(_currentUserId);
    final profileUserDocRef =
    FirebaseFirestore.instance.collection('users').doc(widget.userId);

    // Use a batched write to update both documents atomically
    final batch = FirebaseFirestore.instance.batch();

    if (isCurrentlyFollowing) {
      // --- Unfollow Logic ---
      // Remove profile user from current user's 'following' list
      batch.update(currentUserDocRef, {
        'following': FieldValue.arrayRemove([widget.userId]),
        'followingCount': FieldValue.increment(-1),
      });
      // Remove current user from profile user's 'followers' list
      batch.update(profileUserDocRef, {
        'followers': FieldValue.arrayRemove([_currentUserId]),
        'followerCount': FieldValue.increment(-1),
      });
    } else {
      // --- Follow Logic ---
      // Add profile user to current user's 'following' list
      batch.update(currentUserDocRef, {
        'following': FieldValue.arrayUnion([widget.userId]),
        'followingCount': FieldValue.increment(1),
      });
      // Add current user to profile user's 'followers' list
      batch.update(profileUserDocRef, {
        'followers': FieldValue.arrayUnion([_currentUserId]),
        'followerCount': FieldValue.increment(1),
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating follow status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('You must be logged in.')),
      );
    }

    return Scaffold(
      // Use a StreamBuilder to fetch the user's document from Firestore
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Profile')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(title: const Text('Profile')),
              body: const Center(child: Text('User not found.')),
            );
          }

          // --- Live Firestore Data ---
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final liHandle = userData['liHandle'] as String? ?? '@anonymous';
          final displayName =
              userData['displayName'] as String? ?? 'Anonymous User';
          final bio = userData['bio'] as String?;
          final followerCount = userData['followerCount'] as int? ?? 0;
          final followingCount = userData['followingCount'] as int? ?? 0;

          // Check if the current user is following this profile
          final followersList = (userData['followers'] as List? ?? [])
              .map((e) => e.toString())
              .toList();
          final bool isFollowing = followersList.contains(_currentUserId);

          // Replicate the avatar logic
          final avatarLetter = (liHandle.isNotEmpty && liHandle.length > 1)
              ? liHandle[1].toUpperCase() // Get letter after '@'
              : (displayName.isNotEmpty ? displayName[0].toUpperCase() : '?');

          // --- NEW TABBED LAYOUT (from account_screen.dart) ---
          return DefaultTabController(
            length: 2, // "Whispers" and "Rewhispers"
            child: Scaffold(
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      title: Text(liHandle),
                      floating: true,
                      snap: true,
                      actions: [
                        // --- ADDED: Follow Button Logic ---
                        // Only show if it's not the current user's profile
                        if (_currentUserId != widget.userId)
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: isFollowing
                                ? FilledButton.tonal(
                              onPressed: () => _toggleFollow(true),
                              style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              child: const Text('Following'),
                            )
                                : FilledButton(
                              onPressed: () => _toggleFollow(false),
                              style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              child: const Text('Follow'),
                            ),
                          ),
                      ],
                    ),
                    // --- Profile Header ---
                    SliverToBoxAdapter(
                      child: _buildProfileHeader(
                        context: context,
                        liHandle: liHandle,
                        displayName: displayName,
                        avatarLetter: avatarLetter,
                        bio: bio,
                        followerCount: followerCount,
                        followingCount: followingCount,
                      ),
                    ),
                    // --- Sticky Tab Bar ---
                    SliverPersistentHeader(
                      delegate: _SliverTabBarDelegate(
                        const TabBar(
                          tabs: [
                            Tab(text: 'Whispers'),
                            Tab(text: 'Rewhispers'),
                          ],
                        ),
                      ),
                      pinned: true,
                    ),
                  ];
                },
                // --- Tab Content ---
                body: TabBarView(
                  children: [
                    // --- Whispers Tab ---
                    _buildWhispersList(
                      context: context,
                      userId: widget.userId,
                      liHandle: liHandle,
                    ),
                    // --- Rewhispers Tab ---
                    _buildRewhispersList(
                      context: context,
                      userId: widget.userId,
                      liHandle: liHandle,
                    ),
                  ],
                ),
              ),
            ),
          );
          // --- END NEW LAYOUT ---
        },
      ),
    );
  }

  /// Helper widget to build the main profile header
  /// (Copied from account_screen.dart, removed email)
  Widget _buildProfileHeader({
    required BuildContext context,
    required String liHandle,
    required String displayName,
    required String avatarLetter,
    required String? bio,
    required int followerCount,
    required int followingCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget avatarWidget = CircleAvatar(
      radius: 30,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: Text(
        avatarLetter,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      liHandle,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              avatarWidget,
            ],
          ),
          if (bio != null && bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                bio,
                style: textTheme.bodyLarge,
              ),
            ),
          // --- ADDED: Follower Counts ---
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Text(
                  '$followerCount',
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  ' Followers',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  '$followingCount',
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  ' Following',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }

  /// --- ADDED: Whispers Tab Body ---
  Widget _buildWhispersList({
    required BuildContext context,
    required String userId,
    required String liHandle,
  }) {
    final twentyFourHoursAgo =
    Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('whispers')
          .where('senderId', isEqualTo: userId) // <-- Use profile user's ID
          .where('createdAt', isGreaterThan: twentyFourHoursAgo)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, whisperSnapshot) {
        if (whisperSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (whisperSnapshot.hasError) {
          return Center(child: Text('Error: ${whisperSnapshot.error}'));
        }

        if (!whisperSnapshot.hasData || whisperSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child:
              Text('This user hasn\'t whispered in the last 24 hours.'),
            ),
          );
        }

        final whispers = whisperSnapshot.data!.docs;

        return ListView.separated(
          itemCount: whispers.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final doc = whispers[index];
            final data = doc.data() as Map<String, dynamic>;
            final whisperId = doc.id;

            return WhisperCard(
              data: data,
              whisperId: whisperId,
              currentUserId: _currentUserId!,
              currentUserLiHandle: widget.currentUserLiHandle,
            );
          },
          separatorBuilder: (context, index) => const Divider(
            height: 32,
            thickness: 0.5,
            color: Colors.white24,
          ),
        );
      },
    );
  }

  /// --- ADDED: Rewhispers Tab Body ---
  Widget _buildRewhispersList({
    required BuildContext context,
    required String userId,
    required String liHandle,
  }) {
    final twentyFourHoursAgo =
    Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('whispers')
          .where('rewhisperedBy',
          arrayContains: userId) // <-- Use profile user's ID
          .where('createdAt', isGreaterThan: twentyFourHoursAgo)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, whisperSnapshot) {
        if (whisperSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (whisperSnapshot.hasError) {
          return Center(child: Text('Error: ${whisperSnapshot.error}'));
        }

        if (!whisperSnapshot.hasData || whisperSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child:
              Text('This user hasn\'t rewhispered in the last 24 hours.'),
            ),
          );
        }

        final whispers = whisperSnapshot.data!.docs;

        return ListView.separated(
          itemCount: whispers.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final doc = whispers[index];
            final data = doc.data() as Map<String, dynamic>;
            final whisperId = doc.id;

            return WhisperCard(
              data: data,
              whisperId: whisperId,
              currentUserId: _currentUserId!,
              currentUserLiHandle: widget.currentUserLiHandle,
            );
          },
          separatorBuilder: (context, index) => const Divider(
            height: 32,
            thickness: 0.5,
            color: Colors.white24,
          ),
        );
      },
    );
  }
}

/// --- ADDED: A delegate for the sticky TabBar ---
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Add a background color to match the scaffold
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}