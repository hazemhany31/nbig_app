// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import 'sign_up_screen.dart';
import 'auth_check.dart';

/// Premium glassmorphic login screen for the Patient App
/// Features floating spheres, animated field focus, and bilingual support.
class LoginScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const LoginScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Floating sphere animation
  late AnimationController _sphereController;

  // Content entrance stagger
  late AnimationController _entranceController;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    _sphereController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    ));

    _formFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
    ));

    _buttonFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _sphereController.dispose();
    _entranceController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (mounted) {
        // Navigate to AuthCheck (root) and clear stack
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AuthCheck(
              toggleTheme: widget.toggleTheme,
              isDark: widget.isDark,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: SignUpScreen(
            toggleTheme: widget.toggleTheme,
            isDark: widget.isDark,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // === Deep Gradient Background ===
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isDark
                      ? [const Color(0xFF060D1A), const Color(0xFF0F172A)]
                      : [const Color(0xFF064E3B), const Color(0xFF0B6E6E), const Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // === Floating Spheres ===
            ..._buildFloatingSpheres(size),

            // === Main Content ===
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SizedBox(
                  height: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  child: Column(
                    children: [
                      // Header controls (Theme toggle)
                      Align(
                        alignment: isArabic ? Alignment.topLeft : Alignment.topRight,
                        child: IconButton(
                          icon: Icon(
                            widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          onPressed: widget.toggleTheme,
                        ),
                      ),
                      
                      const Spacer(),

                      // === Logo & Welcome ===
                      FadeTransition(
                        opacity: _logoFade,
                        child: SlideTransition(
                          position: _logoSlide,
                          child: _buildHeader(isArabic),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // === Glass Card Form ===
                      FadeTransition(
                        opacity: _formFade,
                        child: SlideTransition(
                          position: _formSlide,
                          child: _buildGlassForm(isArabic),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // === Login Button ===
                      FadeTransition(
                        opacity: _buttonFade,
                        child: _buildLoginButton(isArabic),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // === Sign Up Link ===
                      FadeTransition(
                        opacity: _buttonFade,
                        child: TextButton(
                          onPressed: _goToSignUp,
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              children: [
                                TextSpan(
                                  text: isArabic ? 'ليس لديك حساب؟ ' : 'Don\'t have an account? ',
                                ),
                                TextSpan(
                                  text: isArabic ? 'سجل الآن' : 'Sign Up',
                                  style: const TextStyle(
                                    color: Color(0xFFFBBF24), // Gold accent
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isArabic) {
    return Column(
      children: [
        // Medical cross icon with glow
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: const Icon(
            Icons.health_and_safety_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isArabic ? 'مرحباً بعودتك' : 'Welcome Back',
          style: GoogleFonts.cairo(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isArabic ? 'سجل دخولك لمتابعة صحتك' : 'Log in to manage your health',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassForm(bool isArabic) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Email Field
                _buildGlassField(
                  controller: emailController,
                  icon: Icons.email_rounded,
                  hintText: isArabic ? 'البريد الإلكتروني' : 'Email Address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return isArabic ? 'مطلوب' : 'Required';
                    if (!v.contains('@')) return isArabic ? 'بريد غير صالح' : 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                _buildGlassField(
                  controller: passwordController,
                  icon: Icons.lock_rounded,
                  hintText: isArabic ? 'كلمة المرور' : 'Password',
                  obscure: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return isArabic ? 'مطلوب' : 'Required';
                    if (v.length < 6) return isArabic ? 'قصير جداً' : 'Too short';
                    return null;
                  },
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.cairo(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 22),
        suffixIcon: suffix,
        hintText: hintText,
        hintStyle: GoogleFonts.cairo(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFFFBBF24).withValues(alpha: 0.6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        errorStyle: GoogleFonts.cairo(color: const Color(0xFFFCA5A5), fontSize: 12),
      ),
    );
  }

  Widget _buildLoginButton(bool isArabic) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: _AnimatedPressButton(
        onPressed: _isLoading ? null : _login,
        child: Container(
          decoration: BoxDecoration(
            gradient: _isLoading
                ? LinearGradient(
                    colors: [
                      const Color(0xFF0B6E6E).withValues(alpha: 0.5),
                      const Color(0xFF0D9488).withValues(alpha: 0.5),
                    ],
                  )
                : const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isLoading
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isArabic ? 'تسجيل الدخول' : 'Sign In',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, 
                        color: Colors.white, 
                        size: 22
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingSpheres(Size size) {
    final spheres = [
      _SphereData(0.15, 0.1, 80, 0.06),
      _SphereData(0.75, 0.2, 120, 0.05),
      _SphereData(0.3, 0.7, 60, 0.04),
      _SphereData(0.85, 0.65, 90, 0.07),
      _SphereData(0.5, 0.85, 70, 0.03),
    ];

    return spheres.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      return AnimatedBuilder(
        animation: _sphereController,
        builder: (context, _) {
          final t = (_sphereController.value + i * 0.2) % 1.0;
          final dx = math.sin(t * math.pi * 2) * 25;
          final dy = math.cos(t * math.pi * 2 + i) * 20;
          return Positioned(
            left: size.width * s.x + dx,
            top: size.height * s.y + dy,
            child: Container(
              width: s.size,
              height: s.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: s.opacity),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

class _SphereData {
  final double x, y, size, opacity;
  const _SphereData(this.x, this.y, this.size, this.opacity);
}

/// Scale-press micro-interaction button
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const _AnimatedPressButton({required this.child, this.onPressed});

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          HapticFeedback.lightImpact();
          _controller.forward();
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          _controller.reverse();
          widget.onPressed!();
        }
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
