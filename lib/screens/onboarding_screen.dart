// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:littlebird/screens/handle_setup_screen.dart'; // Your working file
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingScreen extends StatefulWidget {
  final User user;
  const OnboardingScreen({super.key, required this.user});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  double _scrollProgress = 0.0;

  // Store the page icons for the timeline
  final List<IconData> _pageIcons = const [
    Icons.egg_outlined, // "Hatching"
    Icons.visibility_off_outlined, // "Privacy"
    Icons.people_outline, // "Flock"
  ];

  @override
  void initState() {
    super.initState();
    // Listen to the scroll position to animate the timeline
    _pageController.addListener(() {
      setState(() {
        _scrollProgress = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // When done, we navigate to your HandleSetupScreen
  void _onDone() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HandleSetupScreen(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Inverted theme as requested
      backgroundColor: Colors.grey[900], // Was Colors.white
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildOnboardingPage(
                icon: _pageIcons[0],
                title: 'Welcome to Littlebird',
                subtitle: 'Your private campus nest. Ready to take flight?',
              ),
              _buildOnboardingPage(
                icon: _pageIcons[1],
                title: 'Whispers that Fade',
                subtitle:
                'Connect with students on your campus. Share moments that don\'t last forever.',
              ),
              _buildOnboardingPage(
                icon: _pageIcons[2],
                title: 'Find Your Flock',
                subtitle:
                'This is a private community, just for students. Be kind, be respectful, and build your nest.',
              ),
            ],
          ),
          // Bottom Navigation (Timeline and Button)
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  /// Helper widget for the onboarding pages.
  Widget _buildOnboardingPage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.white), // Changed color
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Changed color
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 18, color: Colors.white70), // Changed color
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Helper widget for the bottom navigation controls (timeline + button)
  Widget _buildBottomControls() {
    bool isLastPage = _currentPage == 2; // 3 pages total (0, 1, 2)

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // NEW: Animated Timeline
        _buildAnimatedTimeline(),

        // Next / Done button
        TextButton(
          onPressed: () {
            if (isLastPage) {
              _onDone(); // Navigate to your HandleSetupScreen
            } else {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Text(
            isLastPage ? 'Take Flight' : 'Next',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white, // Changed color
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// NEW: Widget to build the animated timeline
  Widget _buildAnimatedTimeline() {
    const double totalPages = 3;
    const double timelineWidth = 100.0; // Fixed width for the timeline
    // Calculate the width of the progress bar based on scroll position
    final double progressWidth = (_scrollProgress / (totalPages - 1)) * timelineWidth;

    return SizedBox(
      width: timelineWidth,
      height: 30, // Height to fit the icons
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // 1. The "track" (the full line)
          Container(
            height: 4,
            width: timelineWidth,
            decoration: BoxDecoration(
              color: Colors.white38, // Dim "inactive" color
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 2. The animated "progress" (the growing line)
          AnimatedContainer(
            duration: const Duration(milliseconds: 100), // Fast update
            height: 4,
            width: progressWidth,
            decoration: BoxDecoration(
              color: Colors.white, // Bright "active" color
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 3. The nodes (icons)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              // Check if this node is the one currently being viewed
              bool isCurrent = _currentPage == index;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Highlight the current node with a white background
                  color: isCurrent ? Colors.white : Colors.transparent,
                ),
                child: Icon(
                  _pageIcons[index],
                  size: 20,
                  // Icon color logic:
                  // - If current: Dark (to show on white circle)
                  // - If passed: White (active)
                  // - If future: Dim (inactive)
                  color: isCurrent
                      ? Colors.grey[900]
                      : (_scrollProgress >= index ? Colors.white : Colors.white38),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}