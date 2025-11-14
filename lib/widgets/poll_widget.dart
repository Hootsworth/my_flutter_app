import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PollWidget extends StatefulWidget {
  final String whisperId;
  final String currentUserId;
  final Map<String, dynamic> data;

  const PollWidget({
    super.key,
    required this.whisperId,
    required this.currentUserId,
    required this.data,
  });

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  late Map<String, List<dynamic>> _votes;
  late List<dynamic> _pollOptions;
  late int _totalVotes;
  late String? _userVote;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  @override
  void didUpdateWidget(PollWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _processData();
    }
  }

  void _processData() {
    _votes = Map<String, List<dynamic>>.from(widget.data['votes'] ?? {});
    _pollOptions = List<dynamic>.from(widget.data['pollOptions'] ?? []);
    _totalVotes = 0;
    _userVote = null;

    _votes.forEach((option, userList) {
      _totalVotes += userList.length;
      if (userList.contains(widget.currentUserId)) {
        _userVote = option;
      }
    });
  }

  // --- Vote logic (Unchanged) ---
  Future<void> _vote(String selectedOption) async {
    if (_isVoting) return;

    setState(() {
      _isVoting = true;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('whispers')
          .doc(widget.whisperId);

      Map<String, dynamic> updateData = {};

      updateData['votes.$selectedOption'] =
          FieldValue.arrayUnion([widget.currentUserId]);

      if (_userVote != null && _userVote != selectedOption) {
        updateData['votes.$_userVote'] =
            FieldValue.arrayRemove([widget.currentUserId]);
      }

      await docRef.update(updateData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cast vote: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- REFACTORED ---
    // User can always vote, but the UI reflects the results
    // The UI is built based on whether the user has voted or not
    final bool hasVoted = _userVote != null;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _pollOptions.map((option) {
            final String optionText = option as String;
            final int voteCount = _votes[optionText]?.length ?? 0;
            final double percentage =
            (_totalVotes == 0) ? 0 : (voteCount / _totalVotes);
            final bool isUserChoice = (_userVote == optionText);

            return _buildPollOptionItem(
                optionText, voteCount, percentage, isUserChoice, hasVoted);
          }).toList(),
        ),
        if (_isVoting)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), // Match item border
                color: Colors.black.withOpacity(0.5),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
    // --- END REFACTORED ---
  }

  // --- REFACTORED Poll Item ---
  Widget _buildPollOptionItem(String option, int voteCount, double percentage,
      bool isUserChoice, bool hasVoted) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      // ClipRRect is important for the InkWell splash to respect border radius
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _vote(option),
          child: Stack(
            children: [
              // --- Percentage background ---
              // This is the gray track
              Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  // Use theme color instead of hardcoded blue
                  color: colorScheme.outline.withOpacity(0.1),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                ),
              ),
              // This is the colored fill
              if (hasVoted)
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      // Use a subtle theme color for the fill
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                ),

              // --- Text and vote info ---
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              option,
                              style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: isUserChoice
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUserChoice) const SizedBox(width: 8),
                          if (isUserChoice)
                            Icon(Icons.check_circle,
                                // Use primary theme color
                                color: colorScheme.primary,
                                size: 18),
                        ],
                      ),
                    ),
                    if (hasVoted)
                      Text(
                        '${(percentage * 100).toStringAsFixed(0)}%',
                        style: textTheme.bodyMedium?.copyWith(
                            fontWeight: isUserChoice
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: colorScheme.onSurface),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
// --- END REFACTORED ---
}