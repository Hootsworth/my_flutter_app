import 'package:flutter/foundation.dart';

// An enum to define what kind of message this is
enum MessageType {
  text,
  image,
}

/// A model for an on-device chat message
class ChatMessage {
  final MessageType type;
  final String? text; // Nullable, only for text messages
  final String? filePath; // Nullable, only for image messages
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.type,
    this.text,
    this.filePath,
    required this.timestamp,
    required this.isMe,
  }) : assert(
  // This makes sure we have the right data
  (type == MessageType.text && text != null) ||
      (type == MessageType.image && filePath != null),
  'Text messages must have text, Image messages must have a filePath',
  );

  // Factory constructor for easy creation of text messages
  factory ChatMessage.text({
    required String text,
    required DateTime timestamp,
    required bool isMe,
  }) {
    return ChatMessage(
      type: MessageType.text,
      text: text,
      timestamp: timestamp,
      isMe: isMe,
    );
  }

  // Factory constructor for easy creation of image messages
  factory ChatMessage.image({
    required String filePath,
    required DateTime timestamp,
    required bool isMe,
  }) {
    return ChatMessage(
      type: MessageType.image,
      filePath: filePath,
      timestamp: timestamp,
      isMe: isMe,
    );
  }
}