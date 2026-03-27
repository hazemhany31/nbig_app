import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import 'auth_check.dart';


// === SIGN UP SCREEN PREMIUM REDESIGN ===
class SignUpScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;
  const SignUpScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController =
      TextEditingController(); // Optional now

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Directionality.of(context) == TextDirection.rtl
                ? 'يرجى ملء جميع الحقول المطلوبة'
                : 'Please fill all required fields',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Directionality.of(context) == TextDirection.rtl
                ? 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل'
                : 'Password must be at least 6 characters',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUpWithEmailPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AuthCheck(
              toggleTheme: widget.toggleTheme,
              isDark: widget.isDark,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 800),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = Directionality.of(context) == TextDirection.rtl
            ? 'فشل إنشاء الحساب'
            : 'Sign up failed';
        if (e.code == 'email-already-in-use') {
          errorMessage = Directionality.of(context) == TextDirection.rtl
              ? 'هذا البريد الإلكتروني مستخدم بالفعل.'
              : 'The email is already in use by another account.';
        } else if (e.code == 'invalid-email') {
          errorMessage = Directionality.of(context) == TextDirection.rtl
              ? 'البريد الإلكتروني غير صالح.'
              : 'The email address is invalid.';
        } else if (e.code == 'weak-password') {
          errorMessage = Directionality.of(context) == TextDirection.rtl
              ? 'كلمة المرور ضعيفة جدًا.'
              : 'The password is too weak.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Premium Animated Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF172554)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE0E7FF)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),

          // Glowing Spheres
          Positioned(
            top: 50,
            left: -80,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFF0EA5E9,
                          ).withValues(alpha: isDark ? 0.25 : 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFF6366F1,
                          ).withValues(alpha: isDark ? 0.25 : 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Glassmorphic Content Layer
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        FocusScope.of(context).hasFocus
                            ? const SizedBox.shrink()
                            : Center(
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withValues(alpha: 0.2),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 48,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 24),

                        Text(
                          isArabic ? 'إنشاء حساب جديد' : 'Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isArabic
                              ? 'ابدأ رحلتك نحو صحة أفضل'
                              : 'Start your journey to better health',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Form Container: Glassmorphism
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(
                                        0xFF1E293B,
                                      ).withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.white,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Name Field
                                  _buildInputField(
                                    controller: nameController,
                                    icon: Icons.person_outline_rounded,
                                    label: isArabic
                                        ? 'الاسم بالكامل'
                                        : 'Full Name',
                                    isDark: isDark,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 20),

                                  // Email Field
                                  _buildInputField(
                                    controller: emailController,
                                    icon: Icons.alternate_email_rounded,
                                    label: isArabic
                                        ? 'البريد الإلكتروني'
                                        : 'Email Address',
                                    isDark: isDark,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 20),

                                  // Password Field
                                  _buildInputField(
                                    controller: passwordController,
                                    icon: Icons.lock_outline_rounded,
                                    label: isArabic
                                        ? 'كلمة المرور'
                                        : 'Password',
                                    isDark: isDark,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.next,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[400],
                                        size: 20,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Phone Field
                                  _buildInputField(
                                    controller: phoneController,
                                    icon: Icons.phone_outlined,
                                    label: isArabic
                                        ? 'رقم الهاتف (اختياري)'
                                        : 'Phone Number (Optional)',
                                    isDark: isDark,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _signUp(),
                                  ),
                                  const SizedBox(height: 32),

                                  // Sign Up Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _signUp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF0EA5E9),
                                              Color(0xFF6366F1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF6366F1,
                                              ).withValues(alpha: 0.4),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5,
                                                      ),
                                                )
                                              : Text(
                                                  isArabic
                                                      ? 'إنشاء حساب'
                                                      : 'Sign Up',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isArabic
                                  ? 'لديك حساب بالفعل؟'
                                  : "Already have an account?",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                isArabic ? 'تسجيل الدخول' : 'Sign In',
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required bool isDark,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.5)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
            fontSize: 15,
          ),
          prefixIcon: Icon(
            icon,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
            size: 22,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
