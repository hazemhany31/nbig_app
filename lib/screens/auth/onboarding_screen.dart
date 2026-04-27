// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

/// Premium 3-page onboarding with gradient backgrounds,
/// floating medical icons, and a pulsing "Get Started" CTA.
/// Uses ONLY built-in Flutter animation widgets — no external packages.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const OnboardingScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showSkip = false;

  // Pulsing animation for CTA button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Floating background orbs
  late AnimationController _floatController;

  // Content entrance animation
  late AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.health_and_safety_rounded,
      titleAr: 'صحتك أولويتنا',
      titleEn: 'Your Health, Our Priority',
      subtitleAr: 'تواصل مع أفضل الأطباء واحجز مواعيدك بسهولة وأمان',
      subtitleEn: 'Connect with top doctors and book appointments safely',
      gradientColors: [Color(0xFF064E3B), Color(0xFF0B6E6E), Color(0xFF0D9488)],
      accentColor: Color(0xFF10B981),
      decorIcons: [Icons.favorite_rounded, Icons.local_hospital_rounded, Icons.medical_services_rounded],
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_rounded,
      titleAr: 'تواصل فوري مع طبيبك',
      titleEn: 'Instant Doctor Chat',
      subtitleAr: 'أرسل رسائل وصور مباشرة لطبيبك واحصل على استشارة سريعة',
      subtitleEn: 'Message and share images with your doctor instantly',
      gradientColors: [Color(0xFF1E3A5F), Color(0xFF2563EB), Color(0xFF3B82F6)],
      accentColor: Color(0xFF3B82F6),
      decorIcons: [Icons.message_rounded, Icons.videocam_rounded, Icons.schedule_rounded],
    ),
    _OnboardingPage(
      icon: Icons.calendar_month_rounded,
      titleAr: 'نظّم مواعيدك وأدويتك',
      titleEn: 'Manage Your Health Journey',
      subtitleAr: 'تتبع مواعيدك، أدويتك، وتاريخك الطبي في مكان واحد',
      subtitleEn: 'Track appointments, medications, and health records',
      gradientColors: [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF8B5CF6)],
      accentColor: Color(0xFF8B5CF6),
      decorIcons: [Icons.event_available_rounded, Icons.medication_rounded, Icons.analytics_rounded],
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Pulse for CTA button (only on last page)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Floating orbs
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Content entrance
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic));
    _contentController.forward();

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showSkip = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _contentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    HapticFeedback.selectionClick();
    setState(() => _currentPage = page);
    _contentController.reset();
    _contentController.forward();
  }

  void _goToLogin() {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: LoginScreen(
            toggleTheme: widget.toggleTheme,
            isDark: widget.isDark,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // === Animated Gradient Background ===
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: page.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // === Floating Orbs ===
            ..._buildFloatingOrbs(size, page),

            // === PageView Content ===
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return _buildPageContent(index, size);
              },
            ),

            // === Bottom Controls ===
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(isLast, size),
            ),

            // === Skip Button ===
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: AnimatedOpacity(
                opacity: (isLast || !_showSkip) ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: TextButton(
                  onPressed: isLast ? null : _goToLogin,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'تخطي',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(int index, Size size) {
    final page = _pages[index];

    return FadeTransition(
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // === Large Icon with glow ===
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: page.accentColor.withValues(alpha: 0.3),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      page.icon,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // === Decorative mini icons row ===
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: page.decorIcons.asMap().entries.map((entry) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 400 + entry.key * 150),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Icon(
                            entry.value,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 22,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 48),

              // === Title (Arabic) ===
              Text(
                page.titleAr,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              // === English subtitle ===
              Text(
                page.titleEn,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 20),

              // === Description ===
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  page.subtitleAr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 120), // space for bottom controls
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isLast, Size size) {
    return Container(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        bottom: MediaQuery.of(context).padding.bottom + 32,
        top: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // === Page Indicators ===
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 32 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
              );
            }),
          ),

          const SizedBox(height: 32),

          // === CTA Button ===
          SizedBox(
            width: double.infinity,
            height: 58,
            child: isLast
                ? ScaleTransition(
                    scale: _pulseAnimation,
                    child: _buildCTAButton(),
                  )
                : _buildNextButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton() {
    return GestureDetector(
      onTap: _goToLogin,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ابدأ الآن',
                style: GoogleFonts.cairo(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: () {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'التالي',
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingOrbs(Size size, _OnboardingPage page) {
    return List.generate(5, (i) {
      final offset = i * 1.2;
      return AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final t = (_floatController.value + offset) % 1.0;
          final x = size.width * (0.1 + i * 0.2) +
              math.sin(t * math.pi * 2) * 20;
          final y = size.height * (0.15 + i * 0.15) +
              math.cos(t * math.pi * 2 + i) * 30;
          return Positioned(
            left: x,
            top: y,
            child: Container(
              width: 40 + i * 15.0,
              height: 40 + i * 15.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04 + i * 0.01),
              ),
            ),
          );
        },
      );
    });
  }
}

class _OnboardingPage {
  final IconData icon;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final List<Color> gradientColors;
  final Color accentColor;
  final List<IconData> decorIcons;

  const _OnboardingPage({
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.gradientColors,
    required this.accentColor,
    required this.decorIcons,
  });
}
