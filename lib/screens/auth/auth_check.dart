import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/auth_service.dart';
import '../main_layout.dart';
import '../doctor/doctor_home_shell.dart';
import 'onboarding_screen.dart';

// === AUTH CHECK ===
class AuthCheck extends ConsumerWidget {
  final VoidCallback toggleTheme;
  final bool isDark;
  
  const AuthCheck({super.key, required this.toggleTheme, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مراقبة حالة المصادقة
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // المستخدم غير مسجل دخول
          return OnboardingScreen(
            toggleTheme: toggleTheme,
            isDark: isDark,
          );
        }

        // المستخدم مسجل، جلب بياناته
        final userAsyncData = ref.watch(userDataProvider);

        return userAsyncData.when(
          data: (userData) {
            final userName = userData?['name'] ?? user.displayName ?? 'User';
            final role = (userData?['role'] ?? 'patient').toString().toLowerCase();

            if (role == 'doctor') {
              return DoctorHomeShell(
                userName: userName,
                toggleTheme: toggleTheme,
                isDark: isDark,
              );
            }

            return MainLayout(
              userName: userName,
              toggleTheme: toggleTheme,
              isDark: isDark,
            );
          },
          loading: () => _buildShimmerLoading(context),
          error: (err, stack) => _buildErrorScreen(context, err.toString()),
        );
      },
      loading: () => _buildShimmerLoading(context),
      error: (err, stack) => _buildErrorScreen(context, err.toString()),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF0F4F8),
      body: Center(
        child: Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey[300]!,
          highlightColor: isDark ? const Color(0xFF334155) : Colors.grey[100]!,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 200,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 150,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text(
              'حدث خطأ ما، يرجى المحاولة لاحقاً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
