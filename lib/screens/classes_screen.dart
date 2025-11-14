import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'class_details_screen.dart'; // Import the new details screen

// A model for our class data
class ClassMembership {
  final String classId;
  final String className;
  final String role;

  ClassMembership(
      {required this.classId, required this.className, required this.role});

  factory ClassMembership.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassMembership(
      classId: doc.id,
      className: data['className'] ?? 'Unknown Class',
      role: data['role'] ?? 'member',
    );
  }
}

class ClassesScreen extends StatefulWidget {
  final String currentUserLiHandle;
  const ClassesScreen({super.key, required this.currentUserLiHandle});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  Stream<List<ClassMembership>> _getUserClasses() {
    return _firestore
        .collection('users')
        .doc(_currentUser.uid)
        .collection('classMemberships')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => ClassMembership.fromDoc(doc)).toList());
  }

  // Generates a random 6-digit class code
  String _generateClassCode() {
    var rng = Random();
    // FIX: Perform the math operations *first*, then convert the result to a String.
    // (rng.nextInt(900000) + 100000) is an int, .toString() converts it.
    return (rng.nextInt(900000) + 100000).toString();
  }

  Future<void> _createClass() async {
    final classNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Class'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: classNameController,
              decoration: const InputDecoration(labelText: 'Class Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a class name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Create'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final className = classNameController.text.trim();
                  Navigator.of(context).pop(); // Close dialog

                  try {
                    // TODO: Add logic to ensure class code is unique
                    final classCode = _generateClassCode();

                    // Create class document
                    DocumentReference classRef =
                    await _firestore.collection('classes').add({
                      'className': className,
                      'classCode': classCode,
                      'creatorId': _currentUser.uid,
                      'creatorHandle': widget.currentUserLiHandle,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    // Batch write: Add user as admin and add to their membership list
                    WriteBatch batch = _firestore.batch();

                    // 1. Add admin to class members subcollection
                    batch.set(
                        classRef.collection('members').doc(_currentUser.uid), {
                      'liHandle': widget.currentUserLiHandle,
                      'role': 'admin',
                      'joinedAt': FieldValue.serverTimestamp(),
                    });

                    // 2. Add class to user's classMemberships subcollection
                    batch.set(
                        _firestore
                            .collection('users')
                            .doc(_currentUser.uid)
                            .collection('classMemberships')
                            .doc(classRef.id),
                        {
                          'className': className,
                          'role': 'admin',
                          'joinedAt': FieldValue.serverTimestamp(),
                        });

                    await batch.commit();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                          Text('Class "$className" created! Code: $classCode')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating class: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _joinClass() async {
    final classCodeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join a Class'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: classCodeController,
              decoration: const InputDecoration(labelText: 'Class Code'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return 'Please enter a 6-digit class code';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Join'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final classCode = classCodeController.text.trim();
                  Navigator.of(context).pop(); // Close dialog

                  try {
                    // Find class by code
                    final query = await _firestore
                        .collection('classes')
                        .where('classCode', isEqualTo: classCode)
                        .limit(1)
                        .get();

                    if (query.docs.isEmpty) {
                      throw Exception('Class not found. Check the code.');
                    }

                    final classDoc = query.docs.first;
                    final className = classDoc.data()['className'];

                    // Batch write
                    WriteBatch batch = _firestore.batch();

                    // 1. Add user as member
                    batch.set(
                        classDoc.reference
                            .collection('members')
                            .doc(_currentUser.uid),
                        {
                          'liHandle': widget.currentUserLiHandle,
                          'role': 'member',
                          'joinedAt': FieldValue.serverTimestamp(),
                        });

                    // 2. Add class to user's membership list
                    batch.set(
                        _firestore
                            .collection('users')
                            .doc(_currentUser.uid)
                            .collection('classMemberships')
                            .doc(classDoc.id),
                        {
                          'className': className,
                          'role': 'member',
                          'joinedAt': FieldValue.serverTimestamp(),
                        });

                    await batch.commit();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Successfully joined "$className"')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error joining class: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Class',
            onPressed: _createClass,
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Join Class',
            onPressed: _joinClass,
          ),
        ],
      ),
      body: StreamBuilder<List<ClassMembership>>(
        stream: _getUserClasses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No classes yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create a new class to get started or join an existing one using a class code.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final classes = snapshot.data!;

          return ListView.builder(
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final classData = classes[index];
              // --- UI & LOGIC UPDATE ---
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: Text(classData.className),
                  subtitle: Text('Role: ${classData.role}'),
                  trailing: classData.role == 'admin'
                      ? const Icon(Icons.shield)
                      : null,
                  onTap: () {
                    // Navigate to the details screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ClassDetailsScreen(
                          classId: classData.classId,
                          className: classData.className,
                          userRole: classData.role,
                          currentUserLiHandle: widget.currentUserLiHandle,
                        ),
                      ),
                    );
                  },
                ),
              );
              // --- END UPDATE ---
            },
          );
        },
      ),
    );
  }
}