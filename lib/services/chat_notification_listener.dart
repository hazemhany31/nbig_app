import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'push_notification_service.dart';

/// يراقب collection `notifications` في Firestore
/// ويعرض local push notification للمريض لما الدكتور يرد على رسالته.
///
/// يُشغَّل بعد تسجيل الدخول ويُوقَف عند تسجيل الخروج.
class ChatNotificationListener {
  static final ChatNotificationListener _instance =
      ChatNotificationListener._internal();
  factory ChatNotificationListener() => _instance;
  ChatNotificationListener._internal();

  StreamSubscription<QuerySnapshot>? _subscription;
  String? _currentUserId;

  /// ابدأ الاستماع للإشعارات بتاعة المريض المسجّل دلوقتي.
  /// لو كان فيه listener قديم، يتوقف أولاً.
  Future<void> startListening() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ ChatNotificationListener: no logged-in user, skipping.');
      return;
    }

    // لو نفس اليوزر وعنده listener شغّال، ما نعملش حاجة
    if (_currentUserId == user.uid && _subscription != null) return;

    await stopListening();
    _currentUserId = user.uid;

    debugPrint(
        '🔔 ChatNotificationListener: started for user ${user.uid}');

    // نستمع على كل الإشعارات غير المقروءة للمريض (شات + مواعيد)
    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'unread')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (snapshot) => _handleSnapshot(snapshot),
          onError: (e) =>
              debugPrint('❌ ChatNotificationListener error: $e'),
        );
  }

  /// أوقف الاستماع
  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    debugPrint('🔕 ChatNotificationListener: stopped.');
  }

  // ─── نتابع التغييرات دي فقط (الجديدة) ────────────────────────────────────
  // نحفظ الـ IDs اللي عرضناها عشان ما نكررش الإشعار
  final Set<String> _shown = {};

  Future<void> _handleSnapshot(QuerySnapshot snapshot) async {
    for (final change in snapshot.docChanges) {
      // نتعامل فقط مع الإشعارات الجديدة (added) اللي ما شوفناهاش
      if (change.type != DocumentChangeType.added) continue;
      final docId = change.doc.id;
      if (_shown.contains(docId)) continue;
      _shown.add(docId);

      final data = change.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final String title = (data['title'] ?? 'رسالة جديدة').toString();
      final String body = (data['body'] ?? '').toString();

      if (title.isEmpty && body.isEmpty) continue;

      debugPrint('📨 ChatNotificationListener: showing → $title');

      // عرض الإشعار محلياً
      await PushNotificationService().showManualNotification(
        title,
        body.isNotEmpty ? body : '...',
      );

      // نعلّم الإشعار كـ delivered عشان ما يجيش تاني
      _markDelivered(change.doc.reference);
    }
  }

  /// نغيّر status لـ 'delivered' عشان ما يتعرضش تاني
  void _markDelivered(DocumentReference ref) {
    ref.update({'status': 'delivered'}).catchError((e) {
      debugPrint('⚠️ Could not mark notification delivered: $e');
    });
  }
}
