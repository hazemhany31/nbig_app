import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_helper.dart';
import '../services/hybrid_doctor_service.dart';
import '../models/doctor_model.dart'; // Added import
import '../services/notification_service.dart'; // عشان إشعار الحجز
import '../language_config.dart';
import 'chat/chat_screen.dart' as firebase_chat;
import '../models/chat.dart';

import '../services/chat_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart' as model;
import '../services/appointment_service.dart';

// === 1. DOCTOR DETAILS SCREEN (HERO + DB FAVORITES) ===
class DoctorDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const DoctorDetailsScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _bookAppointment() {
    final docModel = Doctor.fromMap(widget.doctor);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentScreen(
          doctorName: docModel.name,
          specialty: isArabic ? docModel.specialtyAr : docModel.specialty,
          doctorId: docModel.id,
          doctorUserId: docModel.userId, // Added userId
          price: docModel.price.isEmpty ? '150' : docModel.price,
          schedule: docModel.schedule,
        ),
      ),
    );
  }

  Widget _buildDoctorImage(String imagePath, String gender) {
    if (imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (c, o, s) => _fallbackIcon(gender),
      );
    }
    return _fallbackIcon(gender);
  }

  Widget _fallbackIcon(String gender) {
    IconData icon = gender.toLowerCase() == 'female' || gender == 'أنثى'
        ? Icons.face_3_rounded
        : Icons.face_rounded;
    return Icon(icon, size: 60, color: const Color(0xFF0EA5E9));
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doctor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline =
        (doc['isOnline'] ?? false) == true &&
        (doc['lastSeen'] == null ||
            DateTime.now().difference(doc['lastSeen'] as DateTime).inMinutes <
                5);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Parallax Immersive Header
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                stretch: true,
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        (doc['isFavorite'] ?? false)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: (doc['isFavorite'] ?? false)
                            ? const Color(0xFFF43F5E)
                            : Colors.white,
                        size: 22,
                      ),
                    ),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Header Background Pattern / Gradient
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF064E3B), Color(0xFF10B981)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),

                      // Doctor Information Overlay
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            // Gold Ring Avatar
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFBBF24),
                                        Color(0xFFF59E0B),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Hero(
                                    tag: doc['id'] ?? doc['name'],
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        child: _buildDoctorImage(
                                          doc['image'] ?? '',
                                          doc['gender'] ?? '',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isOnline)
                                  Positioned(
                                    bottom: 8,
                                    right: 12,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              doc['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isArabic 
                                    ? Doctor.fromMap(doc).specialtyAr 
                                    : Doctor.fromMap(doc).specialty,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF93C5FD),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom Arc for smooth transition
                      Positioned(
                        bottom: -1,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(40),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Body Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row (Glass Pill Tags)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard(
                            context,
                            Icons.people_alt_rounded,
                            const Color(0xFF8B5CF6),
                            doc['patients'].toString(),
                            isArabic ? 'مريض' : 'Patients',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey[300],
                          ),
                          _buildStatCard(
                            context,
                            Icons.star_rounded,
                            const Color(0xFFF59E0B),
                            doc['rating'].toString(),
                            isArabic ? 'تقييم' : 'Rating',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey[300],
                          ),
                          _buildStatCard(
                            context,
                            Icons.work_history_rounded,
                            const Color(0xFF0EA5E9),
                            '${doc['experience']}',
                            isArabic ? 'سنوات' : 'Years',
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // About Section
                      Text(
                        isArabic ? 'نبذة عن الطبيب' : 'About Doctor',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Text(
                          doc['about'] ??
                              (isArabic
                                  ? 'لا توجد معلومات إضافية.'
                                  : 'No additional information.'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey[400]
                                : const Color(0xFF475569),
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Working Hours
                      Text(
                        isArabic ? 'ساعات العمل' : 'Working Hours',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                doc['workingHours'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.grey[200]
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Extra padding for bottom bar
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Floating Glass Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.only(
                    top: 16,
                    bottom: 32,
                    left: 24,
                    right: 24,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isArabic ? 'سعر الكشف' : 'Consultation Fee',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${doc['price'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0EA5E9),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'ج.م' : 'EGP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  height: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Chat Button
                      GestureDetector(
                        onTap: () async {
                          // إظهار واجهة التحميل السريعة إذا كان الاتصال بطيئاً جداً
                          bool isLoading = true;
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (isLoading && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isArabic ? 'جاري فتح المحادثة...' : 'Opening chat...'), duration: const Duration(milliseconds: 500)),
                              );
                            }
                          });

                          try {
                            final chatService = ChatService();
                            final patientId = FirebaseAuth.instance.currentUser?.uid ?? '';
                            final patientName = FirebaseAuth.instance.currentUser?.displayName ?? 'Patient';

                            // 1. Get Chat ID (this might already exist or create a new doc) 
                            // This takes roundtrip time, but we don't need to load the full chat doc again with getChat.
                            final chatId = await chatService.createOrGetChat(
                              doctorId: doc['id'] ?? '',
                              doctorUserId: doc['userId'] ?? doc['id'] ?? '', // Added doctorUserId
                              doctorName: doc['name'] ?? '',
                              patientId: patientId,
                              patientName: patientName,
                            );

                            isLoading = false;
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();

                            if (context.mounted) {
                              // 2. Instead of loading the chat from firestore, create the object locally to save time
                              final chatInfo = Chat(
                                id: chatId,
                                doctorId: doc['id'] ?? '',
                                doctorUserId: doc['userId'] ?? doc['id'] ?? '', // Added doctorUserId
                                doctorName: doc['name'] ?? '',
                                patientId: patientId,
                                patientName: patientName,
                                createdAt: DateTime.now(),
                              );

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => firebase_chat.ChatScreen(chat: chatInfo),
                                ),
                              );
                            }
                          } catch (e) {
                            isLoading = false;
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _bookAppointment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              isArabic ? 'احجز الآن' : 'Book Now',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    Color color,
    String value,
    String label,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class CategoryDoctorsScreen extends StatefulWidget {
  final String category;
  final String categoryKeyword;

  const CategoryDoctorsScreen({
    super.key,
    required this.category,
    required this.categoryKeyword,
  });

  @override
  State<CategoryDoctorsScreen> createState() => _CategoryDoctorsScreenState();
}

class _CategoryDoctorsScreenState extends State<CategoryDoctorsScreen> {
  List<Doctor> _doctors = [];
  bool _isLoading = true;
  final HybridDoctorService _doctorService = HybridDoctorService();

  @override
  void initState() {
    super.initState();
    _doctorService.setUseFirestore(true);
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final data = await _doctorService.getDoctors(
        category: widget.categoryKeyword == 'All'
            ? null
            : widget.categoryKeyword,
      );
      if (mounted) {
        setState(() {
          _doctors = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            stretch: true,
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: const Color(0xFF0F172A),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: true,
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF064E3B),
                      Color(0xFF10B981),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      size: 50,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Color(0xFF0EA5E9),
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else if (_doctors.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: 60,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isArabic ? 'لا توجد نتائج' : 'No Results Found',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? 'لا يوجد أطباء متاحين في هذا التخصص حالياً'
                          : 'No doctors available in this specialty right now',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final doc = _doctors[index];
                  return _buildDoctorCard(context, doc, index);
                }, childCount: _doctors.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, Doctor doc, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isOnline =
        doc.isOnline &&
        (doc.lastSeen == null ||
            DateTime.now().difference(doc.lastSeen!).inMinutes < 5);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DoctorDetailsScreen(
                  doctor: {
                    'id': doc.id,
                    'name': isArabic ? doc.nameAr : doc.name,
                    'specialty': isArabic ? doc.specialtyAr : doc.specialty,
                    'rating': doc.rating,
                    'image': doc.image,
                    'about': isArabic ? doc.aboutAr : doc.about,
                    'gender': doc.gender,
                    'color': Colors.blue,
                    'isFavorite': doc.isFavorite,
                    'patients': doc.patients,
                    'experience': doc.experience,
                    'isOnline': doc.isOnline,
                    'lastSeen': doc.lastSeen,
                    'price': doc.price,
                    'phone': doc.phone,
                    'workingHours': doc.workingHours,
                    'schedule': doc.schedule,
                  },
                ),
              ),
            );
            _loadDoctors();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0xFF0EA5E9).withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Glowing Status Ring
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isOnline
                              ? const Color(0xFF10B981)
                              : Colors.grey.withValues(alpha: 0.3),
                          width: 2.5,
                        ),
                      ),
                      child: Hero(
                        tag: doc.id,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: _buildDoctorImage(doc.image, doc.gender),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF10B981)
                              : Colors.grey[400],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            width: 3,
                          ),
                          boxShadow: isOnline
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isArabic ? doc.nameAr : doc.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (doc.isFavorite)
                            const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFF43F5E),
                              size: 22,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF6366F1)],
                        ).createShader(bounds),
                        child: Text(
                          isArabic ? doc.specialtyAr : doc.specialty,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Availability tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey.withValues(alpha: 0.10)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOnline
                                  ? (isArabic ? 'متاح اليوم' : 'Available Today')
                                  : (isArabic ? 'غير متاح' : 'Busy'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isOnline
                                    ? const Color(0xFF10B981)
                                    : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  doc.rating.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF59E0B),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.work_history_rounded,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isArabic
                                      ? '${doc.experience} سنوات'
                                      : '${doc.experience} Yrs',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorImage(String imagePath, String gender) {
    if (imagePath.isEmpty) {
      return Icon(
        gender == 'Female' ? Icons.female : Icons.male,
        size: 40,
        color: Colors.grey,
      );
    }
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => Icon(
          gender == 'Female' ? Icons.female : Icons.male,
          size: 40,
          color: Colors.grey,
        ),
      );
    } else if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        memCacheWidth: 200,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Icon(
          gender == 'Female' ? Icons.female : Icons.male,
          size: 40,
          color: Colors.grey,
        ),
      );
    } else if (!kIsWeb) {
      // Local File
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => Icon(
          gender == 'Female' ? Icons.face_3_rounded : Icons.face_rounded,
          size: 40,
          color: Colors.white,
        ),
      );
    } else {
      return Icon(
        gender == 'Female' ? Icons.face_3_rounded : Icons.face_rounded,
        size: 40,
        color: Colors.white,
      );
    }
  }
}

class AppointmentScreen extends StatefulWidget {
  final String doctorName;
  final String specialty;
  final String doctorId;
  final String doctorUserId; // Added userId
  final String price;
  final Map<String, dynamic> schedule;

  const AppointmentScreen({
    super.key,
    required this.doctorName,
    required this.specialty,
    required this.doctorId,
    required this.doctorUserId, // Added userId
    required this.price,
    required this.schedule,
  });
  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  late DateTime _selectedDate;
  int _selectedTime = -1;
  bool _isSaving = false;
  List<String> _bookedTimes = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = _getFirstAvailableDate();
    _checkBookedTimes();
  }

  bool _isDayAvailable(DateTime date) {
    if (widget.schedule.isEmpty) return true;
    final List<String> weekdays = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
    ];
    String dayKey = weekdays[date.weekday - 1];
    if (widget.schedule.containsKey(dayKey)) {
      final daySch = widget.schedule[dayKey];
      if (daySch is Map && daySch['isAvailable'] == true) {
        return true;
      }
    }
    return false;
  }

  DateTime _getFirstAvailableDate() {
    DateTime current = DateTime.now();
    for (int i = 0; i < 30; i++) {
      if (_isDayAvailable(current)) {
        return current;
      }
      current = current.add(const Duration(days: 1));
    }
    return DateTime.now(); // Fallback
  }

  /// Get time slots for the currently selected date based on doctor schedule
  List<String> _getTimeSlotsForSelectedDate() {
    if (widget.schedule.isEmpty) {
      // Fallback: 9AM to 5PM, 1hr slots
      return List.generate(9, (i) => _formatTime(9 + i));
    }
    
    final List<String> weekdays = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
    ];
    final String dayKey = weekdays[_selectedDate.weekday - 1];
    final daySch = widget.schedule[dayKey];
    
    if (daySch == null || daySch is! Map || daySch['isAvailable'] != true) {
      return [];
    }
    
    // Parse start and end times e.g. '09:00', '17:00'
    int startHour = 9;
    int startMin = 0;
    int endHour = 17;
    int endMin = 0;
    int slotMin = (daySch['slotDuration'] as num?)?.toInt() ?? 30;
    
    final startParts = (daySch['startTime'] as String? ?? '09:00').split(':');
    final endParts = (daySch['endTime'] as String? ?? '17:00').split(':');
    
    if (startParts.length == 2) {
      startHour = int.tryParse(startParts[0]) ?? 9;
      startMin = int.tryParse(startParts[1]) ?? 0;
    }
    if (endParts.length == 2) {
      endHour = int.tryParse(endParts[0]) ?? 17;
      endMin = int.tryParse(endParts[1]) ?? 0;
    }
    
    final List<String> slots = [];
    int curHour = startHour;
    int curMin = startMin;
    
    while (curHour < endHour || (curHour == endHour && curMin < endMin)) {
      final period = curHour >= 12 ? 'PM' : 'AM';
      final displayHour = curHour > 12 ? curHour - 12 : (curHour == 0 ? 12 : curHour);
      final minStr = curMin.toString().padLeft(2, '0');
      slots.add('$displayHour:$minStr $period');
      
      curMin += slotMin;
      curHour += curMin ~/ 60;
      curMin = curMin % 60;
    }
    
    return slots;
  }

  String _formatDate(DateTime date) {
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return "${days[date.weekday - 1]}, ${date.day}";
  }

  String _formatTime(int hour) {
    String period = hour >= 12 ? 'PM' : 'AM';
    int h = hour > 12 ? hour - 12 : hour;
    if (h == 0) h = 12;
    return '$h:00 $period';
  }

  void _checkBookedTimes() async {
    String date = _formatDate(_selectedDate);
    final booked = await DatabaseHelper().getBookedTimes(
      widget.doctorName,
      date,
    );
    setState(() {
      _bookedTimes = booked;
      // لو الوقت اللي مختاره طلع محجوز، الغي الاختيار
      if (_selectedTime != -1 &&
          _bookedTimes.contains(_formatTime(9 + _selectedTime))) {
        _selectedTime = -1;
      }
    });
  }

  // فتح التقويم
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: (DateTime date) => _isDayAvailable(date),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = -1;
      });
      _checkBookedTimes();
    }
  }

  void _onConfirmPressed() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          isArabic ? "تأكيد الحجز" : "Confirm Booking",
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Text(
          isArabic
              ? "هل أنت متأكد من حجز موعد مع ${widget.doctorName} يوم ${_formatDate(_selectedDate)} الساعة ${_formatTime(9 + _selectedTime)}؟"
              : "Are you sure you want to book with ${widget.doctorName} on ${_formatDate(_selectedDate)} at ${_formatTime(9 + _selectedTime)}?",
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isArabic ? "إلغاء" : "Cancel",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveBooking();
            },
            child: Text(
              isArabic ? "تأكيد" : "Confirm",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[300]
                    : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBooking() async {
    final patient = FirebaseAuth.instance.currentUser;
    if (patient == null) return;
    final patientId = patient.uid;
    setState(() => _isSaving = true);
    try {
      final appointmentService = AppointmentService();
      
      // Improve patient name resolution
      String patientName = patient.displayName ?? '';
      if (patientName.isEmpty || 
          patientName.toLowerCase() == 'patient' || 
          patientName == 'مريض') {
        // Try fetching from users collection
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(patientId).get().timeout(const Duration(seconds: 10));
        if (userDoc.exists) {
          patientName = userDoc.data()?['name'] ?? 'Patient';
        } else {
          patientName = 'Patient';
        }
      }

      final hasAppt = await appointmentService.hasAppointmentOnDate(patientId, _selectedDate);
      
      if (hasAppt && mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic 
                ? 'لديك حجز بالفعل في هذا اليوم. لا يمكن حجز أكثر من موعد في اليوم الواحد.' 
                : 'You already have an appointment on this date. Only one appointment per day is allowed.'
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final slots = _getTimeSlotsForSelectedDate();
      final timeStr = _selectedTime >= 0 && _selectedTime < slots.length
          ? slots[_selectedTime]
          : _formatTime(9 + _selectedTime);

      // 1. Prepare Firestore Data
      String? firestoreId;
      try {
        firestoreId = await appointmentService.createAppointment(
          doctorId: widget.doctorId,
          doctorUserId: widget.doctorUserId, // Added userId
          doctorName: widget.doctorName,
          specialty: widget.specialty,
          patientId: patientId,
          patientName: patientName,
          date: _selectedDate,
          time: timeStr,
        );

        // Increment patient count on doctor doc
        await FirebaseFirestore.instance.collection('doctors').doc(widget.doctorId).update({
          'patientsCount': FieldValue.increment(1),
        });
      } catch (e) {
// debugPrint('⚠️ Firestore sync failed: $e');
      }

      // 2. Save locally (SQLite) with Firestore ID
      await DatabaseHelper().addAppointment(
        widget.doctorId,
        widget.doctorName,
        widget.specialty,
        _formatDate(_selectedDate),
        timeStr,
        firestoreId,
      );

      // 3. Schedule reminder notification (1 hour before appointment)
      try {
        // Use the same parsing logic as above for consistency
        int hour = 9;
        int minute = 0;
        final parts = timeStr.split(' ');
        if (parts.length == 2) {
          final hm = parts[0].split(':');
          hour = int.tryParse(hm[0]) ?? 9;
          minute = hm.length > 1 ? (int.tryParse(hm[1]) ?? 0) : 0;
          final isPM = parts[1].toUpperCase() == 'PM';
          if (isPM && hour != 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;
        }
        final appointmentDT = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute,
        );

        await NotificationService().scheduleAppointmentReminder(
          id: widget.doctorId.hashCode + _selectedDate.day,
          doctorName: widget.doctorName,
          appointmentDateTime: appointmentDT,
          isArabic: isArabic,
        );
      } catch (_) {}

      // 4. Immediate confirmation notification
      await NotificationService().showNotification(
        isArabic ? "تم تأكيد الحجز ✅" : "Appointment Confirmed ✅",
        isArabic
            ? "تم حجز موعد مع ${widget.doctorName} الساعة $timeStr"
            : "You booked with ${widget.doctorName} at $timeStr",
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              appointmentData: {
                'doctorId': widget.doctorId,
                'doctorName': widget.doctorName,
                'specialty': widget.specialty,
                'date': _formatDate(_selectedDate),
                'time': timeStr,
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? "حدث خطأ أثناء الحجز" : "Error during booking: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isArabic ? 'حجز موعد' : 'Book Appointment',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor info row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.doctorName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.specialty,
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.price} ${isArabic ? "ج.م" : "EGP"}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date selector
            Text(
              isArabic ? 'اختر اليوم' : 'Select Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isArabic ? 'تغيير' : 'Change',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF10B981), size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              isArabic ? 'اختر الوقت' : 'Select Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),

            // Time slots
            Expanded(
              child: Builder(builder: (ctx) {
                final slots = _getTimeSlotsForSelectedDate();
                if (slots.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy_rounded, color: Colors.orange, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isArabic ? 'الدكتور غير متاح' : 'Doctor Unavailable',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.orange),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isArabic
                                    ? 'هذا اليوم ليس ضمن مواعيد الدكتور، اختر يوماً آخر.'
                                    : 'This day is not in the doctor\'s schedule. Please choose another day.',
                                style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (ctx, index) {
                    final timeString = slots[index];
                    final isBooked = _bookedTimes.contains(timeString);
                    final isSelected = !isBooked && _selectedTime == index;

                    Color bgColor;
                    Color textColor;
                    if (isBooked) {
                      bgColor = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08);
                      textColor = const Color(0xFFEF4444);
                    } else if (isSelected) {
                      bgColor = const Color(0xFF10B981);
                      textColor = Colors.white;
                    } else {
                      bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
                      textColor = isDark ? Colors.white70 : const Color(0xFF334155);
                    }

                    return GestureDetector(
                      onTap: isBooked ? null : () => setState(() => _selectedTime = isSelected ? -1 : index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : (isBooked
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                    : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0))),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),

            const SizedBox(height: 16),
            // Confirm Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: (_selectedTime == -1 || _isSaving)
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: (_selectedTime == -1 || _isSaving)
                    ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
                    : null,
                borderRadius: BorderRadius.circular(18),
                boxShadow: (_selectedTime != -1 && !_isSaving)
                    ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
                    : null,
              ),
              child: ElevatedButton(
                onPressed: (_selectedTime == -1 || _isSaving) ? null : _onConfirmPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        isArabic ? 'تأكيد الحجز' : 'Confirm Booking',
                        style: TextStyle(
                          color: (_selectedTime == -1)
                              ? (isDark ? Colors.white38 : Colors.black26)
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === SUCCESS SCREEN ===
class SuccessScreen extends StatefulWidget {
  final Map<String, dynamic> appointmentData;
  const SuccessScreen({super.key, required this.appointmentData});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      isArabic ? "تم تأكيد الحجز!" : "Appointment Confirmed!",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isArabic 
                        ? "تم حجز موعدك بنجاح مع د. ${widget.appointmentData['doctorName']}"
                        : "Your booking with Dr. ${widget.appointmentData['doctorName']} has been successfully secured.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${widget.appointmentData['date']} | ${widget.appointmentData['time']}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 48),


                    const SizedBox(height: 60),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isArabic ? "تم" : "Done",
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PATIENT APPOINTMENT DETAIL SCREEN ───
// شاشة تفاصيل الموعد للمريض: يشوف التقرير، الأدوية، ويضبط التنبيهات
class PatientAppointmentDetailScreen extends StatefulWidget {
  final model.Appointment appointment;

  const PatientAppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<PatientAppointmentDetailScreen> createState() => _PatientAppointmentDetailScreenState();
}

class _PatientAppointmentDetailScreenState extends State<PatientAppointmentDetailScreen> {
  late List<model.Prescription> _prescriptions;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _prescriptions = List.from(widget.appointment.prescriptions ?? []);
  }

  Future<void> _toggleMedicineTaken(int index) async {
    if (_isUpdating) return;

    final med = _prescriptions[index];
    final newStatus = !med.isTaken;

    setState(() {
      _isUpdating = true;
      // Optimistic update
      _prescriptions[index] = model.Prescription(
        medicineName: med.medicineName,
        dosage: med.dosage,
        frequency: med.frequency,
        frequencyHours: med.frequencyHours,
        duration: med.duration,
        instructions: med.instructions,
        reminderTime: med.reminderTime,
        isTaken: newStatus,
      );
    });

    try {
      await AppointmentService().updatePrescriptionStatus(
        widget.appointment.id,
        med.medicineName,
        newStatus,
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _prescriptions[index] = med;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? 'فشل التحديث' : 'Update failed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = const Color(0xFF0EA5E9);
    final Color successColor = const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, successColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        isArabic ? 'تفاصيل الموعد' : 'Appointment Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      appointment.doctorName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _formatDoctorName(appointment.doctorName),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatSpecialty(appointment.specialty),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appointment Status Card
                  _buildSectionCard(
                    isDark,
                    child: Column(
                      children: [
                        _buildDetailRow(
                          Icons.calendar_today, 
                          isArabic ? 'التاريخ' : 'Date', 
                          DateFormat('yyyy-MM-dd').format(appointment.dateTime)
                        ),
                        const Divider(height: 30),
                        _buildDetailRow(
                          Icons.access_time, 
                          isArabic ? 'الوقت' : 'Time', 
                          appointment.formattedTime
                        ),
                        const Divider(height: 30),
                        _buildDetailRow(
                          Icons.info_outline, 
                          isArabic ? 'الحالة' : 'Status', 
                          isArabic ? appointment.statusAr : appointment.status
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Doctor's Notes
                  if (appointment.doctorNotes != null && appointment.doctorNotes!.isNotEmpty) ...[
                    _buildSectionTitle(isArabic ? 'ملاحظات الطبيب' : 'Doctor\'s Notes', Icons.notes),
                    const SizedBox(height: 10),
                    _buildSectionCard(
                      isDark,
                      child: Text(
                        appointment.doctorNotes!,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                   // Prescriptions
                   if (_prescriptions.isNotEmpty) ...[
                     _buildSectionTitle(isArabic ? 'الوصفة الطبية' : 'Prescription', Icons.medication),
                    const SizedBox(height: 10),
                    ...List.generate(
                      _prescriptions.length,
                      (index) => _buildMedicineCard(context, isDark, _prescriptions[index], index),
                    ),
                    
                    const SizedBox(height: 20),
                    // Schedule All Notifications Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _scheduleAllReminders(context, _prescriptions),
                        icon: const Icon(Icons.alarm_add, color: Colors.white),
                        label: Text(
                          isArabic ? 'تفعيل تنبيهات الأدوية' : 'Activate Medication Alarms',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: successColor,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.medication_outlined, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text(
                            isArabic ? 'لا توجد وصفة طبية مسجلة بعد' : 'No prescriptions recorded yet',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0EA5E9)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSectionCard(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(width: 15),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  List<String> _calculateTimes(String frequency) {
    final RegExp regExp = RegExp(r'(\d+)');
    final match = regExp.firstMatch(frequency);
    int times = match != null ? int.parse(match.group(1)!) : 1;
    
    List<String> results = [];
    int startHour = 9; // Suggested start time
    int interval = (24 ~/ times);
    
    for (int i = 0; i < times; i++) {
      int hour = (startHour + (i * interval)) % 24;
      String period = hour >= 12 ? 'PM' : 'AM';
      int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      results.add('$displayHour:00 $period');
    }
    return results;
  }

  Widget _buildMedicineCard(BuildContext context, bool isDark, model.Prescription med, int index) {
    final scheduleTimes = med.reminderTime != null
        ? [DateFormat('hh:mm a').format(med.reminderTime!)]
        : _calculateTimes(med.frequency);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication, color: Color(0xFF0EA5E9), size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.medicineName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${med.dosage} - ${med.duration}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      med.reminderTime != null
                          ? (isArabic ? 'موعد التنبيه:' : 'Alarm Time:')
                          : (isArabic ? 'الجدول:' : 'Schedule:'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                    const Spacer(),
                    Text(
                      med.frequency,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: scheduleTimes.map((time) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9)),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          if (med.instructions != null && med.instructions!.isNotEmpty) ...[
            const Divider(height: 20, color: Colors.transparent),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    med.instructions!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Mark as Taken Switch/Button
          InkWell(
            onTap: () => _toggleMedicineTaken(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: med.isTaken 
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: med.isTaken ? const Color(0xFF10B981) : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    med.isTaken ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: med.isTaken ? const Color(0xFF10B981) : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    med.isTaken 
                      ? (isArabic ? 'تم تناول الدواء' : 'Medicine Taken')
                      : (isArabic ? 'تحديد كمتناول' : 'Mark as Taken'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: med.isTaken ? const Color(0xFF10B981) : Colors.grey[600],
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

  void _scheduleAllReminders(BuildContext context, List<model.Prescription> medicines) async {
    final ns = NotificationService();
    final now = DateTime.now();
    final defaultStartTime = DateTime(now.year, now.month, now.day, 9, 0);
    
    for (final med in medicines) {
      final startTime = med.reminderTime ?? defaultStartTime;
      await ns.scheduleMedicationReminders(
        medicineName: med.medicineName,
        dosage: med.dosage,
        frequency: med.frequency,
        frequencyHours: med.frequencyHours,
        duration: med.duration,
        startTime: startTime,
        isArabic: isArabic,
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic 
              ? 'تم تفعيل جميع تنبيهات الأدوية بنجاح ✅' 
              : 'All medicine reminders activated successfully ✅',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  String _formatDoctorName(String name) {
    name = name.trim();
    final RegExp prefixRegExp = RegExp(r'^(dr\.|د\.|dr|د)\s*', caseSensitive: false);
    name = name.replaceAll(prefixRegExp, '').trim();
    return isArabic ? "د. $name" : "Dr. $name";
  }

  String _formatSpecialty(String specialty) {
    if (specialty.toLowerCase() == 'general' || specialty.isEmpty) {
      return isArabic ? 'عام' : 'General';
    }
    return specialty;
  }
}
