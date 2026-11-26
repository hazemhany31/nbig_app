import 'package:flutter/material.dart';
import '../services/biometric_service.dart';

/// سطر في الإعدادات لتفعيل/إيقاف الدخول بـ Face ID.
/// بيختفي لو الجهاز مش بيدعم البصمة. التفعيل والإيقاف بيطلبوا تحقق فعلي.
class BiometricToggleTile extends StatefulWidget {
  final String uid;
  final bool isArabic;
  const BiometricToggleTile({super.key, required this.uid, required this.isArabic});

  @override
  State<BiometricToggleTile> createState() => _BiometricToggleTileState();
}

class _BiometricToggleTileState extends State<BiometricToggleTile> {
  bool _loaded = false;
  bool _supported = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = BiometricService();
    final supported = await s.isDeviceSupported();
    final enabled = await s.isEnabledForUser(widget.uid);
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _enabled = enabled;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool value) async {
    final s = BiometricService();
    final ar = widget.isArabic;
    final ok = await s.authenticate(
      reason: value
          ? (ar ? 'أكّد Face ID لتفعيله' : 'Confirm Face ID to enable it')
          : (ar ? 'أكّد هويتك لإيقاف Face ID' : 'Confirm your identity to turn off Face ID'),
    );
    if (!ok) return;
    if (value) {
      await s.enableForUser(widget.uid);
    } else {
      await s.disableForUser(widget.uid);
    }
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_supported) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.face_rounded, color: Color(0xFF0B6E6E)),
      title: Text(widget.isArabic ? 'الدخول بـ Face ID' : 'Sign in with Face ID'),
      trailing: Switch(
        key: const Key('biometric_toggle_switch'),
        value: _enabled,
        onChanged: _toggle,
      ),
    );
  }
}
