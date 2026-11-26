import 'package:flutter/widgets.dart';
import 'notification_dedupe.dart';

/// يقرر مين يعرض الإشعار محلياً حسب حالة التطبيق، عشان ما يتكررش:
/// - التطبيق شغال قدامك (foreground): الـ listener يعرضه فوراً.
/// - التطبيق في الخلفية: لو رسالة FCM اتبعتت، النظام بيعرضها بنفسه
///   (السيرفر بيكتب fcmSent=true)، فنستنى شوية ونفحص المستند. لو FCM
///   ما اتبعتتش (مفيش function أو فشلت) نعرض إحنا محلياً. الفحص لو فشل = نعرض.
class NotificationPresenter {
  static Duration backgroundGrace = const Duration(seconds: 8);

  @visibleForTesting
  static bool Function() isForegroundOverride = _defaultIsForeground;

  static bool _defaultIsForeground() {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  }

  static Future<void> present({
    required String docId,
    required Future<bool> Function() sentByFcm,
    required Future<void> Function() show,
    Duration? grace,
  }) async {
    if (!NotificationDedupe.claim(docId)) return;
    if (!isForegroundOverride()) {
      await Future.delayed(grace ?? backgroundGrace);
      try {
        if (await sentByFcm()) return; // النظام عرضها بالفعل
      } catch (_) {
        // مش قادرين نتأكد: الأفضل نعرض بدل ما نضيّع إشعار
      }
    }
    await show();
  }
}
