import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up with Email and Password
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    String role = 'patient',
  }) async {
    // Create User in Firebase Auth
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Save additional data in Firestore
    if (credential.user != null) {
      await saveUserData(
        uid: credential.user!.uid,
        email: email,
        name: name,
        phoneNumber: phone,
        role: role,
      );
      // Update Display Name
      await credential.user!.updateDisplayName(name);
    }

    return credential;
  }

  // Sign In with Email and Password
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Save/Update User Data in Firestore
  Future<void> saveUserData({
    String? uid,
    required String email,
    required String name,
    required String phoneNumber,
    String role = 'patient',
  }) async {
    final userId = uid ?? _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
      // Only set createdAt if it doesn't exist
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get User Data
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Auth State Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
