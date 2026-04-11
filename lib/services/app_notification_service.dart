import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'database_helper.dart';

class AppNotificationService {
  static final AppNotificationService _instance = AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  StreamSubscription? _subscription;
  final Set<String> _processedIds = {};
  bool _isFirstLoad = true;

  void startListening() {
    stopListening();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final recipientIds = [user.uid]; // Patient uses Auth UID
    debugPrint('📡 AppNotificationService: Listening for $recipientIds');

    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', whereIn: recipientIds)
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .listen(
      (snapshot) {
        void processDoc(DocumentSnapshot doc) {
          final docId = doc.id;
          if (_processedIds.contains(docId)) return;
          
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return;
          
          _processedIds.add(docId);
          final title = data['title'] ?? 'تحديث جديد';
          final body = data['body'] ?? 'لديك إشعار جديد';

          NotificationService().showNotification(title, body);

          final type = data['type'] as String?;
          final apptId = data['appointmentId'] as String?;

          if (apptId != null && apptId.isNotEmpty) {
            if (type == 'appointment_confirmed') {
              DatabaseHelper().updateAppointmentStatusByFirestoreId(apptId, 'confirmed');
            } else if (type == 'appointment_cancelled') {
              DatabaseHelper().updateAppointmentStatusByFirestoreId(apptId, 'cancelled');
            }
          }

          // In patient app, we mark as read immediately as there is no notification screen yet
          _markAsRead(docId);
        }

        if (_isFirstLoad) {
          final now = DateTime.now();
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            final createdAt = data?['createdAt'] != null
                ? (data!['createdAt'] as Timestamp).toDate()
                : null;

            if (createdAt != null && now.difference(createdAt).inMinutes > 10) {
              _processedIds.add(doc.id);
            }
          }
          _isFirstLoad = false;

          for (var doc in snapshot.docs) {
            if (!_processedIds.contains(doc.id)) {
              processDoc(doc);
            }
          }
          return;
        }

        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            processDoc(change.doc);
          }
        }
      },
      onError: (e) {
        debugPrint('AppNotificationService stream error: $e');
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
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _processedIds.clear();
  }
}
