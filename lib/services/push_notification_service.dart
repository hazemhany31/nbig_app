import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get localNotificationsPlugin => _localNotificationsPlugin;

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

    // Note: This matches the initialization in NotificationService but integrates with FCM
    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle when user taps the notification
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 3. Background messaging setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Foreground messaging setup
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
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

    // 6. Get and save the FCM token — run in background, never block startup
    saveFCMToken(); // intentionally not awaited
  }

  Future<void> saveFCMToken() async {
    try {
      // iOS simulator doesn't support APNS — skip entirely
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken;
        try {
          apnsToken = await _fcm
              .getAPNSToken()
              .timeout(const Duration(seconds: 3));
        } catch (_) {}

        if (apnsToken == null) {
          debugPrint('APNS token unavailable (simulator?). Skipping FCM token save.');
          return;
        }
      }

      final String? token = await _fcm
          .getToken()
          .timeout(const Duration(seconds: 5));
      if (token != null) {
        debugPrint('FCM Token: $token');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
          debugPrint('FCM Token saved successfully for user ${user.uid}');
        }
      }
    } catch (e) {
      debugPrint('Error saving FCM Token: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    // Fallback if notification title/body are null (data-only messages)
    final String title = notification?.title ?? data['title'] ?? 'New Update';
    final String body = notification?.body ?? data['body'] ?? 'You have a new notification';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel', // id
          'High Importance Notifications', // name
          channelDescription: 'This channel is used for important notifications.',
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
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: data.isNotEmpty ? jsonEncode(data) : null,
    );
  }
}
