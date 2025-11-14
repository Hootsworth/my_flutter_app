import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentUserId;
  final String initialDisplayName;
  final String initialLiHandle;
  final String initialBio;
  final bool isPrivate;

  const EditProfileScreen({
    super.key,
    required this.currentUserId,
    required this.initialDisplayName,
    required this.initialLiHandle,
    required this.initialBio,
    required this.isPrivate,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _liHandleController;
  late final TextEditingController _bioController;
  late bool _isPrivate;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.initialDisplayName);
    _liHandleController = TextEditingController(text: widget.initialLiHandle);
    _bioController = TextEditingController(text: widget.initialBio);
    _isPrivate = widget.isPrivate;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _liHandleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Add liHandle uniqueness check if needed
      // This is a simplified update
      final newLiHandle = _liHandleController.text;
      final newDisplayName = _displayNameController.text;
      final newBio = _bioController.text;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .update({
        'displayName': newDisplayName,
        'liHandle': newLiHandle,
        'bio': newBio,
        'isPrivate': _isPrivate,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          // Save Button
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Display Name ---
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display name cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // --- liHandle ---
            TextFormField(
              controller: _liHandleController,
              decoration: const InputDecoration(
                labelText: 'Handle (@liHandle)',
                prefixText: '@',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Handle cannot be empty';
                }
                if (value.contains(' ')) {
                  return 'Handle cannot contain spaces';
                }
                // Basic format check
                final RegExp liHandleRegex = RegExp(r'^[a-zA-Z0-9_]+$');
                if (!liHandleRegex.hasMatch(value.trim())) {
                  return 'Use only letters, numbers, and underscores';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // --- Bio ---
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 150,
            ),
            const SizedBox(height: 16),
            // --- Private Account Toggle ---
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              title: const Text('Private Account'),
              subtitle: Text(
                'If enabled, your whispers will be protected.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              secondary: Icon(
                _isPrivate ? Icons.lock : Icons.lock_open,
              ),
              value: _isPrivate,
              onChanged: (bool value) {
                setState(() {
                  _isPrivate = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}