import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

enum PostType { whisper, poll }

class _CreatePostScreenState extends State<CreatePostScreen> {
  PostType _postType = PostType.whisper;
  final TextEditingController _textController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isLoading = false;

  void _addPollOption() {
    if (_pollOptionControllers.length < 4) {
      setState(() {
        _pollOptionControllers.add(TextEditingController());
      });
    }
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length > 2) {
      setState(() {
        _pollOptionControllers[index].dispose();
        _pollOptionControllers.removeAt(index);
      });
    }
  }

  Future<void> _submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Whisper text cannot be empty.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> postData = {
        'text': text,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'rewhispers': [],
        'commentCount': 0,
        'type': _postType == PostType.poll ? 'poll' : 'whisper',
      };

      if (_postType == PostType.poll) {
        List<String> pollOptions = _pollOptionControllers
            .map((controller) => controller.text.trim())
            .where((option) => option.isNotEmpty)
            .toList();

        if (pollOptions.length < 2) {
          throw Exception('Polls must have at least 2 valid options.');
        }

        Map<String, List<dynamic>> votes = {};
        for (var option in pollOptions) {
          votes[option] = [];
        }

        postData['pollOptions'] = pollOptions;
        postData['votes'] = votes;
      }

      await FirebaseFirestore.instance.collection('whispers').add(postData);

      if (mounted) {
        // This will now pop the modal bottom sheet
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- MODIFICATION: Build method refactored for a modal bottom sheet ---
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // We use Padding and viewInsets to move the UI up
    // when the keyboard appears.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        // This makes the column only as tall as its children
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. A new header row to replace the AppBar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button to dismiss the modal
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text(
                'Create Post',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              // The Post button, moved from the AppBar
              _isLoading
                  ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ))
                  : FilledButton(
                onPressed: _submitPost,
                child: const Text('Post'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. The body, wrapped in Flexible to allow scrolling
          //    within the modal if the content is too tall.
          Flexible(
            child: ListView(
              // The parent Padding widget handles the outer spacing
              padding: EdgeInsets.zero,
              children: [
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _textController,
                      autofocus: true,
                      style: textTheme.bodyLarge,
                      decoration: InputDecoration.collapsed(
                        hintText: _postType == PostType.poll
                            ? 'Ask a question...'
                            : 'What\'s on your mind?',
                        hintStyle: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      maxLength: 280,
                      minLines: 5,
                      maxLines: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SegmentedButton<PostType>(
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: PostType.whisper,
                      icon: Icon(Icons.chat_bubble_outline),
                      label: Text('Whisper'),
                    ),
                    ButtonSegment(
                      value: PostType.poll,
                      icon: Icon(Icons.poll_outlined),
                      label: Text('Poll'),
                    ),
                  ],
                  selected: {_postType},
                  onSelectionChanged: (Set<PostType> newSelection) {
                    setState(() {
                      _postType = newSelection.first;
                    });
                  },
                ),
                if (_postType == PostType.poll) ...[
                  const Divider(height: 40),
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 16),
                    child: Text(
                      'Poll Options',
                      style: textTheme.titleLarge
                          ?.copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                  ..._buildPollOptionFields(),
                  const SizedBox(height: 8),
                  if (_pollOptionControllers.length < 4)
                    FilledButton.icon(
                      onPressed: _addPollOption,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add option'),
                    ),
                  // Add some space at the bottom for scrolling
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  // --- END OF MODIFICATION ---

  List<Widget> _buildPollOptionFields() {
    return List.generate(_pollOptionControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pollOptionControllers[index],
                decoration: InputDecoration(
                  hintText: 'Option ${index + 1}',
                  filled: true,
                  fillColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                ),
              ),
            ),
            if (_pollOptionControllers.length > 2)
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _removePollOption(index),
              ),
          ],
        ),
      );
    });
  }
}