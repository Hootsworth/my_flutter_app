import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:littlebird/widgets/whisper_card.dart';
import 'package:littlebird/screens/create_post_screen.dart';
import 'package:littlebird/screens/profile_screen.dart';
import 'package:littlebird/screens/whisper_detail_screen.dart';
// --- ADDED: Import the new notifications drawer ---
import 'package:littlebird/widgets/notifications_drawer.dart';

class FeedScreen extends StatefulWidget {
  final String currentUserLiHandle;

  const FeedScreen({
    super.key,
    required this.currentUserLiHandle,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchTerm = '';
      _searchController.clear();
    });
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: false,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search whispers...',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            fontSize: 15,
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainer,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: _searchTerm.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: colorScheme.onSurfaceVariant,
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final twentyFourHoursAgo =
    Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Feed')),
        body: const Center(child: Text("Error: Not logged in.")),
      );
    }

    // --- REFACTORED: Outer StreamBuilder for Current User Data ---
    // This now fetches user data (like isPrivate) *before* building the Scaffold
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          // Show a simple loading scaffold
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Error: Could not load user profile.")),
          );
        }

        // --- Get User Data ---
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> followingList = userData['following'] ?? [];
        final Set<String> followingSet = Set<String>.from(followingList);
        final bool isPrivate = userData['isPrivate'] as bool? ?? false;

        // --- RETURN THE MAIN SCAFFOLD WITH THE DRAWER ---
        return Scaffold(
          // --- ADDED: The new drawer ---
          drawer: NotificationsDrawer(
            currentUserId: currentUserId,
            isPrivate: isPrivate,
          ),
          // The body is the CustomScrollView you had before
          body: CustomScrollView(
            slivers: [
              // --- SliverAppBar (Unchanged) ---
              SliverAppBar(
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isSearching
                      ? _buildSearchBar()
                      : const Text(
                    'Feed',
                    key: ValueKey('title_text'),
                  ),
                ),
                floating: true,
                snap: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1.0),
                  child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colorScheme.outline.withOpacity(0.5)),
                ),
                actions: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: _isSearching
                        ? TextButton(
                      key: const ValueKey('cancel_button'),
                      onPressed: _stopSearch,
                      child: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.all(Radius.circular(20)),
                        ),
                      ),
                    )
                        : IconButton(
                      key: const ValueKey('search_icon'),
                      icon: const Icon(Icons.search),
                      onPressed: _startSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // --- _CreatePostBar (Unchanged) ---
              if (!_isSearching)
                SliverToBoxAdapter(
                  child: _CreatePostBar(
                    currentUserLiHandle: widget.currentUserLiHandle,
                    onTap: () => _navigateToCreatePost(context),
                  ),
                ),

              // --- Inner StreamBuilder for Whispers ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('whispers')
                    .where('createdAt', isGreaterThan: twentyFourHoursAgo)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(child: Text('Error: ${snapshot.error}')),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        onPressed: () => _navigateToCreatePost(context),
                      ),
                    );
                  }

                  // --- Filter logic (Unchanged, still works) ---
                  final allDocs = snapshot.data!.docs;
                  final whispers = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['replyToWhisperId'] != null) {
                      return false;
                    }

                    final bool isWhisperPrivate =
                        data['isPrivate'] as bool? ?? false;
                    final String senderId = data['senderId'] as String? ?? '';

                    if (!isWhisperPrivate) {
                      return true;
                    } else {
                      return senderId == currentUserId ||
                          followingSet.contains(senderId);
                    }
                  }).toList();

                  // --- All other list/empty states (Unchanged) ---
                  if (whispers.isEmpty && !_isSearching) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        onPressed: () => _navigateToCreatePost(context),
                      ),
                    );
                  }

                  final List<DocumentSnapshot> searchResults;
                  if (_searchTerm.isEmpty) {
                    searchResults = _isSearching ? [] : whispers;
                  } else {
                    searchResults = whispers.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final text = data['text'] as String? ?? '';
                      final liHandle = data['liHandle'] as String? ?? '';
                      final searchTermLower = _searchTerm.toLowerCase();

                      return text.toLowerCase().contains(searchTermLower) ||
                          liHandle.toLowerCase().contains(searchTermLower);
                    }).toList();
                  }

                  if (_isSearching &&
                      _searchTerm.isNotEmpty &&
                      searchResults.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptySearchState(
                        searchTerm: _searchTerm,
                        textTheme: textTheme,
                        colorScheme: colorScheme,
                      ),
                    );
                  }

                  if (_isSearching && _searchTerm.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptySearchState(
                        searchTerm: '',
                        textTheme: textTheme,
                        colorScheme: colorScheme,
                      ),
                    );
                  }

                  return SliverList.separated(
                    itemCount: searchResults.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colorScheme.outline.withOpacity(0.5),
                      indent: 16 + 40 + 12,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final doc = searchResults[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final whisperId = doc.id;
                      final senderId = data['senderId'] as String?;

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WhisperDetailScreen(
                                whisperId: whisperId,
                                currentUserLiHandle: widget.currentUserLiHandle,
                                currentUserId: currentUserId,
                              ),
                            ),
                          );
                        },
                        child: WhisperCard(
                          data: data,
                          whisperId: whisperId,
                          currentUserId: currentUserId,
                          currentUserLiHandle: widget.currentUserLiHandle,
                          onProfileTap: () {
                            if (senderId != null && senderId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(
                                      userId: senderId,
                                      currentUserLiHandle:
                                      widget.currentUserLiHandle),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToCreatePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return const CreatePostScreen();
      },
    );
  }
}

// --- _CreatePostBar (Unchanged) ---
class _CreatePostBar extends StatelessWidget {
  final String currentUserLiHandle;
  final VoidCallback onTap;
  const _CreatePostBar(
      {required this.currentUserLiHandle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Text(
                    currentUserLiHandle.isNotEmpty &&
                        currentUserLiHandle.length > 1
                        ? currentUserLiHandle[1].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      'Start a whisper...',
                      style: textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
                height: 1,
                thickness: 0.5,
                color: colorScheme.outline.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// --- _EmptyState (Unchanged) ---
class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.colorScheme,
        required this.textTheme,
        required this.onPressed});
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 48,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'It\'s quiet in here',
              style: textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Whispers from the last 24 hours will appear here. Be the first to start a conversation!',
              style: textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Start a Whisper'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- _EmptySearchState (Unchanged) ---
class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState(
      {required this.searchTerm,
        required this.textTheme,
        required this.colorScheme});
  final String searchTerm;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  @override
  Widget build(BuildContext context) {
    if (searchTerm.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                'Search Whispers',
                style: textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Find whispers by text content or user @liHandle.',
                style: textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'No results for',
              style: textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '"$searchTerm"',
              style: textTheme.headlineSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              'Try a different search term or check for typos.',
              style: textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}