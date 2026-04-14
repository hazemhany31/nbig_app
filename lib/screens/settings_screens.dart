import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

    final titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A));
    final bodyStyle = TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5);

    final offers = isArabic
        ? ['حجز المواعيد بسهولة', 'تواصل آمن مع الأطباء', 'وصول سريع لدعم طبي', 'واجهة حديثة وسهلة الاستخدام']
        : ['Easy appointment booking', 'Secure communication with doctors', 'Fast access to medical support', 'User-friendly and modern interface'];

    return _SettingsBaseScreen(
      title: isArabic ? 'عن التطبيق' : 'About Us',
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF0EA5E9),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Who We Are
          Text(isArabic ? 'من نحن' : 'Who We Are', style: titleStyle),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'نحن منصة رعاية صحية عن بُعد عصرية، مخصصة لربط المرضى بمتخصصين موثوقين في مجال الرعاية الصحية بسهولة وسرعة، مع الحفاظ على أعلى معايير الخصوصية والأمان.'
              : 'We are a modern telehealth platform dedicated to connecting patients with trusted healthcare professionals easily and quickly, while maintaining the highest standards of privacy and security.',
            style: bodyStyle,
          ),
          const SizedBox(height: 20),

          // Our Vision
          Text(isArabic ? 'رؤيتنا' : 'Our Vision', style: titleStyle),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'نسعى إلى إحداث ثورة في الرعاية الصحية بجعل الطب عن بُعد في متناول الجميع، في أي وقت ومن أي مكان.'
              : 'We strive to revolutionize healthcare by making telemedicine accessible, efficient, and reliable for everyone, anytime and anywhere.',
            style: bodyStyle,
          ),
          const SizedBox(height: 20),

          // Our Mission
          Text(isArabic ? 'مهمتنا' : 'Our Mission', style: titleStyle),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'مهمتنا هي تبسيط التواصل بين المرضى والأطباء المؤهلين، وتوفير تجربة سلسة وآمنة تُقدِّم الراحة والخصوصية وجودة الخدمة.'
              : 'Our mission is to simplify communication between patients and qualified doctors, providing a seamless and secure experience that prioritizes comfort, privacy, and quality of service.',
            style: bodyStyle,
          ),
          const SizedBox(height: 20),

          // What We Offer
          Text(isArabic ? 'ما نقدمه' : 'What We Offer', style: titleStyle),
          const SizedBox(height: 10),
          ...offers.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: bodyStyle)),
              ],
            ),
          )),
          const SizedBox(height: 12),

          // Why Choose Us
          Text(isArabic ? 'لماذا تختارنا' : 'Why Choose Us', style: titleStyle),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'نجمع بين التكنولوجيا المتقدمة والخبرة الطبية لضمان حصولك على أفضل رعاية ممكنة بكل سهولة وثقة.'
              : 'We combine advanced technology with medical expertise to ensure you receive the best care possible with convenience and trust.',
            style: bodyStyle,
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
              ? 'نحن نأخذ خصوصيتك على محمل الجد. يتم تشفير جميع بياناتك الشخصية والطبية أثناء الإرسال والتخزين باستخدام معايير أمان على مستوى الصناعة. نلتزم بحماية معلوماتك من الوصول غير المصرح به أو التعديل أو الإفصاح أو الإتلاف.'
              : 'We take your privacy seriously. All your personal and medical data is securely encrypted during transmission and storage using industry-standard security measures. We are committed to protecting your information from unauthorized access, alteration, disclosure, or destruction.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'المعلومات التي نجمعها' : 'Information We Collect',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'قد نجمع معلومات شخصية مثل اسمك وبريدك الإلكتروني والبيانات ذات الصلة بالرعاية الصحية فقط عند الضرورة لتقديم خدماتنا وتحسينها.'
              : 'We may collect personal information such as your name, email address, and medical-related data only when necessary to provide and improve our services.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'كيف نستخدم بياناتك' : 'How We Use Your Data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'تُستخدم بياناتك فقط لتحسين تجربتك داخل التطبيق، بما في ذلك تقديم خدمات مخصصة، وتحسين أداء التطبيق، وضمان دعم أفضل للمستخدمين.'
              : 'Your data is used solely to enhance your experience within the app, including providing personalized services, improving app performance, and ensuring better user support.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'مشاركة البيانات' : 'Data Sharing',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'نحن لا نبيع أو نتاجر أو نؤجر بياناتك الشخصية لأطراف ثالثة. قد تتم مشاركة بياناتك فقط عند الاقتضاء القانوني أو لحماية حقوقنا القانونية.'
              : 'We do not sell, trade, or rent your personal data to third parties. Your data may only be shared when required by law or to protect our legal rights.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'الاحتفاظ بالبيانات' : 'Data Retention',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'نحتفظ ببياناتك فقط طالما كان ذلك ضروريًا لتقديم خدماتنا أو الامتثال للالتزامات القانونية.'
              : 'We retain your data only for as long as necessary to provide our services or comply with legal obligations.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'حقوقك' : 'Your Rights',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'يحق لك الوصول إلى بياناتك الشخصية وتحديثها أو حذفها في أي وقت. يمكنك أيضًا طلب إيقاف استخدام بياناتك.'
              : 'You have the right to access, update, or delete your personal data at any time. You may also request to stop using your data.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'إجراءات الأمان' : 'Security Measures',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'نطبق بروتوكولات أمنية صارمة لحماية معلوماتك، بما في ذلك التشفير والخوادم الآمنة والتحكم في الوصول المحدود.'
              : 'We implement strict security protocols to safeguard your information, including encryption, secure servers, and limited access control.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'إخلاء المسؤولية الطبية' : 'Medical Disclaimer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'هذا التطبيق لا يحل محل الاستشارة الطبية المتخصصة. استشر دائمًا مزود رعاية صحية مؤهلاً عند الحاجة.'
              : 'This app does not replace professional medical advice. Always consult a qualified healthcare provider when needed.',
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
              : 'By using this app, you agree to the collection and use of your information in accordance with this Privacy Policy.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'تواصل معنا' : 'Contact Us',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
              ? 'إذا كان لديك أي أسئلة أو استفسارات حول سياسة الخصوصية هذه، يرجى التواصل معنا عبر:'
              : 'If you have any questions or concerns about this Privacy Policy, please contact us at:',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final Uri emailUri = Uri(
                scheme: 'mailto',
                path: 'info@new-build-egypt.com',
                query: 'subject=Privacy Policy Inquiry',
              );
              if (await canLaunchUrl(emailUri)) {
                await launchUrl(emailUri);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_outlined, color: Color(0xFF0EA5E9), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'info@new-build-egypt.com',
                    style: TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF0EA5E9),
                    ),
                  ),
                ],
              ),
            ),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.hourglass_top_rounded, size: 28, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'قريباً...' : 'Coming Soon...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
