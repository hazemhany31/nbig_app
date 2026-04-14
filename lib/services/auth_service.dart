import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_notification_service.dart';

// === Riverpod Providers ===
// مزود خدمة المصادقة للوصول السريع
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// مزود حالة المستحدم الحالية (مسجل دخول أم لا) للاستماع لها في الشاشات
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// مزود بيانات المستخدم من Firestore
final userDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;
  
  return await ref.read(authServiceProvider).getUserData();
});

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
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('AuthService: Sign-in successful for $email');
      return credential;
    } catch (e) {
      debugPrint('AuthService: Sign-in failed for $email: $e');
      rethrow;
    }
  }

  // Save/Update User Data in Firestore
  Future<void> saveUserData({
    String? uid,
    required String email,
    required String name,
    required String phoneNumber,
    String? photoUrl,
    String role = 'patient',
  }) async {
    final userId = uid ?? _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
      // Only set createdAt if it doesn't exist
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get User Data — try cache first for instant load, fallback to network
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final ref = _firestore.collection('users').doc(user.uid);

    // 1) Try cache instantly
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists && cached.data() != null) return cached.data();
    } catch (_) {}

    // 2) Fallback to network with 5s timeout
    try {
      final doc = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      debugPrint('AuthService: User data fetched from server');
      return doc.data();
    } catch (e) {
      debugPrint('AuthService: Error fetching user data from server: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    AppNotificationService().stopListening();
    await _auth.signOut();
  }

  // Auth State Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
