import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:littlebird/screens/main_app_shell.dart';

/// This screen checks if a user has set their "LiHandle" and profile.
/// If not, it prompts them to create them in a two-step process.
/// 1. Set Handle
/// 2. Set Profile (Display Name, Bio)
/// If they have, it navigates them to the MainAppShell.
class HandleSetupScreen extends StatefulWidget {
  final User user;
  const HandleSetupScreen({super.key, required this.user});

  @override
  State<HandleSetupScreen> createState() => _HandleSetupScreenState();
}

class _HandleSetupScreenState extends State<HandleSetupScreen> {
  // --- Handle Setup ---
  final _handleFormKey = GlobalKey<FormState>();
  final _handleController = TextEditingController();
  bool _isHandleLoading = false;
  String? _handleErrorMessage;

  // --- Profile Setup ---
  final _profileFormKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isProfileLoading = false;
  String? _profileErrorMessage;

  @override
  void dispose() {
    _handleController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Saves the unique handle to Firestore.
  Future<void> _saveHandle() async {
    if (!_handleFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isHandleLoading = true;
      _handleErrorMessage = null;
    });

    try {
      String handle = _handleController.text.trim().toLowerCase();
      String fullHandle = '@$handle';

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('liHandle', isEqualTo: fullHandle)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _handleErrorMessage = 'This handle is already taken. Please try another.';
            _isHandleLoading = false;
          });
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'liHandle': fullHandle});

      // Navigation is handled by the StreamBuilder
    } catch (e) {
      if (mounted) {
        setState(() {
          _handleErrorMessage = 'An error occurred. Please try again.';
          _isHandleLoading = false;
        });
      }
    }
  }

  /// --- UPDATED: Saves the profile info to Firestore (No PFP) ---
  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProfileLoading = true;
      _profileErrorMessage = null;
    });

    try {
      // 1. Get the data
      final displayName = _displayNameController.text.trim();
      final bio = _bioController.text.trim();

      // 2. Save all data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'displayName': displayName,
        'bio': bio,
        'profilePictureUrl': null, // Explicitly set to null or remove
      });

      // Navigation will be handled by the StreamBuilder
    } catch (e) {
      if (mounted) {
        setState(() {
          _profileErrorMessage = 'An error occurred. Please try again.';
          _isProfileLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Error: User document not found.')),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;

        final hasHandle = userData != null &&
            userData.containsKey('liHandle') &&
            userData['liHandle'] != null;
        final hasProfile = userData != null &&
            userData.containsKey('displayName') &&
            userData['displayName'] != null;

        // 1. User is fully set up -> Go to App
        if (hasHandle && hasProfile) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainAppShell()),
                    (route) => false,
              );
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. User has handle, but no profile -> Show Profile Setup
        if (hasHandle && !hasProfile) {
          return _buildProfileSetupForm(context);
        }

        // 3. User has no handle -> Show Handle Setup
        return _buildHandleSetupForm(context);
      },
    );
  }

  /// --- UPDATED: Aesthetic Handle Setup Form ---
  Widget _buildHandleSetupForm(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(32.0),
              children: [
                Form(
                  key: _handleFormKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Choose your LiHandle',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This will be your unique username. Only letters, numbers, and underscores.',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      TextFormField(
                        controller: _handleController,
                        decoration: const InputDecoration(
                          labelText: 'Handle',
                          hintText: 'your_unique_handle',
                          prefixText: '@',
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a handle';
                          }
                          if (value.trim().length < 3) {
                            return 'Must be at least 3 characters long.';
                          }
                          final handleRegex =
                          RegExp(r'^[a-zA-Z0-9_]+$');
                          if (!handleRegex.hasMatch(value.trim())) {
                            return 'Only letters, numbers, and underscores allowed.';
                          }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 24),
                      if (_handleErrorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _handleErrorMessage!,
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (_isHandleLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton(
                          onPressed: _saveHandle,
                          style: ElevatedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save and Continue',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// --- UPDATED: Aesthetic Profile Setup Form (No PFP) ---
  Widget _buildProfileSetupForm(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(32.0),
              children: [
                Form(
                  key: _profileFormKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Set up your Profile',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This info will be visible on your public profile.',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      // --- Display Name ---
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'Your Name',
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a display name';
                          }
                          if (value.trim().length > 50) {
                            return 'Name is too long (max 50 chars).';
                          }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 20),
                      // --- Bio ---
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          hintText: 'Tell everyone about yourself (optional)',
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                        ),
                        maxLines: 3,
                        maxLength: 160,
                        validator: (value) {
                          if (value != null && value.trim().length > 160) {
                            return 'Bio is too long (max 160 chars).';
                          }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 24),
                      if (_profileErrorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _profileErrorMessage!,
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (_isProfileLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Profile',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}