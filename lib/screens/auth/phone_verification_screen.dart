import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_check.dart';

// === PHONE VERIFICATION SCREEN ===
class PhoneVerificationScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;
  final String phoneNumber;
  final String? name;
  final String? email;

  const PhoneVerificationScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
    required this.phoneNumber,
    this.name,
    this.email,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 6 controllers for each OTP digit
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _verificationId;
  bool _isSendingCode = true;
  bool _isVerifying = false;
  bool _codeSent = false;

  // Resend timer
  int _resendCountdown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _animController.forward();
    _sendVerificationCode();
  }

  @override
  void dispose() {
    _animController.dispose();
    _resendTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────── SEND CODE ───────────────────────────
  Future<void> _sendVerificationCode() async {
    setState(() {
      _isSendingCode = true;
      _codeSent = false;
    });

    // Format the phone number — ensure it starts with +
    String phone = widget.phoneNumber.trim();
    // Remove spaces and dashes
    phone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (!phone.startsWith('+')) {
      // Default to Egypt (+20), and if starts with 0 remove it first
      if (phone.startsWith('0')) phone = phone.substring(1);
      phone = '+20$phone';
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android (silent SMS)
          if (mounted) {
            setState(() {
              _isSendingCode = false;
              _codeSent = true;
            });
          }
          await _verifyWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isSendingCode = false);
            _showError(_getFirebaseError(e));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isSendingCode = false;
              _codeSent = true;
            });
            _startResendTimer();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              // If timeout arrives and code was never sent, show error
              if (!_codeSent) {
                _isSendingCode = false;
              }
            });
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isSendingCode = false);
        _showError(_getFirebaseError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingCode = false);
        _showError('تعذّر إرسال الكود، تأكد من رقم الهاتف وحاول مرة أخرى');
      }
    }
  }

  // ─────────────────────────── VERIFY OTP ───────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showError('يرجى إدخال الكود كامل (6 أرقام)');
      return;
    }
    if (_verificationId == null) {
      _showError('لم يتم استلام كود التحقق بعد');
      return;
    }

    setState(() => _isVerifying = true);

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    await _verifyWithCredential(credential);
  }

  Future<void> _verifyWithCredential(PhoneAuthCredential credential) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Link phone to existing email/password account
        await currentUser.linkWithCredential(credential);
      } else {
        await _auth.signInWithCredential(credential);
      }

      if (mounted) {
        setState(() => _isVerifying = false);
        _navigateToHome();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        _showError(_getFirebaseError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        _showError('فشل التحقق: $e');
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AuthCheck(
          toggleTheme: widget.toggleTheme,
          isDark: widget.isDark,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
      (route) => false,
    );
  }

  // ─────────────────────────── RESEND ───────────────────────────
  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) timer.cancel();
    });
  }

  // ─────────────────────────── HELPERS ───────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'كود التحقق غير صحيح، يرجى المحاولة مرة أخرى';
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صالح، تأكد من صيغة الرقم';
      case 'too-many-requests':
        return 'طلبات كثيرة جداً، يرجى الانتظار قليلاً ثم المحاولة';
      case 'session-expired':
        return 'انتهت صلاحية الكود، اضغط "إعادة إرسال"';
      case 'credential-already-in-use':
        return 'رقم الهاتف مرتبط بحساب آخر مسبقاً';
      case 'provider-already-linked':
        return 'رقم الهاتف مربوط بالحساب مسبقاً';
      case 'internal-error':
        // Happens when reCAPTCHA is dismissed or APNs not configured
        return 'تعذّر إرسال الكود. يمكنك تخطي التحقق الآن والاستمرار';
      case 'missing-client-identifier':
      case 'missing-app-credential':
        return 'خطأ في إعداد التطبيق. جرّب مرة أخرى.';
      case 'quota-exceeded':
        return 'تجاوزنا الحد اليومي لإرسال الرسائل. حاول لاحقاً';
      case 'network-request-failed':
        return 'تحقق من الاتصال بالإنترنت وحاول مرة أخرى';
      default:
        return e.message ?? 'حدث خطأ: ${e.code}';
    }
  }

  // ─────────────────────────── OTP BOX ───────────────────────────
  Widget _buildOtpBox(int index, bool isDark) {
    return SizedBox(
      width: 48,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _otpControllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
            _otpControllers[index - 1].clear();
          }
        },
        child: TextField(
          controller: _otpControllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF6366F1),
                width: 2.5,
              ),
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            }
            if (value.isNotEmpty && index == 5) {
              // Auto-verify when last digit is entered
              FocusScope.of(context).unfocus();
              Future.delayed(
                const Duration(milliseconds: 200),
                _verifyOtp,
              );
            }
            setState(() {});
          },
        ),
      ),
    );
  }

  // ─────────────────────────── BUILD ───────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final filledDigits = _otpControllers.where((c) => c.text.isNotEmpty).length;

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
          // ── Background gradient ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1A1040)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEDE9FE)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),

          // ── Glowing orbs ──
          Positioned(
            top: -60,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(
                      alpha: isDark ? 0.2 : 0.12,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0EA5E9).withValues(
                      alpha: isDark ? 0.18 : 0.1,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ──
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                        // ── Phone icon with glow ──
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (context, val, child) {
                            return Transform.scale(scale: val, child: child);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFF6366F1).withValues(
                                      alpha: 0.1,
                                    ),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withValues(
                                  alpha: 0.3,
                                ),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.25),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              size: 52,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Title ──
                        Text(
                          isArabic
                              ? 'تحقق من رقمك'
                              : 'Verify Your Number',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isArabic
                              ? 'تم إرسال كود التحقق إلى'
                              : 'Verification code sent to',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color:
                                isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.phoneNumber,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6366F1),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ── Glass card ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(
                                        0xFF1E293B,
                                      ).withValues(alpha: 0.65)
                                    : Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // ── OTP boxes ──
                                  if (_isSendingCode) ...[
                                    const SizedBox(height: 12),
                                    const CircularProgressIndicator(
                                      color: Color(0xFF6366F1),
                                      strokeWidth: 2.5,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      isArabic
                                          ? 'جارٍ إرسال الكود...'
                                          : 'Sending code...',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ] else ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(
                                        6,
                                        (i) => _buildOtpBox(i, isDark),
                                      ),
                                    ),
                                    const SizedBox(height: 32),

                                    // ── Verify button ──
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: (filledDigits < 6 ||
                                                _isVerifying)
                                            ? null
                                            : _verifyOtp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          disabledBackgroundColor:
                                              Colors.transparent,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          decoration: BoxDecoration(
                                            gradient: filledDigits < 6
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.grey[400]!,
                                                      Colors.grey[500]!,
                                                    ],
                                                  )
                                                : const LinearGradient(
                                                    colors: [
                                                      Color(0xFF6366F1),
                                                      Color(0xFF0EA5E9),
                                                    ],
                                                  ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: filledDigits < 6
                                                ? []
                                                : [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF6366F1,
                                                      ).withValues(alpha: 0.4),
                                                      blurRadius: 14,
                                                      offset:
                                                          const Offset(0, 6),
                                                    ),
                                                  ],
                                          ),
                                          child: Center(
                                            child: _isVerifying
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
                                                        ? 'تأكيد الكود'
                                                        : 'Verify Code',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Resend section ──
                        if (_codeSent)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _resendCountdown > 0
                                ? Text(
                                    isArabic
                                        ? 'يمكن إعادة الإرسال بعد $_resendCountdown ثانية'
                                        : 'Resend in $_resendCountdown seconds',
                                    key: ValueKey(_resendCountdown),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  )
                                : TextButton.icon(
                                    key: const ValueKey('resend-btn'),
                                    onPressed: _sendVerificationCode,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      color: Color(0xFF6366F1),
                                      size: 18,
                                    ),
                                    label: Text(
                                      isArabic
                                          ? 'إعادة إرسال الكود'
                                          : 'Resend Code',
                                      style: const TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),

                        const SizedBox(height: 16),

                        // ── Skip (if phone is optional) ──
                        TextButton(
                          onPressed: _navigateToHome,
                          child: Text(
                            isArabic
                                ? 'تخطي التحقق الآن'
                                : 'Skip verification for now',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
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
}
