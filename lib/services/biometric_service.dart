import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة الدخول بالبصمة / Face ID
///
/// المستخدم يسجّل دخوله أول مرة بالبريد وكلمة المرور، ثم يفعّل Face ID
/// مرة واحدة بعد تسجيل الدخول. بعدها يفتح التطبيق بالـ Face ID تلقائياً
/// في كل مرة يفتح فيها التطبيق (حتى بعد إغلاقه تماماً).
/// واجهة بسيطة فوق local_auth عشان نقدر نختبر السلوك بدون جهاز حقيقي.
abstract class BiometricBackend {
  Future<bool> canCheckBiometrics();
  Future<bool> isDeviceSupported();
  Future<bool> authenticate(String reason);
}

class LocalAuthBackend implements BiometricBackend {
  final LocalAuthentication _auth = LocalAuthentication();
  @override
  Future<bool> canCheckBiometrics() => _auth.canCheckBiometrics;
  @override
  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();
  @override
  Future<bool> authenticate(String reason) => _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
}

class BiometricService {
  static BiometricService _instance = BiometricService._internal(LocalAuthBackend());
  factory BiometricService() => _instance;
  BiometricService._internal(this._backend);

  /// للاختبارات فقط.
  @visibleForTesting
  static void overrideForTest(BiometricBackend backend) {
    _instance = BiometricService._internal(backend);
  }

  final BiometricBackend _backend;

  static const String _kEnabledPrefix = 'biometric_enabled_';

  String _keyFor(String uid) => '$_kEnabledPrefix$uid';

  /// هل الجهاز يدعم البصمة / Face ID أصلاً؟
  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _backend.canCheckBiometrics();
      final supported = await _backend.isDeviceSupported();
      return canCheck || supported;
    } catch (e) {
      debugPrint('⚠️ BiometricService.isDeviceSupported error: $e');
      return false;
    }
  }

  /// تنفيذ التحقق بالبصمة / Face ID مرة واحدة.
  /// يرجع true لو المستخدم اجتاز التحقق.
  Future<bool> authenticate({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await _backend.authenticate(reason);
    } catch (e) {
      debugPrint('⚠️ BiometricService.authenticate error: $e');
      return false;
    }
  }

  /// تفعيل الدخول بالبصمة لهذا المستخدم (تُحفظ محلياً وتستمر بعد إغلاق التطبيق).
  Future<void> enableForUser(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFor(uid), true);
      debugPrint('✅ Biometric login enabled for UID: $uid');
    } catch (e) {
      debugPrint('⚠️ BiometricService.enableForUser error: $e');
    }
  }

  /// إيقاف الدخول بالبصمة لهذا المستخدم.
  Future<void> disableForUser(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFor(uid), false);
      debugPrint('✅ Biometric login disabled for UID: $uid');
    } catch (e) {
      debugPrint('⚠️ BiometricService.disableForUser error: $e');
    }
  }

  static const String _kAskedPrefix = 'biometric_asked_';

  /// هل عرضنا على المستخدم تفعيل Face ID قبل كده؟
  Future<bool> wasOffered(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kAskedPrefix$uid') ?? false;
  }

  Future<void> markOffered(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kAskedPrefix$uid', true);
  }

  /// هل الدخول بالبصمة مفعّل لهذا المستخدم؟
  Future<bool> isEnabledForUser(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyFor(uid)) ?? false;
    } catch (e) {
      debugPrint('⚠️ BiometricService.isEnabledForUser error: $e');
      return false;
    }
  }
}
