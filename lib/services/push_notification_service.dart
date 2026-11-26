import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Top-level function for background messages
// IMPORTANT: This runs in a separate ISOLATE.
// It CANNOT use singletons or any un-initialized state.
// It must initialize everything it needs from scratch.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📲 [BG] FCM received: ${message.messageId}');

  // If OS notification payload is present, Android/iOS handle system display natively.
  if (message.notification != null) {
    debugPrint('📲 [BG] OS notification payload present — skipping manual local display to avoid duplicate.');
    return;
  }

  // Extract title and body from data payload (data-only message)
  final String? title = message.data['title']?.toString();
  final String? body  = message.data['body']?.toString();

  if (title == null && body == null) {
    debugPrint('📲 [BG] Data payload has no title or body — skipping display.');
    return;
  }

  // Initialize a fresh local notifications plugin for this isolate
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await plugin.show(
    id: message.hashCode,
    title: title ?? 'إشعار جديد',
    body: body ?? 'لديك تحديث جديد',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
  );

  debugPrint('📲 [BG] Notification shown for data-only message: $title');
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get localNotificationsPlugin =>
      _localNotificationsPlugin;

  Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 2. Initialize Local Notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 2.5 Android: Create notification channels
    if (Platform.isAndroid) {
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'doctor_app_channel',
            'iHEALTY+ Notifications',
            description: 'إشعارات iHEALTY+',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }

    // 3. Background messaging setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Foreground messaging setup
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
      }
      final hasVisual =
          message.notification != null ||
          message.data.containsKey('title') ||
          message.data.containsKey('body');
      if (hasVisual) {
        _showLocalNotification(message);
      }
    });

    // 5. App opened from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened via notification: ${message.data}');
    });

    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state via: ${initialMessage.data}');
    }

    // 6. Save token now and whenever auth session changes
    await saveFCMToken();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        saveFCMToken();
      }
    });

    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM Token refreshed in ihealthy');
      saveFCMToken();
    });
  }

  Future<void> saveFCMToken() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken;
        try {
          apnsToken = await _fcm.getAPNSToken().timeout(
            const Duration(seconds: 2),
          );
        } catch (_) {}

        if (apnsToken != null) {
          debugPrint('APNS token available in ihealthy.');
        } else {
          debugPrint('APNS token unavailable or pending in ihealthy.');
        }
      }

      final String? token = await _fcm.getToken().timeout(
        const Duration(seconds: 6),
      );
      if (token != null) {
        debugPrint('FCM Token: $token');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'fcmToken': token,
                'fcmUpdatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          debugPrint('FCM Token saved successfully for user ${user.uid}');
        }
      }
    } catch (e) {
      debugPrint('Error saving FCM Token: $e');
    }
  }

  /// Clears the saved FCM token from Firestore for the user (called on Logout)
  Future<void> clearFCMToken({String? targetUid}) async {
    final uid = targetUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    debugPrint('🧹 Purging FCM token for ihealthy user: $uid');
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()}).catchError((e) {
        debugPrint('⚠️ Error deleting fcmToken from users/$uid: $e');
      });
      debugPrint('✅ FCM token purged successfully for user: $uid');
    } catch (e) {
      debugPrint('❌ Failed to clear FCM token: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final String title = notification?.title ?? data['title'] ?? 'إشعار جديد';
    final String body = notification?.body ?? data['body'] ?? 'لديك تحديث جديد';

    await showManualNotification(
      title,
      body,
      payload: data.isNotEmpty ? jsonEncode(data) : null,
    );
  }

  Future<void> showManualNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }
}
