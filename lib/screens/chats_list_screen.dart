import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:littlebird/models/chat_message.dart'; // Make sure this path is correct
import 'package:littlebird/services/nearby_service.dart'; // Make sure this path is correct

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  StreamSubscription? _messageSubscription;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final nearbyService = context.read<NearbyService>();
    // Start services when the screen is first initialized
    nearbyService.initializeService();
    // Listen for incoming messages
    _messageSubscription = nearbyService.messageStream.listen(_onMessageReceived);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  void _onMessageReceived(ChatMessage message) {
    if (mounted) {
      setState(() {
        _messages.insert(0, message);
      });
    }
  }

  void _sendTextMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final nearbyService = context.read<NearbyService>();
    nearbyService.sendTextMessage(text);

    final message = ChatMessage.text(
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
    );

    setState(() {
      _messages.insert(0, message);
    });
    _chatController.clear();
  }

  Future<void> _sendImageMessage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress image to send faster
      );

      if (image == null) {
        // User cancelled the picker
        return;
      }

      final File imageFile = File(image.path);
      final nearbyService = context.read<NearbyService>();

      // Send the file
      nearbyService.sendImageFile(imageFile);

      // Add to local UI immediately
      final message = ChatMessage.image(
        filePath: imageFile.path,
        timestamp: DateTime.now(),
        isMe: true,
      );

      setState(() {
        _messages.insert(0, message);
      });
    } catch (e) {
      print("Error picking/sending image: $e");
      // You might want to show a SnackBar here
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearbyService = context.watch<NearbyService>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          nearbyService.isConnected
              ? nearbyService.connectedUserName ?? 'Chat'
              : 'Nearby Chats',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (nearbyService.isConnected)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Disconnect',
              onPressed: () => nearbyService.disconnect(),
            ),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: nearbyService.isConnected
          ? _buildChatView()
          : _buildDiscoveryView(nearbyService),
    );
  }

  // --- WIDGET BUILDERS ---

  /// Shows the list of discovered users
  Widget _buildDiscoveryView(NearbyService nearbyService) {
    if (nearbyService.discoveredUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_tethering,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Searching for users...',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure you\'re on the same Wi-Fi network.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: nearbyService.discoveredUsers.map((user) {
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              user.userName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'Tap to connect',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => nearbyService.connect(user),
          ),
        );
      }).toList(),
    );
  }

  /// Shows the chat UI (messages and input field)
  Widget _buildChatView() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // This is where the 10-minute auto-delete logic happens!
    final visibleMessages = _messages
        .where((m) =>
    DateTime.now().difference(m.timestamp) < const Duration(minutes: 10))
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: Chip(
            avatar: Icon(Icons.timer_outlined,
                size: 18, color: colorScheme.onSecondaryContainer),
            label: Text(
              'Messages disappear after 10 minutes',
              style: textTheme.labelLarge
                  ?.copyWith(color: colorScheme.onSecondaryContainer),
            ),
            backgroundColor: colorScheme.secondaryContainer,
            side: BorderSide.none,
          ),
        ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: visibleMessages.length,
            itemBuilder: (context, index) {
              final message = visibleMessages[index];

              // Choose which bubble to build based on message type
              if (message.type == MessageType.text) {
                return _buildTextBubble(message, colorScheme, textTheme);
              } else if (message.type == MessageType.image) {
                return _buildImageBubble(message, colorScheme);
              }
              return const SizedBox.shrink(); // Should not happen
            },
          ),
        ),
        // --- Text Input Field ---
        _buildChatInput(),
      ],
    );
  }

  /// Builds a chat bubble for a text message
  Widget _buildTextBubble(
      ChatMessage message, ColorScheme colorScheme, TextTheme textTheme) {
    const largeRadius = Radius.circular(24);
    const smallRadius = Radius.circular(8);

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        elevation: 0,
        color: message.isMe
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: largeRadius,
            topRight: largeRadius,
            bottomLeft: message.isMe ? largeRadius : smallRadius,
            bottomRight: message.isMe ? smallRadius : largeRadius,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: Text(
            message.text!, // We know text is not null here
            style: textTheme.bodyLarge?.copyWith(
              color: message.isMe
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a chat bubble for an image message
  Widget _buildImageBubble(ChatMessage message, ColorScheme colorScheme) {
    const largeRadius = Radius.circular(24);
    const smallRadius = Radius.circular(8);
    final imageFile = File(message.filePath!);

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        elevation: 0,
        color: message.isMe
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: largeRadius,
            topRight: largeRadius,
            bottomLeft: message.isMe ? largeRadius : smallRadius,
            bottomRight: message.isMe ? smallRadius : largeRadius,
          ),
        ),
        clipBehavior: Clip.antiAlias, // Clips the image to the card's shape
        child: Padding(
          padding: const EdgeInsets.all(4), // Small padding around the image
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7, // Max 70% width
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20), // Inner radius for the image
              child: Image.file(
                imageFile,
                fit: BoxFit.cover,
                // Show a placeholder while the image loads


              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The text input field at the bottom
  Widget _buildChatInput() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
      ),
      child: Row(
        children: [
          // Button to attach an image
          IconButton(
            icon: Icon(
              Icons.attach_file,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: _sendImageMessage,
            tooltip: 'Send Image',
          ),
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: 'Send a message...',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          FilledButton(
            onPressed: _sendTextMessage,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}