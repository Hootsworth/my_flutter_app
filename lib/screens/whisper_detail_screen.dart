import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:littlebird/widgets/whisper_card.dart';

class WhisperDetailScreen extends StatelessWidget {
  final String whisperId;
  final String currentUserId;
  final String currentUserLiHandle;

  const WhisperDetailScreen({
    super.key,
    required this.whisperId,
    required this.currentUserId,
    required this.currentUserLiHandle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Whisper'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
              height: 1,
              thickness: 0.5,
              color: colorScheme.outline.withOpacity(0.5)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // --- 1. The Main Whisper ---
                SliverToBoxAdapter(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('whispers')
                        .doc(whisperId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final data =
                      snapshot.data!.data() as Map<String, dynamic>;
                      return WhisperCard(
                        data: data,
                        whisperId: whisperId,
                        currentUserId: currentUserId,
                        currentUserLiHandle: currentUserLiHandle,
                        onProfileTap: () {
                          // Tapping profile on detail screen just pops
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colorScheme.outline.withOpacity(0.5),
                  ),
                ),

                // --- 2. The Replies ---
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('whispers')
                      .where('parentWhisperId', isEqualTo: whisperId)
                      .orderBy('createdAt', descending: false) // Show oldest first
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'Be the first to reply!',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      );
                    }

                    final replies = snapshot.data!.docs;

                    return SliverList.separated(
                      itemCount: replies.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: colorScheme.outline.withOpacity(0.5),
                        indent: 16 + 40 + 12,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        final doc = replies[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final replyId = doc.id;
                        // final senderId = data['senderId'] as String?;

                        return WhisperCard(
                          data: data,
                          whisperId: replyId,
                          currentUserId: currentUserId,
                          currentUserLiHandle: currentUserLiHandle,
                          // TODO: Implement navigation to profiles from replies
                          onProfileTap: () {},
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          // --- 3. The Reply Bar ---
          _ReplyBar(
            parentWhisperId: whisperId,
            currentUserId: currentUserId,
            currentUserLiHandle: currentUserLiHandle,
          ),
        ],
      ),
    );
  }
}

// --- WIDGET FOR THE REPLY TEXT FIELD ---
class _ReplyBar extends StatefulWidget {
  final String parentWhisperId;
  final String currentUserId;
  final String currentUserLiHandle;

  const _ReplyBar({
    required this.parentWhisperId,
    required this.currentUserId,
    required this.currentUserLiHandle,
  });

  @override
  State<_ReplyBar> createState() => _ReplyBarState();
}

class _ReplyBarState extends State<_ReplyBar> {
  final _controller = TextEditingController();
  bool _isPosting = false;

  Future<void> _postReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final newWhisperRef =
      FirebaseFirestore.instance.collection('whispers').doc();
      final parentWhisperRef = FirebaseFirestore.instance
          .collection('whispers')
          .doc(widget.parentWhisperId);

      // Create a batch to do both actions at once
      final batch = FirebaseFirestore.instance.batch();

      // 1. Create the new reply whisper
      batch.set(newWhisperRef, {
        'text': text,
        'type': 'whisper', // Replies are always standard whispers
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': widget.currentUserId,
        'liHandle': widget.currentUserLiHandle,
        'parentWhisperId': widget.parentWhisperId, // Link to parent
        'likes': [],
        'rewhispers': [],
        'commentCount': 0,
      });

      // 2. Atomically increment the parent's comment count
      batch.update(parentWhisperRef, {
        'commentCount': FieldValue.increment(1),
      });

      // Commit both operations
      await batch.commit();

      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post reply: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isPosting,
                  decoration: InputDecoration(
                    hintText: 'Post your reply...',
                    filled: true,
                    fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isPosting
                  ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              )
                  : IconButton(
                icon: const Icon(Icons.send),
                onPressed: _postReply,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}