import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:littlebird/services/nearby_service.dart';
import 'feed_screen.dart';
import 'chats_screen.dart';
import 'classes_screen.dart'; // Import the new screen
import 'account_screen.dart';

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0;
  String? _liHandle;
  bool _isLoadingHandle = true;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUserHandle();
  }

  Future<void> _fetchUserHandle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingHandle = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _liHandle = doc.data()?['liHandle'] as String?;
          _isLoadingHandle = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHandle = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load user profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHandle) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_liHandle == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error: Could not load your LiHandle.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign Out'),
              )
            ],
          ),
        ),
      );
    }

    final userName = _liHandle!;

    final List<Widget> screens = <Widget>[
      FeedScreen(currentUserLiHandle: userName),
      ChatsScreen(),
      ClassesScreen(currentUserLiHandle: userName), // New screen
      const AccountScreen(),
    ];

    return ChangeNotifierProvider(
      create: (_) => NearbyService(userName),
      child: Scaffold(
        body: Center(
          child: screens.elementAt(_selectedIndex),
        ),

        // --- AESTHETIC CHANGE: Remove tap animation ---
        bottomNavigationBar: Theme(
          // 1. Override the theme just for this widget
          data: Theme.of(context).copyWith(
            // 2. Set the splash/ripple effect to nothing
            splashFactory: NoSplash.splashFactory,
            // 3. Set the highlight color (when pressed) to transparent
            highlightColor: Colors.transparent,
          ),
          // 4. This is your NavigationBar
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,

            // Hide all labels for a clean, icon-only look
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,

            destinations: const <NavigationDestination>[
              // --- Feed Tab ---
              NavigationDestination(
                selectedIcon: Icon(Icons.auto_awesome),
                icon: Icon(Icons.auto_awesome_outlined),
                label: 'Feed',
              ),
              // --- Chats Tab ---
              NavigationDestination(
                selectedIcon: Icon(Icons.chat_bubble),
                icon: Icon(Icons.chat_bubble_outline),
                label: 'Chats',
              ),
              // --- NEW: Classes Tab ---
              NavigationDestination(
                selectedIcon: Icon(Icons.school),
                icon: Icon(Icons.school_outlined),
                label: 'Classes',
              ),
              // --- Account Tab ---
              NavigationDestination(
                selectedIcon: Icon(Icons.person),
                icon: Icon(Icons.person_outline),
                label: 'Account',
              ),
            ],
          ),
        ),
        // --- END CHANGE ---
      ),
    );
  }
}