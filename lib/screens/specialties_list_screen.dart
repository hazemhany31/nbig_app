import 'package:flutter/material.dart';
import 'sub_screens.dart'; // For CategoryDoctorsScreen
import '../language_config.dart';

class Specialty {
  final String nameEn;
  final String nameAr;
  final String dbKeyword;
  final IconData icon;
  final List<Color> colors;

  const Specialty({
    required this.nameEn,
    required this.nameAr,
    required this.dbKeyword,
    required this.icon,
    required this.colors,
  });
}

class SpecialtiesListScreen extends StatelessWidget {
  const SpecialtiesListScreen({super.key});

  static const List<Specialty> specialties = [
    Specialty(
      nameEn: 'Cardiology',
      nameAr: 'قلب',
      dbKeyword: 'Cardio',
      icon: Icons.monitor_heart_outlined,
      colors: [Color(0xFFEF4444), Color(0xFFF97316)],
    ),
    Specialty(
      nameEn: 'Dermatology',
      nameAr: 'جلدية',
      dbKeyword: 'Dermatology',
      icon: Icons.face,
      colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
    ),
    Specialty(
      nameEn: 'Neurology',
      nameAr: 'مخ وأعصاب',
      dbKeyword: 'Neurology',
      icon: Icons.psychology,
      colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
    ),
    Specialty(
      nameEn: 'Orthopedics',
      nameAr: 'عظام',
      dbKeyword: 'Orthopedics',
      icon: Icons.accessibility_new,
      colors: [Color(0xFF10B981), Color(0xFF0EA5E9)],
    ),
    Specialty(
      nameEn: 'Pediatrics',
      nameAr: 'أطفال',
      dbKeyword: 'Pediatric',
      icon: Icons.baby_changing_station,
      colors: [Color(0xFFF97316), Color(0xFFEF4444)],
    ),
    Specialty(
      nameEn: 'Dentistry',
      nameAr: 'أسنان',
      dbKeyword: 'Dent',
      icon: Icons.medical_services_rounded,
      colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
    ),
    Specialty(
      nameEn: 'Ophthalmology',
      nameAr: 'عيون',
      dbKeyword: 'Ophthalmology',
      icon: Icons.remove_red_eye_rounded,
      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
    Specialty(
      nameEn: 'Internal Medicine',
      nameAr: 'باطنة',
      dbKeyword: 'Internal Medicine',
      icon: Icons.medical_information_outlined,
      colors: [Color(0xFF3B82F6), Color(0xFF2DD4BF)],
    ),
    Specialty(
      nameEn: 'Obstetrics & Gynecology',
      nameAr: 'نساء وتوليد',
      dbKeyword: 'Obstetrics & Gynecology',
      icon: Icons.pregnant_woman_rounded,
      colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    ),
    Specialty(
      nameEn: 'ENT',
      nameAr: 'أنف وأذن',
      dbKeyword: 'ENT',
      icon: Icons.hearing_rounded,
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    Specialty(
      nameEn: 'Psychiatry',
      nameAr: 'نفسية',
      dbKeyword: 'Psychiatry',
      icon: Icons.psychology_alt_rounded,
      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    ),
    Specialty(
      nameEn: 'General Surgery',
      nameAr: 'جراحة عامة',
      dbKeyword: 'General Surgery',
      icon: Icons.content_cut_rounded,
      colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
    ),
    Specialty(
      nameEn: 'Urology',
      nameAr: 'مسالك بولية',
      dbKeyword: 'Urology',
      icon: Icons.water_drop_outlined,
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    ),
    Specialty(
      nameEn: 'Physical Therapy',
      nameAr: 'علاج طبيعي',
      dbKeyword: 'Physical Therapy',
      icon: Icons.directions_walk_rounded,
      colors: [Color(0xFF10B981), Color(0xFF047857)],
    ),
    Specialty(
      nameEn: 'Radiology',
      nameAr: 'أشعة',
      dbKeyword: 'Radiology',
      icon: Icons.settings_overscan_rounded,
      colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
    ),
    Specialty(
      nameEn: 'Nutrition',
      nameAr: 'تغذية',
      dbKeyword: 'Nutrition',
      icon: Icons.restaurant_rounded,
      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isArabic ? 'كل التخصصات' : 'All Specialaties',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.95,
        ),
        itemCount: specialties.length,
        itemBuilder: (context, index) {
          final specialty = specialties[index];
          return _buildSpecialtyCard(context, specialty, isDark);
        },
      ),
    );
  }

  Widget _buildSpecialtyCard(BuildContext context, Specialty specialty, bool isDark) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: specialty.colors.first.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryDoctorsScreen(
                    category: isArabic ? specialty.nameAr : specialty.nameEn,
                    categoryKeyword: specialty.dbKeyword,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          specialty.colors.first.withValues(alpha: 0.15),
                          specialty.colors.last.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      specialty.icon,
                      color: specialty.colors.first,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic ? specialty.nameAr : specialty.nameEn,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
