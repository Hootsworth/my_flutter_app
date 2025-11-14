import 'package:flutter/material.dart';
import 'package:littlebird/widgets/poll_widget.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:littlebird/screens/whisper_detail_screen.dart';

class WhisperCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String whisperId;
  final String currentUserId;
  final String currentUserLiHandle;
  final VoidCallback? onProfileTap;

  const WhisperCard({
    super.key,
    required this.data,
    required this.whisperId,
    required this.currentUserId,
    required this.currentUserLiHandle,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final String text = data['text'] ?? '...';
    final String liHandle = data['liHandle'] as String? ?? '@anonymous';
    final String type = data['type'] ?? 'poll';
    final Timestamp? timestamp = data['createdAt'] as Timestamp?;
    final String timeAgo =
    timestamp != null ? timeago.format(timestamp.toDate()) : 'just now';

    final List<dynamic> likes = data['likes'] ?? [];
    final List<dynamic> rewhispers = data['rewhispers'] ?? [];
    final int commentCount = data['commentCount'] ?? 0;

    final bool isLiked = likes.contains(currentUserId);
    final bool isRewhispered = rewhispers.contains(currentUserId);

    final String avatarLetter = (liHandle.isNotEmpty && liHandle.length > 1)
        ? liHandle[1].toUpperCase()
        : (liHandle.isNotEmpty ? liHandle[0].toUpperCase() : '?');

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- AVATAR (Unchanged) ---
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text(
              avatarLetter,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER (Unchanged) ---
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onProfileTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            liHandle,
                            style: textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        icon: const Icon(Icons.more_horiz, size: 20),
                        padding: EdgeInsets.zero,
                        color: colorScheme.onSurfaceVariant,
                        onPressed: () {
                          // TODO: Implement more options
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // --- TEXT & POLL (Unchanged) ---
                Text(
                  text,
                  style: textTheme.bodyLarge?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                if (type == 'poll')
                  PollWidget(
                    whisperId: whisperId,
                    currentUserId: currentUserId,
                    data: data,
                  ),
                // --- ACTION BUTTONS (Refined) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // --- COMMENT BUTTON (Unchanged) ---
                    _buildActionButton(
                      context,
                      icon: Icons.chat_bubble_outline,
                      onTap: () => _navigateToDetail(context),
                    ),
                    const SizedBox(width: 12),
                    // --- REWHISPER BUTTON (Refined with Animation) ---
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: _buildActionButton(
                        context,
                        // Key is CRITICAL for AnimatedSwitcher
                        key: ValueKey<bool>(isRewhispered),
                        icon: isRewhispered ? Icons.repeat_on : Icons.repeat,
                        color: isRewhispered ? Colors.green : null,
                        onTap: () => _toggleRewhisper(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // --- LIKE BUTTON (Refined with Animation) ---
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: _buildActionButton(
                        context,
                        // Key is CRITICAL for AnimatedSwitcher
                        key: ValueKey<bool>(isLiked),
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.pink : null,
                        onTap: () => _toggleLike(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // --- SHARE BUTTON (Unchanged) ---
                    _buildActionButton(
                      context,
                      icon: Icons.share_outlined,
                      onTap: () => _shareWhisper(liHandle, text),
                    ),
                  ],
                ),
                // --- STATS TEXT (Unchanged) ---
                if (commentCount > 0 || likes.isNotEmpty || rewhispers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      [
                        if (commentCount > 0)
                          "$commentCount repl${commentCount > 1 ? "ies" : "y"}",
                        if (likes.isNotEmpty)
                          "${likes.length} like${likes.length > 1 ? "s" : ""}",
                        if (rewhispers.isNotEmpty)
                          "${rewhispers.length} rewhisper${rewhispers.length > 1 ? "s" : ""}"
                      ].join(' · '),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Logic Functions (Unchanged) ---

  Future<void> _toggleLike() async {
    final docRef =
    FirebaseFirestore.instance.collection('whispers').doc(whisperId);
    final List<dynamic> likes = data['likes'] ?? [];
    final bool isLiked = likes.contains(currentUserId);

    if (isLiked) {
      await docRef.update({
        'likes': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([currentUserId])
      });
    }
  }

  Future<void> _toggleRewhisper() async {
    final docRef =
    FirebaseFirestore.instance.collection('whispers').doc(whisperId);
    final List<dynamic> rewhispers = data['rewhispers'] ?? [];
    final bool isRewhispered = rewhispers.contains(currentUserId);

    if (isRewhispered) {
      await docRef.update({
        'rewhispers': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      await docRef.update({
        'rewhispers': FieldValue.arrayUnion([currentUserId])
      });
    }
  }

  void _shareWhisper(String liHandle, String text) {
    Share.share('Whisper from $liHandle:\n\n"$text"');
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WhisperDetailScreen(
          whisperId: whisperId,
          currentUserId: currentUserId,
          currentUserLiHandle: currentUserLiHandle,
        ),
      ),
    );
  }

  // --- Action Button Helper (CORRECTED) ---
  Widget _buildActionButton(
      BuildContext context, {
        // --- ADDED: Key parameter ---
        Key? key,
        required IconData icon,
        required VoidCallback onTap,
        Color? color,
      }) {
    return IconButton(
      // --- ADDED: Pass the key to the IconButton ---
      key: key,
      icon: Icon(icon, size: 22),
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 22,
    );
  }
}