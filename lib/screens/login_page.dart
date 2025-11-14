import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// The Login Page (shown if the user is logged out)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoadingGoogle = false;
  bool _isLoadingAnon = false;

  /// Creates or updates the user document in Firestore after sign-in.
  /// This ensures every user (Google or Anon) has a profile document.
  Future<void> _createOrUpdateUserDocument(User? user) async {
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      // Create the document if it doesn't exist
      final Map<String, dynamic> userData = {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      // Add displayName if available (from Google Sign-In)
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        userData['displayName'] = user.displayName;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        userData['email'] = user.email;
      }

      await userRef.set(userData, SetOptions(merge: true));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoadingGoogle = true;
    });

    try {
      // 1. Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        setState(() {
          _isLoadingGoogle = false;
        });
        return;
      }

      // 2. Obtain authentication details from the request
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // 3. Create a new Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      // 5. Create user document in Firestore
      await _createOrUpdateUserDocument(userCredential.user);
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoadingAnon = true;
    });

    try {
      // 1. Sign in anonymously
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInAnonymously();

      // 2. Create user document in Firestore
      await _createOrUpdateUserDocument(userCredential.user);
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in anonymously: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnon = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mode_comment_outlined,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome to Littlebird',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Whispers that fade.',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              if (_isLoadingGoogle)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  icon: SvgPicture.network(
                    'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg', // Online Google SVG
                    height: 24.0,
                    // As a fallback, we use a text 'G'
                    placeholderBuilder: (context) =>
                    const Text('G', style: TextStyle(fontSize: 20)),
                  ),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _signInWithGoogle,
                ),
              const SizedBox(height: 16),
              if (_isLoadingAnon)
                const CircularProgressIndicator()
              else
                TextButton(
                  child: const Text('Sign in Anonymously'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                  onPressed: _signInAnonymously,
                ),
            ],
          ),
        ),
      ),
    );
  }
}