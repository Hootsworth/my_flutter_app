import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:littlebird/screens/login_page.dart';
// --- CHANGED ---
// We now import the onboarding screen instead of the handle setup screen.
import 'package:littlebird/screens/onboarding_screen.dart';
// --- END CHANGE ---

/// A widget that listens to the auth state and shows the correct page.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // --- CHANGED ---
          // User is logged in, show them the onboarding flow first.
          // The onboarding screen will then navigate to the HandleSetupScreen.
          return OnboardingScreen(user: snapshot.data!);
          // --- END CHANGE ---
        } else {
          // User is logged out
          return const LoginPage();
        }
      },
    );
  }
}