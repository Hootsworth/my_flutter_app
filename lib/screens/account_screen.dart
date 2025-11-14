import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:littlebird/widgets/whisper_card.dart';
// --- ADDED: Import for the new edit screen ---
import 'package:littlebird/screens/edit_profile_screen.dart';

/// The screen for user's own profile, whispers, and sign out.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(child: Text('Not logged in.')),
      );
    }

    final currentUserId = user.uid;

    return Scaffold(
      // Use a StreamBuilder to fetch the user's document from Firestore
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Account')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // --- Fallback Data ---
          String liHandle = '@anonymous';
          String displayName = 'Anonymous User';
          String? email = user.email;
          String avatarLetter = '?';
          String? bio;
          int followerCount = 0;
          int followingCount = 0;
          bool isPrivate = false; // <-- ADDED

          // --- Live Firestore Data ---
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            liHandle = userData['liHandle'] as String? ?? '@anonymous';
            displayName =
                userData['displayName'] as String? ?? 'Anonymous User';
            email = userData['email'] as String? ?? user.email;
            bio = userData['bio'] as String?;
            followerCount = userData['followerCount'] as int? ?? 0;
            followingCount = userData['followingCount'] as int? ?? 0;
            isPrivate = userData['isPrivate'] as bool? ?? false; // <-- ADDED

            avatarLetter = (liHandle.isNotEmpty && liHandle.length > 1)
                ? liHandle[1].toUpperCase()
                : (displayName.isNotEmpty ? displayName[0].toUpperCase() : '?');
          }

          // --- NEW TABBED LAYOUT ---
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
                        // --- ADDED: Edit Profile Button ---
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            // Navigate to the new EditProfileScreen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(
                                  currentUserId: currentUserId,
                                  initialDisplayName: displayName,
                                  initialLiHandle: liHandle,
                                  initialBio: bio ?? '',
                                  isPrivate: isPrivate,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Edit Profile',
                        ),
                        // --- END ADDED ---
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: _signOut,
                          tooltip: 'Sign Out',
                        ),
                      ],
                    ),
                    // --- Profile Header ---
                    SliverToBoxAdapter(
                      child: _buildProfileHeader(
                        context: context,
                        liHandle: liHandle,
                        displayName: displayName,
                        email: email,
                        avatarLetter: avatarLetter,
                        bio: bio,
                        followerCount: followerCount,
                        followingCount: followingCount,
                        isPrivate: isPrivate, // <-- Pass data
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
                      userId: currentUserId,
                      liHandle: liHandle,
                    ),
                    // --- Rewhispers Tab ---
                    _buildRewhispersList(
                      context: context,
                      userId: currentUserId,
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
  Widget _buildProfileHeader({
    required BuildContext context,
    required String liHandle,
    required String displayName,
    required String? email,
    required String avatarLetter,
    required String? bio,
    required int followerCount,
    required int followingCount,
    required bool isPrivate, // <-- ADDED
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
                    // --- MODIFIED: Added Row for lock icon ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          liHandle,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        // --- Show lock icon if private ---
                        if (isPrivate)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    // --- END MODIFIED ---
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
          if (email != null && email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                email,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }

  /// --- Whispers Tab Body (Unchanged) ---
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
          .where('senderId', isEqualTo: userId)
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
              child: Text('You haven\'t whispered in the last 24 hours.'),
            ),
          );
        }

        final whispers = whisperSnapshot.data!.docs;

        return ListView.separated(
          itemCount: whispers.length,
          padding: EdgeInsets.zero, // Use padding from TabBarView if needed
          itemBuilder: (context, index) {
            final doc = whispers[index];
            final data = doc.data() as Map<String, dynamic>;
            final whisperId = doc.id;

            return WhisperCard(
              data: data,
              whisperId: whisperId,
              currentUserId: userId,
              currentUserLiHandle: liHandle,
            );
          },
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        );
      },
    );
  }

  /// --- Rewhispers Tab Body (Query Corrected) ---
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
      // --- FIX: Corrected field name from 'rewhisperedBy' to 'rewhispers' ---
          .where('rewhispers', arrayContains: userId)
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
              child: Text('You haven\'t rewhispered in the last 24 hours.'),
            ),
          );
        }

        final whispers = whisperSnapshot.data!.docs;

        return ListView.separated(
          itemCount: whispers.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final doc = whispers[index];
            final data = doc.data() as Map<String, dynamic>;
            final whisperId = doc.id;

            return WhisperCard(
              data: data,
              whisperId: whisperId,
              currentUserId: userId,
              currentUserLiHandle: liHandle,
            );
          },
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        );
      },
    );
  }
}

/// --- Delegate for the sticky TabBar (Unchanged) ---
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