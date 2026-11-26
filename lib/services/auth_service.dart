import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_notification_service.dart';
import 'chat_notification_listener.dart';
import 'push_notification_service.dart';
import 'doctor_cache_service.dart';

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

  /// User-friendly error message generator — never exposes raw Firebase internal exceptions.
  static String getFriendlyAuthErrorMessage(dynamic error, bool isArabic) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
          return isArabic ? 'كلمة المرور غير صحيحة.' : 'Incorrect password.';
        case 'user-not-found':
          return isArabic ? 'الحساب غير مسجل أو البريد غير صحيح.' : 'Account not found. Please check your email.';
        case 'invalid-email':
          return isArabic ? 'صيغة البريد الإلكتروني غير صالحة.' : 'Invalid email address format.';
        case 'invalid-credential':
          return isArabic ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.' : 'Incorrect email or password.';
        case 'email-already-in-use':
          return isArabic ? 'هذا البريد الإلكتروني مستخدم بالفعل بحساب آخر.' : 'The email is already in use by another account.';
        case 'weak-password':
          return isArabic ? 'كلمة المرور ضعيفة جداً، يرجى كتابة 6 أحرف على الأقل.' : 'The password is too weak. Please use at least 6 characters.';
        case 'user-disabled':
          return isArabic ? 'تم تعطيل هذا الحساب. يرجى التواصل مع الدعم.' : 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return isArabic
              ? 'تم حظر المحاولات مؤقتاً بسبب محاولات متكررة خاطئة. يرجى المحاولة بعد قليل.'
              : 'Too many failed attempts. Please try again in a few minutes.';
        case 'network-request-failed':
          return isArabic
              ? 'تعذر الاتصال بالسيرفر. يرجى التحقق من اتصالك بالإنترنت.'
              : 'Network error. Please check your internet connection.';
        case 'operation-not-allowed':
          return isArabic ? 'هذه العملية غير مفعلة حالياً.' : 'This operation is not allowed.';
        default:
          return isArabic ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.' : 'Incorrect email or password.';
      }
    }

    final errStr = error.toString().toLowerCase();
    if (errStr.contains('invalid-credential') ||
        errStr.contains('wrong-password') ||
        errStr.contains('user-not-found') ||
        errStr.contains('invalid credential') ||
        errStr.contains('malformed or has expired')) {
      return isArabic ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.' : 'Incorrect email or password.';
    }
    if (errStr.contains('email-already-in-use')) {
      return isArabic ? 'هذا البريد الإلكتروني مستخدم بالفعل.' : 'The email is already in use by another account.';
    }
    if (errStr.contains('network') || errStr.contains('socket') || errStr.contains('offline')) {
      return isArabic
          ? 'تعذر الاتصال بالسيرفر. يرجى التحقق من اتصالك بالإنترنت.'
          : 'Network error. Please check your internet connection.';
    }
    if (errStr.contains('too-many-requests')) {
      return isArabic
          ? 'تم حظر المحاولات مؤقتاً بسبب محاولات متكررة خاطئة. يرجى المحاولة بعد قليل.'
          : 'Too many failed attempts. Please try again later.';
    }

    return isArabic ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.' : 'Incorrect email or password.';
  }

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

    final data = <String, dynamic>{
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }

    await _firestore.collection('users').doc(userId).set(data, SetOptions(merge: true));
  }

  /// Delete user profile image from Firebase Storage and remove URL from Firestore
  Future<void> removeProfilePhoto({String? uid}) async {
    final userId = uid ?? _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // 1. Delete image file from Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('users/$userId/profile_pic.jpg');
      try {
        await storageRef.delete();
        debugPrint('🗑️ Firebase Storage profile_pic.jpg deleted for $userId');
      } catch (e) {
        debugPrint('⚠️ Storage photo delete warning (file may not exist): $e');
      }

      // 2. Remove photoUrl field in Firestore
      await _firestore.collection('users').doc(userId).update({
        'photoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Clear Flutter PaintingBinding image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // 4. Remove local shared preferences cached image path
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image');

      debugPrint('✅ Profile photo successfully removed for user: $userId');
    } catch (e) {
      debugPrint('❌ Error removing profile photo: $e');
      rethrow;
    }
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
    ChatNotificationListener().stopListening();
    DoctorCacheService().invalidate();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await PushNotificationService().clearFCMToken();
    await _auth.signOut();
  }

  // Auth State Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}

