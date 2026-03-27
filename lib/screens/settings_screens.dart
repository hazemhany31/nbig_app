import 'dart:ui';
import 'package:flutter/material.dart';

// === COMMON SETTINGS PAGE LAYOUT ===
class _SettingsBaseScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget content;

  const _SettingsBaseScreen({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Stretchy Header
          SliverAppBar(
            expandedHeight: 140.0,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFE0E7FF), const Color(0xFFF8FAFC)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(seconds: 1),
                    curve: Curves.elasticOut,
                    builder: (context, val, child) {
                      return Transform.scale(
                        scale: val,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconColor.withValues(alpha: 0.1),
                            boxShadow: [
                              BoxShadow(color: iconColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 3),
                            ],
                          ),
                          child: Icon(icon, size: 40, color: iconColor),
                        ),
                      );
                    },
                  ),
                ),
              ),
              titlePadding: EdgeInsets.only(
                left: isArabic ? 0 : 16,
                right: isArabic ? 16 : 0,
                bottom: 12,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          
          // Glassmorphic Content
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// === ABOUT US SCREEN ===
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return _SettingsBaseScreen(
      title: isArabic ? 'عن التطبيق' : 'About Us',
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF0EA5E9),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'رؤيتنا' : 'Our Vision',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic 
              ? 'نسعى لتقديم أفضل خدمات الرعاية الصحية عن بُعد وبطريقة سلسة وعصرية تواكب احتياجات المرضى.'
              : 'We strive to provide the best telehealth services seamlessly and modernly to meet patient needs.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'مهمتنا' : 'Our Mission',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'تسهيل التواصل بين النخبة من الأطباء والمرضى، وتوفير تجربة مستخدم متميزة تحافظ على الخصوصية والراحة.'
              : 'Facilitating communication between elite doctors and patients, providing an outstanding user experience that maintains privacy and comfort.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }
}

// === PRIVACY POLICY SCREEN ===
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return _SettingsBaseScreen(
      title: isArabic ? 'سياسة الخصوصية' : 'Privacy Policy',
      icon: Icons.privacy_tip_outlined,
      iconColor: const Color(0xFF64748B),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'حماية بياناتك' : 'Protecting Your Data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic 
              ? 'نحن نأخذ خصوصيتك على محمل الجد. يتم تشفير جميع بياناتك الطبية والشخصية ولا تتم مشاركتها مع أي جهة خارجية بدون موافقتك الصريحة.'
              : 'We take your privacy seriously. All your medical and personal data is encrypted and not shared with any third party without your explicit consent.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'الموافقة' : 'Consent',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'باستخدامك لهذا التطبيق، فإنك توافق على جمع واستخدام معلوماتك وفقاً لهذه السياسة.'
              : 'By using this app, you consent to the collection and use of your information in accordance with this policy.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }
}

// === DONATE SCREEN ===
class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return _SettingsBaseScreen(
      title: isArabic ? 'تبرع' : 'Donate',
      icon: Icons.volunteer_activism_rounded,
      iconColor: const Color(0xFFF43F5E),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.favorite_rounded, size: 60, color: const Color(0xFFF43F5E).withValues(alpha: 0.8)),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'ادعم فريقنا' : 'Support Our Team',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          Text(
            isArabic 
              ? 'مساهمتك تساعدنا في استمرار تقديم أفضل الخدمات الصحية وتطوير التطبيق لخدمتك بشكل أفضل.'
              : 'Your contribution helps us continue to provide the best health services and develop the app to serve you better.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                // Donation logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? 'شكراً لدعمك!' : 'Thank you for your support!'),
                    backgroundColor: const Color(0xFFF43F5E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  )
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF43F5E).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: Text(
                    isArabic ? 'تبرع الآن' : 'Donate Now',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
