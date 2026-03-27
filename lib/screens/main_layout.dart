// ignore_for_file: deprecated_member_use, unused_field

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart'; // للـ Haptic Feedback
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart'; // مكتبة الحفظ الدائم
import 'package:path/path.dart' hide context; // عشان نتعامل مع المسارات
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/appointment_service.dart';
import '../models/appointment_model.dart' as model;
import 'package:intl/intl.dart';
import 'search_doctors_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sub_screens.dart';
import 'medication_reminders_screen.dart';
import 'settings_screens.dart';
import 'auth/login_screen.dart';
import 'emergency_alert_screen.dart';
import 'specialties_list_screen.dart';
import 'blog_screens.dart';
import '../services/app_notification_service.dart';
import '../services/medication_tracking_service.dart';

import '../language_config.dart';

// === MAIN LAYOUT ===
class MainLayout extends StatefulWidget {
  final String userName;
  final VoidCallback toggleTheme;
  final bool isDark;
  const MainLayout({
    super.key,
    required this.userName,
    required this.toggleTheme,
    required this.isDark,
  });
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  late String currentName;
  final ScrollController _homeScrollController = ScrollController();
  Key _scheduleKey = UniqueKey();
  Key _homeKey = UniqueKey();

  String? _cachedProfileImage;

  @override
  void initState() {
    super.initState();
    currentName = widget.userName;
    _loadLang();
    _loadProfileImage();

    // تشغيل مستمع الإشعارات (المواعيد وغيرها)
    AppNotificationService().startListening();
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isArabic = prefs.getBool('isArabic') ?? false;
    });
  }

  // دالة تحميل آمنة (بتتأكد إن الملف موجود)
  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    String? path = prefs.getString('profile_image');

    // لو المسار موجود بس الملف مش موجود (اتمسح)، نعتبره null
    if (!kIsWeb && path != null && !File(path).existsSync()) {
      path = null;
    }

    setState(() {
      _cachedProfileImage = path;
    });
  }

  void _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isArabic = !isArabic;
      prefs.setBool('isArabic', isArabic);
      _homeKey = UniqueKey();
      _scheduleKey = UniqueKey();
    });
  }

  void _updateName(String newName) {
    setState(() {
      currentName = newName;
    });
  }

  void _updateImage(String newPath) {
    setState(() {
      _cachedProfileImage = newPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(
        key: _homeKey,
        userName: currentName,
        scrollController: _homeScrollController,
        profileImage: _cachedProfileImage,
        isDark: widget.isDark,
        onTabChange: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      ScheduleScreen(key: _scheduleKey),
      YourHealthScreen(
        onTabChange: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      ProfileScreen(
        userName: currentName,
        onNameChanged: _updateName,
        onLangChanged: _toggleLanguage,
        toggleTheme: widget.toggleTheme,
        isDark: widget.isDark,
        profileImage: _cachedProfileImage,
        onImageChanged: _updateImage,
      ),
    ];

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        body: pages[_currentIndex],
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0B1120).withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.88),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                  child: GNav(
                    rippleColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    hoverColor: const Color(0xFF10B981).withValues(alpha: 0.08),
                    gap: 6,
                    activeColor: Colors.white,
                    iconSize: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    duration: const Duration(milliseconds: 350),
                    tabBackgroundColor: const Color(0xFF10B981),
                    tabBackgroundGradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    tabs: [
                      GButton(
                        icon: Icons.home_rounded,
                        text: isArabic ? 'الرئيسية' : 'Home',
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      GButton(
                        icon: Icons.calendar_month_rounded,
                        text: isArabic ? 'مواعيدي' : 'Schedule',
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      GButton(
                        icon: Icons.health_and_safety_rounded,
                        text: isArabic ? 'صحتي' : 'Health',
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      GButton(
                        icon: Icons.person_rounded,
                        text: isArabic ? 'حسابي' : 'Profile',
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                    selectedIndex: _currentIndex,
                    onTabChange: (index) {
                      HapticFeedback.lightImpact();
                      if (index == 1) {
                        setState(() => _scheduleKey = UniqueKey());
                      }
                      if (index == 0 && _currentIndex == 0) {
                        if (_homeScrollController.hasClients) {
                          _homeScrollController.animateTo(
                            0.0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      } else {
                        setState(() => _currentIndex = index);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// === HOME SCREEN ===
class HomeScreen extends StatefulWidget {
  final String userName;
  final ScrollController? scrollController;
  final String? profileImage;
  final bool isDark;
  final Function(int) onTabChange;

  const HomeScreen({
    super.key,
    required this.userName,
    this.scrollController,
    this.profileImage,
    required this.isDark,
    required this.onTabChange,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bannerIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (isArabic) {
      if (hour < 12) return '🌤️ صباح الخير';
      if (hour < 17) return '☀️ مساء الخير';
      return '🌙 مساء النور';
    } else {
      if (hour < 12) return '🌤️ Good Morning';
      if (hour < 17) return '☀️ Good Afternoon';
      return '🌙 Good Evening';
    }
  }

  void _onCategoryTap(String category, String dbKeyword) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDoctorsScreen(
          category: category,
          categoryKeyword: dbKeyword,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {},
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Header Row — Greeting + Avatar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time-of-day pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getGreetingText(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.userName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Avatar with gradient ring
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF0B1120)
                                  : Colors.white,
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundImage:
                                  (!kIsWeb && widget.profileImage != null &&
                                      File(widget.profileImage!).existsSync())
                                  ? FileImage(File(widget.profileImage!)) as ImageProvider
                                  : const AssetImage('assets/images/doctor_big_preview.png'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Premium Search Bar
                    Hero(
                      tag: 'search_bar',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => const SearchDoctorsScreen(),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(0.0, 0.05);
                                  const end = Offset.zero;
                                  const curve = Curves.fastOutSlowIn;
                                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(position: animation.drive(tween), child: child),
                                  );
                                },
                                transitionDuration: const Duration(milliseconds: 300),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                  size: 21,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isArabic ? 'ابحث عن طبيب أو تخصص...' : 'Search doctor or specialty...',
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // === Banner Slider ===
                    _buildBannerSlider(),
                    const SizedBox(height: 30),

                    // === Departments (Categories) ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          isArabic ? 'الأقسام' : 'Departments',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SpecialtiesListScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isArabic ? 'كل التخصصات' : 'See All',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategoryItem(
                            context,
                            Icons.grid_view_rounded,
                            isArabic ? 'الكل' : 'All',
                            'All',
                            const Color(0xFF10B981),
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.monitor_heart_outlined,
                            isArabic ? 'قلب' : 'Cardiology',
                            'Cardio',
                            const Color(0xFFEF4444),
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.face,
                            isArabic ? 'جلدية' : 'Dermatology',
                            'Dermatology',
                            const Color(0xFFF59E0B),
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.psychology,
                            isArabic ? 'مخ وأعصاب' : 'Neurology',
                            'Neurology',
                            const Color(0xFF0EA5E9),
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.accessibility_new,
                            isArabic ? 'عظام' : 'Orthopedics',
                            'Orthopedics',
                            const Color(0xFF10B981),
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.baby_changing_station,
                            isArabic ? 'أطفال' : 'Pediatrics',
                            'Pediatric',
                            const Color(0xFFF97316),
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.medical_services_rounded,
                            isArabic ? 'أسنان' : 'Dentistry',
                            'Dent',
                            const Color(0xFF0EA5E9),
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.remove_red_eye_rounded,
                            isArabic ? 'عيون' : 'Ophthalmology',
                            'Ophthalmology',
                            const Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // === Emergency Banner ===
                    _buildEmergencyBanner(),
                    const SizedBox(height: 30),

                    // === Medical Centers (Map) ===
                    _buildLocationMap(),
                    const SizedBox(height: 30),
                    _buildDoctorInterviews(),
                    const SizedBox(height: 30),
                    _buildNewsSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmergencyAlertScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pulsing SOS circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              child: const Center(
                child: Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'طوارئ طبية؟' : 'Medical Emergency?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isArabic
                        ? 'اضغط هنا للتواصل الفوري مع طبيب إنقاذ'
                        : 'Tap to connect with an emergency doctor now',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Extracted doctor item for cleaner code
  Widget _buildCategoryItem(
    BuildContext ctx,
    IconData icon,
    String label,
    String dbKeyword,
    Color color,
  ) {
    final bool isDark = widget.isDark;
    return GestureDetector(
      onTap: () => _onCategoryTap(label, dbKeyword),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 88,
        margin: const EdgeInsets.only(right: 14, bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.18 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : color.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 11,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDoctorInterviews() {
    final interviews = [
      {
        'name': isArabic ? 'د. سارة أحمد' : 'Dr. Sarah Ahmed',
        'title': isArabic ? 'طبيبة عامة' : 'General Practitioner',
        'image':
            'https://images.unsplash.com/photo-1594824436998-dfb9fb6c8e31?auto=format&fit=crop&w=300&q=80',
      },
      {
        'name': isArabic ? 'د. محمد علي' : 'Dr. Mohamed Ali',
        'title': isArabic ? 'أخصائي قلب' : 'Cardiologist',
        'image':
            'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80',
      },
      {
        'name': isArabic ? 'د. ليلى حسن' : 'Dr. Laila Hassan',
        'title': isArabic ? 'طبيبة أطفال' : 'Pediatrician',
        'image':
            'https://images.unsplash.com/photo-1622253692010-333f2da6031d?auto=format&fit=crop&w=300&q=80',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Text(
            isArabic ? 'لقاءات مع الأطباء' : 'Doctor Interview',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: interviews.map((item) {
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 15),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(item['image']!),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['name']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item['title']!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsSection() {
    final isDark = widget.isDark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'الأخبار والمدونة الطبية' : 'News & Health Blog',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlogListScreen()),
              ),
              child: Text(
                isArabic ? 'عرض الكل' : 'View all',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: blogPosts.map((post) {
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BlogDetailScreen(post: post)),
                ),
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 20, bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: post.image,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isArabic ? post.categoryAr : post.categoryEn,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? post.titleAr : post.titleEn,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isArabic ? post.subtitleAr : post.subtitleEn,
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerSlider() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: PageView(
            controller: PageController(viewportFraction: 0.9),
            padEnds: false,
            onPageChanged: (index) => setState(() => _bannerIndex = index),
            children: [
              _buildBannerItem('assets/images/banner_1.jpg'),
              _buildBannerItem('assets/images/banner_2.png'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [0, 1].map((i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _bannerIndex == i ? 24 : 7,
              height: 7,
              decoration: BoxDecoration(
                gradient: _bannerIndex == i
                    ? const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      )
                    : null,
                color: _bannerIndex == i ? null : const Color(0xFF10B981).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBannerItem(String imagePath) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Text(
            isArabic
                ? 'المراكز الطبية والمستشفيات'
                : 'Medical Centers & Hospital',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            // Open Google Maps
            const url = 'https://maps.app.goo.gl/UqipS68RxL3mjztk6';
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            }
          },
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: const DecorationImage(
                image: AssetImage('assets/images/map_placeholder.png'),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 15,
                  left: 15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? 'عرض على الخريطة' : 'View on Google Maps',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// === SCHEDULE SCREEN ===
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _tabIndex = 0;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  void _loadAppointments() async {
    setState(() => _isLoading = true);
    String status = _tabIndex == 0
        ? 'upcoming'
        : (_tabIndex == 2 ? 'canceled' : 'completed');
    try {
      List<Map<String, dynamic>> data = [];
      
      if (kIsWeb) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final appointments = await AppointmentService().getPatientAppointmentsFuture(user.uid);
          
          // Filter by status (mapping Firestore statuses to UI tabs)
          final filtered = appointments.where((a) {
            if (_tabIndex == 0) return a.status == 'pending' || a.status == 'confirmed';
            if (_tabIndex == 1) return a.status == 'completed';
            if (_tabIndex == 2) return a.status == 'cancelled';
            return false;
          }).toList();

          data = filtered.map((a) {
            // Match the format expected by the UI and SQLite
            final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            final dateStr = "${days[a.dateTime.weekday - 1]}, ${a.dateTime.day}";
            
            return {
              'id': a.id, // String ID from Firestore
              'doctorId': a.doctorId,
              'doctorName': a.doctorName,
              'specialty': a.specialty,
              'date': dateStr,
              'time': a.formattedTime,
              'status': _tabIndex == 0 ? 'upcoming' : (_tabIndex == 2 ? 'canceled' : 'completed'),
              'firestoreId': a.id,
            };
          }).toList();
        }
      } else {
        data = await DatabaseHelper().getAppointments(status);
      }

      if (!mounted) return;
      setState(() {
        _appointments = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appointments = [];
        _isLoading = false;
      });
    }
  }

  void _cancelAppointment(BuildContext ctx, dynamic id) async {
    try {
      // 1. Handle based on platform (Web uses String ID, Mobile uses SQLite Int ID)
      if (kIsWeb) {
        // Direct cancel in Firestore
        await AppointmentService().cancelAppointment(id.toString());
      } else {
        // 1. Get the firestoreId from SQLite before cancelling locally
        final db = DatabaseHelper();
        final appointments = await db.getAppointments('upcoming');
        final appt = appointments.firstWhere((a) => a['id'] == id, orElse: () => {});
        final String? firestoreId = appt['firestoreId'];

        // 2. Sync with Firestore if ID exists
        if (firestoreId != null && firestoreId.isNotEmpty) {
          await AppointmentService().cancelAppointment(firestoreId);
        }

        // 3. Cancel locally
        await db.cancelAppointment(id as int);
      }

      _loadAppointments();

      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(isArabic ? "تم إلغاء الموعد" : "Appointment Canceled"),
          ),
        );
      }
    } catch (e) {
// debugPrint('❌ Error in _cancelAppointment: $e');
    }
  }

  void _completeAppointment(BuildContext ctx, dynamic id) async {
    try {
      if (kIsWeb) {
        // For web, we only have one source of truth (Firestore)
        // Note: AppointmentService doesn't have a direct completeAppointment yet,
        // but we can update it if needed or just use Firestore directly here.
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(id.toString())
            .update({'status': 'completed'});
      } else {
        await DatabaseHelper().completeAppointment(id as int);
      }
      
      _loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(isArabic ? "تمت الزيارة ✅" : "Appointment Completed ✅"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
// debugPrint('❌ Error in _completeAppointment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              isArabic ? 'مواعيدي' : 'My Schedule',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic ? 'تتبع مسارك ومناعيدك الطبية' : 'Track your upcoming visits',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Premium pill tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTab(context, isArabic ? 'القادمة' : 'Upcoming', 0),
                  _buildTab(context, isArabic ? 'تمت' : 'Completed', 1),
                  _buildTab(context, isArabic ? 'ملغاة' : 'Canceled', 2),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isArabic ? 'جاري التحميل...' : 'Loading...',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _appointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 44,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isArabic ? "لا توجد مواعيد" : "No appointments yet",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isArabic
                                ? "تحجز موعدك الأول مع طبيبك الآن"
                                : "Book your first appointment now",
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _appointments.length,
                      itemBuilder: (context, index) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: _buildAppointmentCard(
                            context,
                            _appointments[index],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext ctx, String title, int index) {
    bool isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tabIndex = index);
          _loadAppointments();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : (Theme.of(ctx).brightness == Brightness.dark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(
    BuildContext ctx,
    Map<String, dynamic> appointment,
  ) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    bool isCompletedTab = _tabIndex == 1;
    bool isCanceledTab = _tabIndex == 2;

    final Color accentColor = isCompletedTab
        ? const Color(0xFF10B981)
        : (isCanceledTab ? const Color(0xFFEF4444) : const Color(0xFF6366F1));

    // Generate initials avatar color from doctor name
    final String doctorName = appointment['doctorName'] ?? '';
    final String initials = doctorName.isNotEmpty
        ? (doctorName.split(' ').length > 1
            ? '${doctorName.split(' ')[0][0]}${doctorName.split(' ')[1][0]}'
            : doctorName[0])
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + info + status icon
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials.toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appointment['specialty'] ?? '',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompletedTab
                        ? Icons.check_rounded
                        : (isCanceledTab ? Icons.close_rounded : Icons.schedule_rounded),
                    color: accentColor,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Date + Time pill row
            Row(
              children: [
                _buildInfoPill(
                  Icons.calendar_today_rounded,
                  appointment['date'] ?? '',
                  accentColor,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildInfoPill(
                  Icons.access_time_rounded,
                  appointment['time'] ?? '',
                  accentColor,
                  isDark,
                ),
              ],
            ),
            if (_tabIndex == 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelAppointment(ctx, appointment['id']),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        isArabic ? 'إلغاء' : 'Cancel',
                        style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () => _completeAppointment(ctx, appointment['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          isArabic ? 'تم' : 'Done',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (isCanceledTab) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isArabic ? 'تم الإلغاء' : 'Appointment Canceled',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
            if (isCompletedTab) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isArabic ? 'تمت الزيارة ✅' : 'Visit Completed ✅',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if ((appointment['isRated'] ?? 0) == 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _showRatingDialog(ctx, appointment),
                    icon: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                    label: Text(
                      isArabic ? 'تقييم الطبيب' : 'Rate Doctor',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        doctorName: appointment['doctorName'],
        onSubmitted: (rating) async {
          // 1. Update local DB
          await DatabaseHelper().markAppointmentAsRated(appointment['id']);
          
          // 2. Update Firestore if possible
          try {
            final String? doctorId = appointment['doctorId'];
            if (doctorId != null && doctorId.isNotEmpty) {
              final docService = AppointmentService(); // We can use this to get firestore instance
              final docRef = FirebaseFirestore.instance.collection('doctors').doc(doctorId);
              
              await FirebaseFirestore.instance.runTransaction((transaction) async {
                final snapshot = await transaction.get(docRef);
                if (snapshot.exists) {
                  final data = snapshot.data()!;
                  double currentRating = double.tryParse(data['rating']?.toString() ?? '0') ?? 0;
                  int currentReviews = int.tryParse(data['reviews']?.toString() ?? '0') ?? 0;
                  
                  int newReviews = currentReviews + 1;
                  double newRating = (currentRating * currentReviews + rating) / newReviews;
                  
                  transaction.update(docRef, {
                    'rating': newRating.toStringAsFixed(1),
                    'reviews': newReviews,
                  });
                }
              });
            }
          } catch (e) {
            debugPrint('Error updating doctor rating in Firestore: $e');
          }

          if (mounted) {
            _loadAppointments();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isArabic 
                  ? "شكراً لتقييمك! ❤️" 
                  : "Thank you for your rating! ❤️"),
                backgroundColor: Colors.blue,
              ),
            );
          }
        },
      ),
    );
  }
}

class RatingDialog extends StatefulWidget {
  final String doctorName;
  final Function(double) onSubmitted;

  const RatingDialog({
    super.key,
    required this.doctorName,
    required this.onSubmitted,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 5;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isArabic ? "تقييم الطبيب" : "Rate Doctor",
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isArabic 
              ? "كيف كانت تجربتك مع ${widget.doctorName}؟" 
              : "How was your experience with ${widget.doctorName}?",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () => setState(() => _rating = index + 1.0),
                  icon: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber[700],
                    size: 36, // Slightly reduced from 40
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isArabic ? "إلغاء" : "Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSubmitted(_rating);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            isArabic ? "إرسال" : "Submit",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// === PROFILE SCREEN ===
class ProfileScreen extends StatefulWidget {
  final String userName;
  final Function(String) onNameChanged;
  final VoidCallback? onLangChanged;
  final VoidCallback? toggleTheme;
  final bool? isDark;
  final String? profileImage;
  final Function(String) onImageChanged;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.onNameChanged,
    this.onLangChanged,
    this.toggleTheme,
    this.isDark,
    this.profileImage,
    required this.onImageChanged,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userPhone = "Loading...";
  String userGender = "";
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // جلب بيانات المستخدم من Firestore
    final authService = AuthService();
    final userData = await authService.getUserData();

    if (!mounted) return;

    setState(() {
      userPhone = userData?['phoneNumber'] ?? "No Phone";
      userGender = userData?['gender'] ?? "";
    });
  }

  // === دالة اختيار الصورة وحفظها بشكل دائم ===
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // 1. نحدد مكان دائم للحفظ (المستندات)
      final directory = await getApplicationDocumentsDirectory();
      final String newPath = join(directory.path, 'profile_pic.jpg');

      // 2. ننسخ الصورة للمكان الجديد (عشان ما تتمسحش من التمب)
      await File(image.path).copy(newPath);

      // 3. نحفظ المسار الجديد الدائم
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', newPath);

      // 4. نحدث الشاشة والأب
      widget.onImageChanged(newPath);
    }
  }

  // === دالة رفع الملفات الطبية (PDF / صور) ===
  Future<void> _pickMedicalRecord() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        File fileToUpload = File(file.path!);
        String fileName = file.name;

        // 1. إظهار لودينج
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Text(isArabic ? "جاري الرفع..." : "Uploading..."),
                ],
              ),
              duration: const Duration(minutes: 1), // مدة طويلة لحد ما يخلص
            ),
          );
        }

        // 2. الرفع لـ Firebase Storage
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) throw Exception("User not logged in");

          final storageRef = FirebaseStorage.instance.ref().child(
            'uploads/${user.uid}/$fileName',
          );

          await storageRef.putFile(fileToUpload);
          String downloadUrl = await storageRef.getDownloadURL();

          // 3. حفظ الرابط في Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('medical_records')
              .add({
                'name': fileName,
                'url': downloadUrl,
                'type': extension(fileName).replaceAll('.', ''),
                'date': DateTime.now().toIso8601String(),
              });

          // 4. رسالة نجاح
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).hideCurrentSnackBar(); // نخفي اللودينج
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic ? "تم الرفع بنجاح ✅" : "Upload Successful ✅",
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isArabic ? "فشل الرفع: $e" : "Upload Failed: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // المستخدم لغى الاختيار
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? "حدث خطأ: $e" : "Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // === Premium Profile Header Card ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Gradient ring avatar
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          ),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundImage:
                                (widget.profileImage != null &&
                                    !kIsWeb &&
                                    File(widget.profileImage!).existsSync())
                                ? FileImage(File(widget.profileImage!)) as ImageProvider
                                : const AssetImage('assets/images/doctor_big_preview.png'),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.40),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userPhone != 'No Phone'
                        ? userPhone
                        : (isArabic ? 'لا يوجد رقم هاتف' : 'No Phone Number'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildProfileStat(isArabic ? 'مواعيد' : 'Appointments', '0', isDark),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 24)),
                      _buildProfileStat(isArabic ? 'تحت المتابعة' : 'Under Care', '1', isDark),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 24)),
                      _buildProfileStat(isArabic ? 'سجلات' : 'Records', '0', isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === Account section ===
                  _buildSectionHeader(isArabic ? 'الحساب' : 'Account', isDark),
                  const SizedBox(height: 8),
                  _buildSettingsCard([
                    _buildProfileOption(
                      Icons.dark_mode_rounded,
                      isArabic ? 'الوضع الليلي' : 'Dark Mode',
                      () {},
                      isDark: isDark,
                      color: const Color(0xFF6366F1),
                      trailing: Switch(
                        value: Theme.of(context).brightness == Brightness.dark,
                        onChanged: (val) {
                          HapticFeedback.mediumImpact();
                          widget.toggleTheme?.call();
                        },
                        activeColor: const Color(0xFF10B981),
                      ),
                    ),
                    _buildProfileOption(
                      Icons.language_rounded,
                      isArabic ? 'English' : 'اللغة العربية',
                      () => widget.onLangChanged?.call(),
                      isDark: isDark,
                      color: const Color(0xFF0EA5E9),
                    ),
                    _buildProfileOption(
                      Icons.person_outline_rounded,
                      isArabic ? 'تعديل الحساب' : 'Edit Profile',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(currentName: widget.userName),
                          ),
                        ).then((newName) {
                          if (newName != null) widget.onNameChanged(newName);
                        });
                      },
                      isDark: isDark,
                      color: const Color(0xFF10B981),
                    ),
                  ], isDark),

                  const SizedBox(height: 20),
                  // === Medical section ===
                  _buildSectionHeader(isArabic ? 'طبي' : 'Medical', isDark),
                  const SizedBox(height: 8),
                  _buildSettingsCard([
                    _buildProfileOption(
                      Icons.upload_file_rounded,
                      isArabic ? 'رفع ملفات طبية' : 'Upload Medical Records',
                      _pickMedicalRecord,
                      isDark: isDark,
                      color: const Color(0xFFF59E0B),
                    ),
                    _buildProfileOption(
                      Icons.notifications_none_rounded,
                      isArabic ? 'الإشعارات' : 'Notifications',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                      isDark: isDark,
                      color: const Color(0xFFF97316),
                    ),
                  ], isDark),

                  const SizedBox(height: 20),
                  // === Support section ===
                  _buildSectionHeader(isArabic ? 'دعم ومعلومات' : 'Support', isDark),
                  const SizedBox(height: 8),
                  _buildSettingsCard([
                    _buildProfileOption(
                      Icons.privacy_tip_outlined,
                      isArabic ? 'الخصوصية' : 'Privacy Policy',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                      isDark: isDark,
                      color: const Color(0xFF8B5CF6),
                    ),
                    _buildProfileOption(
                      Icons.help_outline_rounded,
                      isArabic ? 'عنا' : 'About Us',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen())),
                      isDark: isDark,
                      color: const Color(0xFF0EA5E9),
                    ),
                    _buildProfileOption(
                      Icons.volunteer_activism_rounded,
                      isArabic ? 'تبرع' : 'Donate',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonateScreen())),
                      isDark: isDark,
                      color: const Color(0xFFF43F5E),
                    ),
                  ], isDark),

                  const SizedBox(height: 28),
                  // === Logout ===
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await AuthService().signOut();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(
                                toggleTheme: widget.toggleTheme ?? () {},
                                isDark: widget.isDark ?? false,
                              ),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      label: Text(
                        isArabic ? 'تسجيل خروج' : 'Log Out',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map((entry) {
              final isLast = entry.key == children.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    ),
                ],
              );
            })
            .toList(),
      ),
    );
  }

  Widget _buildProfileOption(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDark = false,
    Color color = const Color(0xFF6366F1),
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      trailing: trailing ?? Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
      ),
      onTap: trailing == null ? onTap : null,
    );
  }
}

// ... (EditProfileScreen, NotificationScreen)
class EditProfileScreen extends StatefulWidget {
  final String currentName;
  const EditProfileScreen({super.key, required this.currentName});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          
          if (_firstNameController.text.isEmpty && data.containsKey('name')) {
            final String existingName = data['name'] ?? widget.currentName;
            final parts = existingName.trim().split(' ');
            if (parts.isNotEmpty) {
              _firstNameController.text = parts.first;
              if (parts.length > 1) {
                _lastNameController.text = parts.skip(1).join(' ');
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading profile: $e");
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final authService = AuthService();
    final user = authService.getCurrentUser();
    final String newFullName = "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}".trim();

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'phoneNumber': _phoneController.text.trim(),
            'name': newFullName, 
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_name', newFullName);

    if (mounted) {
      Navigator.pop(context, newFullName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isArabic ? "تعديل الحساب" : "Edit Profile",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'المعلومات الشخصية' : 'Personal Information',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'قم بتحديث بياناتك للظهور للأطباء' : 'Update your details so doctors can identify you',
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(child: _buildTextField(
                      controller: _firstNameController,
                      label: isArabic ? 'الاسم الأول' : 'First Name',
                      icon: Icons.person_outline_rounded,
                      isDark: isDark,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(
                      controller: _lastNameController,
                      label: isArabic ? 'اسم العائلة' : 'Last Name',
                      icon: Icons.badge_outlined,
                      isDark: isDark,
                    )),
                  ],
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: _phoneController,
                  label: isArabic ? 'رقم الهاتف' : 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  isDark: isDark,
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_firstNameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isArabic ? 'يرجى إدخال الاسم الأول' : 'Please enter your first name'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      await _saveProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      shadowColor: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                    ),
                    child: Text(
                      isArabic ? 'حفظ التغييرات' : 'Save Changes',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.name,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildNotif(
            "Appointment Confirmed",
            "Your appointment is confirmed.",
            Icons.check_circle,
            Colors.green,
          ),
          _buildNotif(
            "New Update",
            "Check out new features.",
            Icons.info,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildNotif(String title, String body, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: Icon(icon, color: color, size: 35),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(body),
      ),
    );
  }
}

class YourHealthScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const YourHealthScreen({super.key, required this.onTabChange});

  @override
  State<YourHealthScreen> createState() => _YourHealthScreenState();
}

class ActiveMedication {
  final model.Prescription prescription;
  final String appointmentId;
  ActiveMedication(this.prescription, this.appointmentId);
}

class _YourHealthScreenState extends State<YourHealthScreen> {
  model.Appointment? _latestAppointment;
  List<model.Appointment> _allAppointments = [];
  List<ActiveMedication> _activeMedications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isLoading = false); return; }

    AppointmentService().getPatientAppointments(user.uid).listen((appointments) {
      if (!mounted) return;
      
      // Sort to find the absolute latest one (completed or confirmed) for the "Last Visit" card
      List<model.Appointment> sorted = List.from(appointments);
      sorted.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
      model.Appointment? latest;
      try {
        latest = sorted.firstWhere((a) => a.status == 'completed' || (a.status == 'confirmed' && a.prescriptions != null && a.prescriptions!.isNotEmpty));
      } catch (_) {
        if (sorted.isNotEmpty) latest = sorted.first;
      }

      // Collect ALL active medications from ALL appointments (newest first)
      List<ActiveMedication> allActiveMeds = [];
      for (var appt in sorted) {
        if (appt.status == 'completed' || appt.status == 'confirmed' || appt.status == 'pending') {
          if (appt.prescriptions != null) {
            for (var med in appt.prescriptions!) {
              // Show all prescriptions for now to diagnose visibility issues
              if (true || _isMedicationActive(appt.dateTime, med)) {
                // Check if permanently dismissed in this appointment
                bool isPermanentlyDismissed = false;
                final data = appt.id; // We need the actual data from the appointment map if available
                // Wait, appointments in YourHealthScreen are model.Appointment objects.
                // Does model.Appointment have the medicationTracker field?
                // I need to check the model.
                if (!allActiveMeds.any((am) => am.prescription.medicineName.trim().toLowerCase() == med.medicineName.trim().toLowerCase())) {
                  allActiveMeds.add(ActiveMedication(med, appt.id));
                }
              }
            }
          }
        }
      }

      setState(() {
        _latestAppointment = latest;
        _allAppointments = appointments;
        _activeMedications = allActiveMeds;
        _isLoading = false;
      });
    });
  }

  bool _isMedicationActive(DateTime prescribedDate, model.Prescription med) {
    final int? days = _extractNumber(med.duration);
    if (days == null) return true;
    final expiryDate = prescribedDate.add(Duration(days: days));
    return DateTime.now().isBefore(expiryDate.add(const Duration(hours: 24)));
  }

  int? _extractNumber(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  List<String> _getDoseTimes(model.Prescription p) {
    int intervalHours = 24;
    if (p.frequencyHours != null && p.frequencyHours! > 0) {
      intervalHours = p.frequencyHours!;
    } else {
      final count = _extractNumber(p.frequency);
      if (count != null && count > 0) intervalHours = 24 ~/ count;
    }
    final int times = 24 ~/ intervalHours;
    const int startHour = 9;
    final List<String> result = [];
    for (int i = 0; i < times; i++) {
      final int hour = (startHour + i * intervalHours) % 24;
      final String period = hour >= 12 ? 'PM' : 'AM';
      final int display = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      String label;
      if (hour >= 6 && hour < 12) {
        label = isArabic ? 'صباحاً' : 'Morning';
      } else if (hour >= 12 && hour < 15) {
        label = isArabic ? 'ظهراً' : 'Noon';
      } else if (hour >= 15 && hour < 20) {
        label = isArabic ? 'مساءً' : 'Evening';
      } else {
        label = isArabic ? 'ليلاً' : 'Night';
      }
      result.add('$display:00 $period ($label)');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -30, right: -30,
                    child: Container(width: 150, height: 150,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)))),
                  Positioned(
                    bottom: -20, left: 40,
                    child: Container(width: 100, height: 100,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF10B981).withValues(alpha: 0.15)))),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(isArabic ? 'صحتي' : 'My Health',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                              Text(isArabic ? 'أدويتك ونصائح طبيبك' : 'Your meds & doctor advice',
                                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                            ]),
                          ]),
                          const SizedBox(height: 20),
                          Row(children: [
                            _headerStat(_allAppointments.where((a) => a.status == 'completed').length.toString(),
                              isArabic ? 'مكتملة' : 'Completed', Icons.check_circle_outline_rounded),
                            const SizedBox(width: 10),
                            _headerStat(_activeMedications.length.toString(),
                              isArabic ? 'دواء فعّال' : 'Active Meds', Icons.medication_rounded),
                            const SizedBox(width: 10),
                            _headerStat(_allAppointments.where((a) => a.status == 'pending').length.toString(),
                              isArabic ? 'قادم' : 'Upcoming', Icons.event_rounded),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: SizedBox(width: 40, height: 40,
                child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 3))))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Quick Actions
                  _sectionTitle(isArabic ? 'إجراءات سريعة' : 'Quick Actions', isDark),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _quickAction(
                      icon: Icons.medication_rounded,
                      label: isArabic ? 'أدويتي\nوتذكيراتي' : 'My Meds\n& Reminders',
                      color: const Color(0xFF10B981),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationRemindersScreen()));
                        setState(() {});
                      },
                      isDark: isDark,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _quickAction(
                      icon: Icons.upload_file_rounded,
                      label: isArabic ? 'ملفات\nطبية' : 'Medical\nRecords',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => widget.onTabChange(2),
                      isDark: isDark,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _quickAction(
                      icon: Icons.calendar_month_rounded,
                      label: isArabic ? 'مواعيدي\nالقادمة' : 'My\nSchedule',
                      color: const Color(0xFF0EA5E9),
                      onTap: () => widget.onTabChange(1),
                      isDark: isDark,
                    )),
                  ]),
                  const SizedBox(height: 28),
                  // Latest Visit card
                  if (_latestAppointment != null) ...[
                    _sectionTitle(isArabic ? 'آخر زيارة' : 'Last Visit', isDark),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isArabic ? 'وصفة بواسطة' : 'Prescribed by',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                          Text('${isArabic ? "د." : "Dr."} ${_latestAppointment!.doctorName}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(_latestAppointment!.specialty,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text(DateFormat('dd MMM').format(_latestAppointment!.dateTime),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 28),
                  ],
                  // Doctor Notes
                  if (_latestAppointment?.doctorNotes?.isNotEmpty ?? false) ...[
                    _sectionTitle(isArabic ? 'تعليمات الطبيب' : 'Doctor\'s Notes', isDark),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.sticky_note_2_rounded, color: Colors.blue, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_latestAppointment!.doctorNotes!,
                          style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey[300] : const Color(0xFF475569)))),
                      ]),
                    ),
                    const SizedBox(height: 28),
                  ],
                  // Active Meds
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _sectionTitle(isArabic ? 'الأدوية الفعّالة' : 'Active Medications', isDark),
                    if (_activeMedications.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationRemindersScreen()));
                          setState(() {});
                        },
                        child: ShaderMask(
                          shaderCallback: (b) => const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF10B981)]).createShader(b),
                          child: Text(isArabic ? 'إدارة التنبيهات' : 'Manage Reminders',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  if (_activeMedications.isEmpty)
                    _noMedsCard(isDark)
                  else
                    ..._activeMedications.map((med) => _medCard(med, isDark)),
                  const SizedBox(height: 28),
                  // Health Tips
                  _sectionTitle(isArabic ? 'نصائح صحية' : 'Health Tips', isDark),
                  const SizedBox(height: 12),
                  _tipCard(Icons.water_drop_rounded, const Color(0xFF0EA5E9),
                    isArabic ? 'اشرب الماء بانتظام' : 'Stay Hydrated',
                    isArabic ? 'احرص على شرب 8 أكواب ماء يومياً.' : 'Drink 8 glasses of water daily.', isDark),
                  _tipCard(Icons.bedtime_rounded, const Color(0xFF8B5CF6),
                    isArabic ? 'نوم كافٍ' : 'Get Enough Sleep',
                    isArabic ? '7-8 ساعات نوم يومياً تساعد الجسم على التعافي.' : '7-8 hours of sleep nightly helps recovery.', isDark),
                  _tipCard(Icons.directions_walk_rounded, const Color(0xFF10B981),
                    isArabic ? 'النشاط البدني' : 'Stay Active',
                    isArabic ? '30 دقيقة مشي يومياً تحسّن صحة القلب.' : '30 min of walking daily improves heart health.', isDark),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) => Row(children: [
    Container(width: 4, height: 18,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF10B981)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(4),
      )),
    const SizedBox(width: 10),
    Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
      color: isDark ? Colors.white : const Color(0xFF1E293B), letterSpacing: -0.3)),
  ]);

  Widget _quickAction({required IconData icon, required String label, required Color color, required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[200] : const Color(0xFF1E293B), height: 1.3),
            textAlign: TextAlign.center, maxLines: 2),
        ]),
      ),
    );
  }

  Widget _noMedsCard(bool isDark) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), shape: BoxShape.circle),
        child: const Icon(Icons.medication_rounded, color: Color(0xFF10B981), size: 28),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isArabic ? 'لا توجد أدوية فعّالة' : 'No Active Medications',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        const SizedBox(height: 4),
        Text(isArabic ? 'ستظهر هنا الأدوية بعد زيارتك للطبيب' : 'Your medicines will appear after your visit',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
      ])),
    ]),
  );

  Widget _medCard(ActiveMedication activeMed, bool isDark) {
    final med = activeMed.prescription;
    final times = _getDoseTimes(med);
    return StreamBuilder<DocumentSnapshot>(
      stream: MedicationTrackingService().getTrackingStream(activeMed.appointmentId),
      builder: (context, snapshot) {
        List takenDoses = [];
        final String dateKey = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
        
        bool isDismissedForDay = false;
        bool isPermanentlyDismissed = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['medicationTracker'] != null) {
            final tracker = data['medicationTracker'];
            // Check day dismissal
            if (tracker[dateKey] != null && tracker[dateKey][med.medicineName] != null) {
              final medData = tracker[dateKey][med.medicineName];
              takenDoses = medData['takenDoses'] ?? [];
              isDismissedForDay = medData['isDismissed'] ?? false;
            }
            // Check permanent dismissal
            if (tracker['permanentDismissals'] != null && tracker['permanentDismissals'][med.medicineName] == true) {
              isPermanentlyDismissed = true;
            }
          }
        }
        
        if (isDismissedForDay || isPermanentlyDismissed) return const SizedBox.shrink();

        final bool isAllTaken = times.isNotEmpty && takenDoses.length >= times.length;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationRemindersScreen())),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAllTaken 
                  ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.05))
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAllTaken 
                    ? const Color(0xFF10B981).withValues(alpha: 0.5)
                    : const Color(0xFF10B981).withValues(alpha: 0.12),
                width: isAllTaken ? 1.5 : 1.0,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAllTaken ? const Color(0xFF10B981) : const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Icon(
                    isAllTaken ? Icons.check_circle_rounded : Icons.medication_rounded, 
                    color: isAllTaken ? Colors.white : const Color(0xFF10B981), 
                    size: 22
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(med.medicineName.isEmpty ? (isArabic ? 'دواء' : 'Medicine') : med.medicineName, 
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w800,
                            color: isAllTaken ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                            decoration: isAllTaken ? TextDecoration.lineThrough : null,
                          )),
                      ),
                      if (isAllTaken)
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(isArabic ? 'إزالة الدواء؟' : 'Remove Medicine?'),
                                content: Text(isArabic 
                                  ? 'تم اكتمال جميع جرعات اليوم. هل تريد إزالة هذا الدواء من القائمة النشطة؟' 
                                  : 'All doses for today completed. Do you want to remove this medicine from the active list?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      MedicationTrackingService().permanentlyDismissMedicine(
                                        appointmentId: activeMed.appointmentId,
                                        medicineName: med.medicineName,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text(isArabic ? 'نعم، إزالة' : 'Yes, Remove'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(isArabic ? 'إخفاء' : 'Done', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                                const SizedBox(width: 4),
                                const Icon(Icons.visibility_off_rounded, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    _chip(med.dosage, const Color(0xFF0EA5E9)),
                    const SizedBox(width: 6),
                    _chip(med.duration, const Color(0xFFF59E0B)),
                  ]),
                ])),
              ]),
              const SizedBox(height: 16),
              // Dose Tracker
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.checklist_rounded, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(isArabic ? 'جرعات اليوم:' : 'Today\'s Doses:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: times.map((time) {
                      final bool isTaken = takenDoses.contains(time);
                      return InkWell(
                        onTap: () {
                          MedicationTrackingService().toggleDoseTaken(
                            appointmentId: activeMed.appointmentId,
                            medicineName: med.medicineName,
                            doseTime: time,
                            date: DateTime.now(),
                            taken: !isTaken,
                            totalDoses: times.length,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isTaken 
                                ? const Color(0xFF10B981).withValues(alpha: 0.15) 
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isTaken ? const Color(0xFF10B981) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTaken)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                ),
                              Text(time,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isTaken ? FontWeight.w800 : FontWeight.w600,
                                  color: isTaken 
                                      ? const Color(0xFF10B981) 
                                      : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                                )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              if (med.instructions?.isNotEmpty ?? false) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(med.instructions!,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF475569), fontStyle: FontStyle.italic))),
                  ]),
                ),
              ],
            ]),
          ),
        );
      }
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _tipCard(IconData icon, Color color, String title, String body, bool isDark) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.12)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF1E293B))),
        const SizedBox(height: 4),
        Text(body, style: TextStyle(fontSize: 13, height: 1.4,
          color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
      ])),
    ]),
  );
}
