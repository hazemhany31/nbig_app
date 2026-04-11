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
  debugPrint('📲 [BG] NBIG FCM received: ${message.messageId}');

  // Extract title and body from notification or data payload
  final String title =
      message.notification?.title ?? message.data['title'] ?? 'إشعار جديد';
  final String body =
      message.notification?.body ?? message.data['body'] ?? 'لديك تحديث جديد';

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
    title: title,
    body: body,
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

  debugPrint('📲 [BG] NBIG Notification shown: $title');
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

    // Note: This matches the initialization in NotificationService but integrates with FCM
    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle when user taps the notification
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 2.5 Android: Explicitly create the high importance channel
    if (Platform.isAndroid) {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'high_importance_channel',
              'High Importance Notifications',
              description: 'This channel is used for important notifications.',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
    }

    // 3. Background messaging setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Foreground messaging setup (notification payload and/or data-only)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
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
      debugPrint(
        'App opened from terminated state via: ${initialMessage.data}',
      );
    }

    // 6. Save token now and whenever auth session changes (login after cold start)
    await saveFCMToken();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        saveFCMToken();
      }
    });
  }

  Future<void> saveFCMToken() async {
    try {
      // iOS simulator doesn't support APNS — skip entirely
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken;
        try {
          apnsToken = await _fcm.getAPNSToken().timeout(
            const Duration(seconds: 3),
          );
        } catch (_) {}

        if (apnsToken == null) {
          debugPrint(
            'APNS token unavailable (simulator?). Skipping FCM token save.',
          );
          return;
        }
      }

      final String? token = await _fcm.getToken().timeout(
        const Duration(seconds: 5),
      );
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
    final String title = notification?.title ?? data['title'] ?? 'إشعار جديد';
    final String body = notification?.body ?? data['body'] ?? 'لديك تحديث جديد';

    await showManualNotification(
      title,
      body,
      payload: data.isNotEmpty ? jsonEncode(data) : null,
    );
  }

  // Helper method to show notification manually (used by background handler too)
  Future<void> showManualNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel', // id
          'High Importance Notifications', // name
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
