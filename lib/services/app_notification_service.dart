import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class AppNotificationService {
  static final AppNotificationService _instance = AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  StreamSubscription? _subscription;
  // Keep track of processed notification IDs to avoid duplicate alerts
  final Set<String> _processedIds = {};
  bool _isFirstLoad = true;

  void startListening() {
    stopListening();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isFirstLoad = true;

    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .listen(
      (snapshot) {
        if (_isFirstLoad) {
          final now = DateTime.now();
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            final createdAt = data?['createdAt'] != null
                ? (data!['createdAt'] as Timestamp).toDate()
                : null;
            
            // If notification is older than 10 minutes, just record it as processed
            // If it's very recent, we might want to alert the user even on startup
            if (createdAt == null || now.difference(createdAt).inMinutes > 10) {
              _processedIds.add(doc.id);
            }
          }
          _isFirstLoad = false;
          // If we didn't add all to processedIds, they will be processed in the loop below
          if (_processedIds.length == snapshot.docs.length) return;
        }

        for (var doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data();
            final docId = doc.doc.id;

            if (data != null && !_processedIds.contains(docId)) {
              _processedIds.add(docId);
              final title = data['title'] ?? 'تحديث جديد';
              final body = data['body'] ?? 'لديك إشعار جديد';

              NotificationService().showNotification(title, body);

              // Optionally mark as read immediately or let the app UI handle it
              // For now, we just mark as read so it doesn't trigger again on another device
              _markAsRead(docId);
            }
          }
        }
      },
      onError: (e) {
// debugPrint('⚠️ AppNotificationService stream error: $e');
      },
      cancelOnError: false,
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'status': 'read'});
    } catch (e) {
// debugPrint('⚠️ Failed to mark notification as read: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _processedIds.clear();
  }
}
