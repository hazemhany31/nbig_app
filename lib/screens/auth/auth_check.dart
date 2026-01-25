import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../main_layout.dart';

import 'onboarding_screen.dart';

// === AUTH CHECK ===
class AuthCheck extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;
  const AuthCheck({super.key, required this.toggleTheme, required this.isDark});
  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          // عرض شاشة التحميل أثناء انتظار حالة تسجيل الدخول
          return const Scaffold(
            backgroundColor: Colors.blue,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          final user = authSnapshot.data!;

          // استخدام FutureBuilder مع مهلة زمنية (Timeout)
          return FutureBuilder<Map<String, dynamic>?>(
            future: _authService.getUserData().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint("AuthCheck: User data fetch timed out. Proceeding.");
                return null;
              },
            ),
            builder: (context, userSnapshot) {
              // لو لسه بيحمل نشوف هل طول زيادة عن اللزوم؟
              // ولكن التايم أوت فوق هيتصرف.
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.blue,
                  body: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }

              // في حالة حدوث خطأ، نكمل عادي عشان المستخدم ميعلقش
              if (userSnapshot.hasError) {
                debugPrint(
                  "AuthCheck: Error fetching user data: ${userSnapshot.error}",
                );
                // نكمل كأن مفيش داتا إضافية
              }

              final userData = userSnapshot.data;

              // لو البيانات مش موجودة، نحفظها في Firestore
              if (userData == null || userData.isEmpty) {
                final phoneNumber = user.phoneNumber ?? '';
                // نحاول نحفظ لو المعانا رقم تليفون أو إيميل
                if (phoneNumber.isNotEmpty ||
                    (user.email != null && user.email!.isNotEmpty)) {
                  _authService.saveUserData(
                    phoneNumber: phoneNumber,
                    name: user.displayName ?? 'User',
                    email: user.email ?? '',
                    role: 'patient',
                  );
                }
              }

              final userName =
                  userData?['name'] ??
                  user.displayName ??
                  user.phoneNumber ??
                  user.email?.split('@')[0] ??
                  'User';

              // التوجيه دائماً للواجهة الرئيسية
              return MainLayout(
                userName: userName,
                toggleTheme: widget.toggleTheme,
                isDark: widget.isDark,
              );
            },
          );
        }

        // المستخدم غير مسجل دخول
        return OnboardingScreen(
          toggleTheme: widget.toggleTheme,
          isDark: widget.isDark,
        );
      },
    );
  }
}
