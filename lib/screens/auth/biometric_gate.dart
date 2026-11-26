import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';

/// بوابة Face ID.
/// - لو Face ID مفعّل: التطبيق مقفول لحد ما المستخدم يتحقق بالوجه/البصمة.
/// - لو مش مفعّل ولسه ما اتعرضش عليه: بنعرض عليه التفعيل مرة واحدة بعد تسجيل الدخول.
class BiometricGate extends StatefulWidget {
  final String uid;
  final Widget child;
  const BiometricGate({super.key, required this.uid, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  bool _checking = true;
  bool _unlocked = false;
  bool _authenticating = false;
  bool _isAr = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<bool> _loadIsArabic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getString('language_code') ?? 'ar') == 'ar';
    } catch (_) {
      return true;
    }
  }

  Future<void> _init() async {
    final service = BiometricService();
    _isAr = await _loadIsArabic();
    final enabled = await service.isEnabledForUser(widget.uid);
    if (!mounted) return;
    if (enabled) {
      setState(() => _checking = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
      return;
    }
    setState(() {
      _checking = false;
      _unlocked = true;
    });
    // أول مرة بعد تسجيل الدخول: اعرض تفعيل Face ID
    if (!await service.wasOffered(widget.uid) &&
        await service.isDeviceSupported()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offer());
    }
  }

  Future<void> _offer() async {
    if (!mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(_isAr ? 'تفعيل Face ID؟' : 'Enable Face ID?'),
        content: Text(_isAr
            ? 'تفتح التطبيق بوجهك في كل مرة بدل ما تسجل دخول من جديد.'
            : 'Open the app with your face every time instead of signing in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_isAr ? 'مش دلوقتي' : 'Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isAr ? 'تفعيل' : 'Enable'),
          ),
        ],
      ),
    );
    final service = BiometricService();
    await service.markOffered(widget.uid);
    if (accept == true) {
      // لازم يتحقق فعلاً مرة قبل ما نحفظ التفعيل
      final ok = await service.authenticate(
        reason: _isAr ? 'أكّد Face ID لتفعيله' : 'Confirm Face ID to enable it',
      );
      if (ok) await service.enableForUser(widget.uid);
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    final ok = await BiometricService().authenticate(
      reason: _isAr ? 'افتح iHEALTY+ بالـ Face ID' : 'Unlock iHEALTY+ with Face ID',
    );
    _authenticating = false;
    if (!mounted) return;
    if (ok) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    const primary = Color(0xFF0B6E6E);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('iHEALTY+',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                const Icon(Icons.lock_outline_rounded, size: 72, color: primary),
                const SizedBox(height: 16),
                Text(_isAr ? 'التطبيق مقفول' : 'App is locked',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                    _isAr
                        ? 'استخدم الـ Face ID للدخول'
                        : 'Use Face ID to sign in',
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.face_rounded),
                  label: Text(_isAr ? 'حاول تاني' : 'Try again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => AuthService().signOut(),
                  child: Text(_isAr
                      ? 'تسجيل الخروج والدخول بكلمة المرور'
                      : 'Sign out and use password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
