import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_check.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/chat_notification_listener.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // === تهيئة Firebase مع الإعدادات الصحيحة ===
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    debugPrint('ℹ️ Firebase already initialized, continuing...');
  }

  // === إعداد Firebase Crashlytics للإنتاج ===
  if (!kIsWeb) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // === تفعيل Firestore Offline Persistence ===
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (!kIsWeb) {
    await NotificationService().init();
    await PushNotificationService().initialize();

    // ابدأ/أوقف الاستماع لإشعارات الشات بناءً على حالة الـ auth
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        ChatNotificationListener().startListening();
      } else {
        ChatNotificationListener().stopListening();
      }
    });
  }

  runApp(
    // تغليف التطبيق بـ ProviderScope لعمل Riverpod
    const ProviderScope(
      child: DoctorApp(),
    ),
  );
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
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF0B6E6E),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0B6E6E),
          onPrimary: Colors.white,
          secondary: Color(0xFF0D9488),
          onSecondary: Colors.white,
          tertiary: Color(0xFF3B82F6),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0F172A),
          outline: Color(0xFFE2E8F0),
          error: Color(0xFFEF4444),
        ),
        cardColor: Colors.white,
        textTheme: GoogleFonts.cairoTextTheme(
          const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: Color(0xFF0F172A)),
            displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Color(0xFF0F172A)),
            headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
            headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF334155), height: 1.5),
            bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF64748B), height: 1.5),
            bodySmall: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
            labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
            labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
          ),
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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            borderSide: const BorderSide(color: Color(0xFF0B6E6E), width: 2),
          ),
          hintStyle: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF94A3B8)),
          labelStyle: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        chipTheme: const ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF0B6E6E) : const Color(0xFFCBD5E1)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0D9488),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0D9488),
          onPrimary: Colors.white,
          secondary: Color(0xFF0B6E6E),
          onSecondary: Colors.white,
          tertiary: Color(0xFF3B82F6),
          surface: Color(0xFF1E293B),
          onSurface: Color(0xFFE2E8F0),
          outline: Color(0xFF334155),
          error: Color(0xFFF87171),
        ),
        cardColor: const Color(0xFF1E293B),
        textTheme: GoogleFonts.cairoTextTheme(
          const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: Color(0xFFF1F5F9)),
            displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Color(0xFFF1F5F9)),
            headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
            headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
            headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF1F5F9)),
            titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
            titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
            bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0), height: 1.5),
            bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8), height: 1.5),
            bodySmall: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFCBD5E1)),
            labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
          ),
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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            borderSide: const BorderSide(color: Color(0xFF0D9488), width: 2),
          ),
          hintStyle: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF64748B)),
          labelStyle: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF94A3B8)),
        ),
        chipTheme: const ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF0D9488) : const Color(0xFF334155)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
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
