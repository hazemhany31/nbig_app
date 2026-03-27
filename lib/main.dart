import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_check.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // === تهيئة Firebase مع الإعدادات الصحيحة ===
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // === تفعيل Firestore Offline Persistence ===
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (!kIsWeb) {
    // Run in background — never block app startup
    NotificationService().init();
    PushNotificationService().initialize();
  }


  // === حذف الدكاترة القديمة (تم التعطيل للاعتماد على Firestore) ===
  // await DatabaseHelper().recreateDoctorsTable();

  // === تم تعطيل الإضافة التلقائية للدكاترة للاعتماد على البيانات الفورية من Firestore ===
  /*
  await DatabaseHelper().insertDoctor({ ... });
  */

  runApp(const DoctorApp());
}

class DoctorApp extends StatefulWidget {
  const DoctorApp({super.key});
  @override
  State<DoctorApp> createState() => _DoctorAppState();
}

class _DoctorAppState extends State<DoctorApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_isDark;
    // حفظ التفضيل أولاً قبل تحديث الحالة
    await prefs.setBool('isDarkMode', newValue);
    // الآن نحدث الحالة بعد التأكد من الحفظ
    if (mounted) {
      setState(() {
        _isDark = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NBIG Health',
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: child!,
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF10B981),
          onPrimary: Colors.white,
          secondary: Color(0xFF6366F1),
          onSecondary: Colors.white,
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0F172A),
          outline: Color(0xFFE2E8F0),
          error: Color(0xFFEF4444),
        ),
        cardColor: Colors.white,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: Color(0xFF0F172A)),
          displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Color(0xFF0F172A)),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF64748B)),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          color: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
          ),
        ),
        chipTheme: const ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          onPrimary: Colors.white,
          secondary: Color(0xFF818CF8),
          onSecondary: Colors.white,
          surface: Color(0xFF1E293B),
          onSurface: Color(0xFFF1F5F9),
          outline: Color(0xFF334155),
          error: Color(0xFFF87171),
        ),
        cardColor: const Color(0xFF1E293B),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: Color(0xFFF1F5F9)),
          displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Color(0xFFF1F5F9)),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF1F5F9)),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
          bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFFCBD5E1)),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          color: Color(0xFF1E293B),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1E293B),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
          ),
        ),
        chipTheme: const ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF10B981) : const Color(0xFF334155)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: AuthCheck(toggleTheme: _toggleTheme, isDark: _isDark),
      // Handle any incoming route by showing AuthCheck, which redirects based on auth state
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) =>
              AuthCheck(toggleTheme: _toggleTheme, isDark: _isDark),
        );
      },
    );
  }
}
