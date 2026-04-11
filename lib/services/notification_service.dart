import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _ready;

  Future<void> init() {
    _ready ??= _initImpl();
    return _ready!;
  }

  Future<void> _initImpl() async {
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (_) {
      // Fallback to a default or just leave it
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

    // Request permissions for Android 13+
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  static const NotificationDetails _defaultDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'doctor_app_channel',
      'Doctor App Notifications',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// إشعار فوري
  Future<void> showNotification(String title, String body) async {
    if (kIsWeb) return;
    await init();
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: _defaultDetails,
    );
  }

  /// جدولة إشعار قبل الموعد بساعة
  Future<void> scheduleAppointmentReminder({
    required int id,
    required String doctorName,
    required DateTime appointmentDateTime,
    bool isArabic = false,
  }) async {
    if (kIsWeb) return;
    // إشعار قبل الموعد بساعة
    final reminderTime = appointmentDateTime.subtract(const Duration(hours: 1));

    // لو الموعد خلاص عدى، ما نجدولش
    if (reminderTime.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzReminder = tz.TZDateTime.from(reminderTime, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: isArabic ? '⏰ تذكير بموعدك' : '⏰ Appointment Reminder',
      body: isArabic
          ? 'موعدك مع $doctorName بعد ساعة!'
          : 'Your appointment with $doctorName is in 1 hour!',
      scheduledDate: tzReminder,
      notificationDetails: _defaultDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  int _parseDuration(String text) {
    if (text.isEmpty) return 1;
    final lower = text.toLowerCase();
    int multiplier = 1;
    if (lower.contains('أسبوع') || lower.contains('week')) multiplier = 7;
    if (lower.contains('شهر') || lower.contains('month')) multiplier = 30;
    
    final match = RegExp(r'(\d+)').firstMatch(text);
    if (match != null) {
      return int.parse(match.group(1)!) * multiplier;
    }
    // If no number, but has word week/month
    if (multiplier > 1) return multiplier;
    return 1;
  }

  /// جدولة تنبيهات الأدوية بناءً على التكرار والمدة
  Future<void> scheduleMedicationReminders({
    required String medicineName,
    required String dosage,
    required String frequency,
    int? frequencyHours,
    required String duration,
    required DateTime startTime,
    bool isArabic = false,
  }) async {
    if (kIsWeb) return;
    int intervalHours = 24;
    
    if (frequencyHours != null && frequencyHours > 0) {
      intervalHours = frequencyHours;
    } else {
      int? freqCount = _extractNumber(frequency);
      if (freqCount != null && freqCount > 0) {
        intervalHours = 24 ~/ freqCount;
      }
    }

    int durDays = _parseDuration(duration);
    int totalReminders = (durDays * 24) ~/ intervalHours;

    DateTime currentScheduleTime = startTime;
    final now = DateTime.now();

    // Fast forward to the next future time to start scheduling
    while (currentScheduleTime.isBefore(now)) {
      currentScheduleTime = currentScheduleTime.add(Duration(hours: intervalHours));
    }

    for (int i = 0; i < totalReminders; i++) {
      final tz.TZDateTime tzSchedule = tz.TZDateTime.from(currentScheduleTime, tz.local);
      
      int notificationId = (medicineName.hashCode ^ currentScheduleTime.millisecondsSinceEpoch ~/ 1000).abs() % 100000;

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: notificationId,
        title: isArabic ? '💊 موعد الدواء: $medicineName' : '💊 Medicine Time: $medicineName',
        body: isArabic 
            ? 'حان وقت جرعة $dosage من $medicineName. تمنياتنا بالشفاء!' 
            : 'It\'s time for your $dosage dose of $medicineName. Get well soon!',
        scheduledDate: tzSchedule,
        notificationDetails: _defaultDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      currentScheduleTime = currentScheduleTime.add(Duration(hours: intervalHours));
    }
  }

  /// إلغاء تنبيهات دواء معين
  Future<void> cancelMedicationReminders(String medicineName) async {
    final List<PendingNotificationRequest> pendingNotifications =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    
    for (var pending in pendingNotifications) {
      if (pending.title?.contains(medicineName) ?? false) {
        await flutterLocalNotificationsPlugin.cancel(id: pending.id);
      }
    }
  }

  int? _extractNumber(String text) {
    final RegExp regExp = RegExp(r'(\d+)');
    final match = regExp.firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : null;
  }
}
