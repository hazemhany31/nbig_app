import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_service.dart';
import 'database_helper.dart';

class AppNotificationService {
  static final AppNotificationService _instance = AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  StreamSubscription? _subscription;
  final Set<String> _processedIds = {};
  bool _isFirstLoad = true;

  Future<void> _loadProcessedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('processed_notification_ids') ?? [];
      _processedIds.addAll(saved);
    } catch (e) {
      debugPrint('Error loading processed notification IDs: $e');
    }
  }

  Future<void> _saveProcessedId(String id) async {
    _processedIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('processed_notification_ids', _processedIds.toList());
    } catch (e) {
      debugPrint('Error saving processed notification ID: $e');
    }
  }

  Future<void> startListening() async {
    stopListening();
    await _loadProcessedIds();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final recipientIds = [user.uid];
    debugPrint('📡 AppNotificationService: Listening for $recipientIds');
    _isFirstLoad = true;

    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', whereIn: recipientIds)
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .listen(
      (snapshot) async {
        void processDoc(DocumentSnapshot doc) {
          final docId = doc.id;
          if (_processedIds.contains(docId)) return;
          
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return;
          
          _saveProcessedId(docId);
          final title = (data['title'] ?? 'تحديث جديد').toString();
          final body = (data['body'] ?? 'لديك إشعار جديد').toString();

          PushNotificationService().showManualNotification(title, body);

          final type = data['type'] as String?;
          final apptId = data['appointmentId'] as String?;

          if (apptId != null && apptId.isNotEmpty) {
            if (type == 'appointment_confirmed' || type == 'appointment_accepted') {
              DatabaseHelper().updateAppointmentStatusByFirestoreId(apptId, 'confirmed');
            } else if (type == 'appointment_cancelled' || type == 'appointment_rejected') {
              DatabaseHelper().updateAppointmentStatusByFirestoreId(apptId, 'cancelled');
            }
          }
        }

        if (_isFirstLoad) {
          final now = DateTime.now();
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            final createdAt = data?['createdAt'] != null
                ? (data!['createdAt'] as Timestamp).toDate()
                : null;

            if (createdAt != null && now.difference(createdAt).inMinutes > 10) {
              _saveProcessedId(doc.id);
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
          if (change.type == DocumentChangeType.added) {
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

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _processedIds.clear();
  }
}
