// ignore_for_file: deprecated_member_use, unused_field

import 'dart:io';
import 'package:flutter/material.dart';
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
import '../models/doctor_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sub_screens.dart';
import 'auth/login_screen.dart';

bool isArabic = false;

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
    if (path != null && !File(path).existsSync()) {
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
      ),
      ScheduleScreen(key: _scheduleKey),
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
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: pages[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(.1)),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15.0,
                vertical: 8,
              ),
              child: GNav(
                rippleColor: Colors.grey[300]!,
                hoverColor: Colors.grey[100]!,
                gap: 8,
                activeColor: Colors.white,
                iconSize: 24,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                duration: const Duration(milliseconds: 400),
                tabBackgroundColor: Colors.blue,
                color: Colors.grey,
                tabs: [
                  GButton(
                    icon: Icons.home_rounded,
                    text: isArabic ? 'الرئيسية' : 'Home',
                  ),
                  GButton(
                    icon: Icons.calendar_month_rounded,
                    text: isArabic ? 'مواعيدي' : 'Schedule',
                  ),
                  GButton(
                    icon: Icons.person_rounded,
                    text: isArabic ? 'حسابي' : 'Profile',
                  ),
                ],
                selectedIndex: _currentIndex,
                onTabChange: (index) {
                  // Haptic feedback للتفاعل
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
    );
  }
}

// === HOME SCREEN ===
class HomeScreen extends StatefulWidget {
  final String userName;
  final ScrollController? scrollController;
  final String? profileImage;
  const HomeScreen({
    super.key,
    required this.userName,
    this.scrollController,
    this.profileImage,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Doctor> _doctors = [];
  bool _isLoading = true;
  final String _selectedCategory = 'All';
  Timer? _debounce;
  int _bannerIndex = 0;
  @override
  void initState() {
    super.initState();
    _loadDoctors('All');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadDoctors(String category) async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper().getDoctors(category: category);
      setState(() {
        _doctors = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _runFilter(query);
    });
  }

  Future<void> _runFilter(String keyword) async {
    setState(() => _isLoading = true);
    if (keyword.isEmpty) {
      await _loadDoctors('All');
    } else {
      final results = await DatabaseHelper().searchDoctors(keyword);
      setState(() {
        _doctors = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _loadDoctors(_selectedCategory),
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'مرحباً،' : 'Hello,',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color?.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          radius: 25,
                          backgroundImage:
                              (widget.profileImage != null &&
                                  File(widget.profileImage!).existsSync())
                              ? FileImage(File(widget.profileImage!))
                                    as ImageProvider
                              : const AssetImage(
                                  'assets/images/doctor_big_preview.png',
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Search Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? 'ابحث عن دكتور...'
                              : 'Search by: Doctor, Specialty, Clinic',
                          border: InputBorder.none,
                          icon: const Icon(Icons.search, color: Colors.blue),
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
                      children: [
                        Text(
                          isArabic ? 'الأقسام' : 'Departments',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isArabic ? 'كل التخصصات' : 'All Specialities',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
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
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.monitor_heart_outlined,
                            isArabic ? 'قلب' : 'Cardiology',
                            'Cardio',
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.face,
                            isArabic ? 'جلدية' : 'Dermatology',
                            'Dermatology',
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.psychology,
                            isArabic ? 'مخ وأعصاب' : 'Neurology',
                            'Neurology',
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.accessibility_new,
                            isArabic ? 'عظام' : 'Orthopedics',
                            'Orthopedics',
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.baby_changing_station,
                            isArabic ? 'أطفال' : 'Pediatrics',
                            'Pediatric',
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.medical_services_rounded,
                            isArabic ? 'أسنان' : 'Dentistry',
                            'Dent',
                          ),
                          _buildCategoryItem(
                            context,
                            Icons.remove_red_eye_rounded,
                            isArabic ? 'عيون' : 'Ophthalmology',
                            'Ophthalmology',
                          ),
                        ],
                      ),
                    ),
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

  // Extracted doctor item for cleaner code
  Widget _buildCategoryItem(
    BuildContext ctx,
    IconData icon,
    String label,
    String dbKeyword,
  ) {
    return GestureDetector(
      onTap: () => _onCategoryTap(label, dbKeyword),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 100, // Fixed width for square look
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white, // Always white bg like example
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.blue,
              size: 30, // Larger icon
            ),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 12,
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
            'https://images.unsplash.com/photo-1559839734-2b71ea86b48e?auto=format&fit=crop&w=300&q=80',
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
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
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
    final news = [
      {
        'title': isArabic
            ? 'حافظ على صحتك في الشتاء'
            : 'STAY FLU-FREE THIS SEASON',
        'subtitle': isArabic
            ? 'نصائح هامة لتجنب الانفلونزا'
            : 'Influenza, commonly known as the flu...',
        'image':
            'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=300&q=80',
      },
      {
        'title': isArabic
            ? 'الاستعداد للعلاج الكيميائي'
            : 'Preparation For Chemotherapy',
        'subtitle': isArabic
            ? 'كل ما تحتاج معرفته عن العلاج'
            : 'Chemotherapy affects everyone differently...',
        'image':
            'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=300&q=80',
      },
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'الأخبار والمدونة الطبية' : 'News & Health Blog',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {},
              child: Text(isArabic ? 'عرض الكل' : 'View all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: news.map((item) {
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: item['image']!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item['subtitle']!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [0, 1].map((i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _bannerIndex == i ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _bannerIndex == i
                    ? Colors.blue
                    : Colors.blue.withOpacity(0.3),
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
            color: Colors.black.withOpacity(0.1),
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
                  color: Colors.black.withOpacity(0.1),
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
                    color: Colors.black.withOpacity(0.1),
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
                          color: Colors.black.withOpacity(0.2),
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
                          color: Colors.black.withOpacity(0.1),
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
      final data = await DatabaseHelper().getAppointments(status);
      setState(() {
        _appointments = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _appointments = [];
        _isLoading = false;
      });
    }
  }

  void _cancelAppointment(BuildContext ctx, int id) async {
    await DatabaseHelper().cancelAppointment(id);
    _loadAppointments();
    if (mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(isArabic ? "تم إلغاء الموعد" : "Appointment Canceled"),
        ),
      );
    }
  }

  void _completeAppointment(BuildContext ctx, int id) async {
    await DatabaseHelper().completeAppointment(id);
    _loadAppointments();
    if (mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(isArabic ? "تمت الزيارة ✅" : "Appointment Completed ✅"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'مواعيدي' : 'My Schedule',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
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
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            isArabic ? 'جاري التحميل...' : 'Loading...',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color?.withOpacity(0.6),
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
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isArabic ? "لا توجد مواعيد" : "No appointments",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isArabic
                                ? "احجز موعدك الأول الآن"
                                : "Book your first appointment now",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color?.withOpacity(0.6),
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : (Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[700]),
                fontWeight: FontWeight.bold,
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
    bool isCompletedTab = _tabIndex == 1;
    bool isCanceledTab = _tabIndex == 2;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(ctx).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['doctorName'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(ctx).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      appointment['specialty'],
                      style: TextStyle(
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isCompletedTab
                    ? Icons.check_circle
                    : (isCanceledTab ? Icons.cancel : Icons.access_time_filled),
                color: isCompletedTab
                    ? Colors.green
                    : (isCanceledTab ? Colors.red : Colors.blue),
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(ctx).brightness == Brightness.dark
                  ? (isCompletedTab
                        ? Colors.green.withOpacity(0.2)
                        : (isCanceledTab
                              ? Colors.red.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.2)))
                  : (isCompletedTab
                        ? Colors.green[50]
                        : (isCanceledTab ? Colors.red[50] : Colors.blue[50])),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isCompletedTab
                      ? Colors.green
                      : (isCanceledTab ? Colors.red : Colors.blue),
                ),
                const SizedBox(width: 5),
                Text(
                  appointment['date'],
                  style: TextStyle(
                    color: isCompletedTab
                        ? Colors.green
                        : (isCanceledTab ? Colors.red : Colors.blue),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isCompletedTab
                      ? Colors.green
                      : (isCanceledTab ? Colors.red : Colors.blue),
                ),
                const SizedBox(width: 5),
                Text(
                  appointment['time'],
                  style: TextStyle(
                    color: isCompletedTab
                        ? Colors.green
                        : (isCanceledTab ? Colors.red : Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          if (_tabIndex == 0)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _cancelAppointment(ctx, appointment['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.red.withOpacity(0.2)
                          : Colors.red[50],
                      elevation: 0,
                    ),
                    child: Text(
                      isArabic ? 'إلغاء' : 'Cancel',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _completeAppointment(ctx, appointment['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      elevation: 0,
                    ),
                    child: Text(
                      isArabic ? 'تم' : 'Completed',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          if (isCanceledTab)
            Center(
              child: Text(
                isArabic ? "ملغي" : "Canceled",
                style: TextStyle(
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (isCompletedTab)
            Center(
              child: Text(
                isArabic ? "تمت الزيارة ✅" : "Visit Done ✅",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
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
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // === الصورة (محمية من الحذف) ===
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    // بنستخدم الصورة اللي جاية من الأب (widget.profileImage)
                    // وبنتأكد إن الملف موجود فعلاً File(...).existsSync()
                    backgroundImage:
                        (widget.profileImage != null &&
                            File(widget.profileImage!).existsSync())
                        ? FileImage(File(widget.profileImage!)) as ImageProvider
                        : const AssetImage(
                            'assets/images/doctor_big_preview.png',
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.userName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                userPhone != "No Phone"
                    ? userPhone
                    : (isArabic ? "لا يوجد رقم هاتف" : "No Phone Number"),
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 30),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dark_mode, color: Colors.blue),
                ),
                title: Text(
                  isArabic ? "الوضع الليلي" : "Dark Mode",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Switch(
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (val) {
                    HapticFeedback.mediumImpact();
                    widget.toggleTheme?.call();
                  },
                ),
              ),

              _buildProfileOption(
                Icons.language,
                isArabic ? "English" : "اللغة العربية",
                () {
                  widget.onLangChanged?.call();
                },
              ),
              _buildProfileOption(
                Icons.person_outline,
                isArabic ? "تعديل الحساب" : "Edit Profile",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditProfileScreen(currentName: widget.userName),
                    ),
                  ).then((newName) {
                    if (newName != null) widget.onNameChanged(newName);
                  });
                },
              ),
              _buildProfileOption(
                Icons.upload_file,
                isArabic ? "رفع ملفات طبية / أشعة" : "Upload Medical Records",
                _pickMedicalRecord,
              ),
              _buildProfileOption(
                Icons.notifications_none,
                isArabic ? "الإشعارات" : "Notifications",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              _buildProfileOption(
                Icons.privacy_tip_outlined,
                isArabic ? "الخصوصية" : "Privacy Policy",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              _buildProfileOption(
                Icons.help_outline,
                isArabic ? "عنا" : "About Us",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutUsScreen(),
                    ),
                  );
                },
              ),
              _buildProfileOption(
                Icons.volunteer_activism,
                isArabic ? "تبرع" : "Donate",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DonateScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    // تسجيل الخروج من Firebase
                    await AuthService().signOut();

                    // مسح البيانات المحلية (اختياري)
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();

                    // الانتقال لشاشة تسجيل الدخول
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    elevation: 0,
                  ),
                  child: Text(
                    isArabic ? 'تسجيل خروج' : 'Log Out',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
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
  late TextEditingController _nameController;
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  // حفظ الاسم في Firestore
                  final authService = AuthService();
                  final user = authService.getCurrentUser();
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                          'name': _nameController.text,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                  }

                  // حفظ في SharedPreferences أيضاً (للتوافق مع الكود القديم)
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('saved_name', _nameController.text);

                  Navigator.pop(context, _nameController.text);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ],
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
