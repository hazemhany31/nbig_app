import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../services/notification_service.dart';
import '../services/medication_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../language_config.dart';
import '../providers/medication_provider.dart';
import 'medication_analytics_screen.dart';

class MedicationRemindersScreen extends ConsumerStatefulWidget {
  const MedicationRemindersScreen({super.key});

  @override
  ConsumerState<MedicationRemindersScreen> createState() =>
      _MedicationRemindersScreenState();
}

class _MedicationRemindersScreenState
    extends ConsumerState<MedicationRemindersScreen> {
  final NotificationService _notificationService = NotificationService();
  final MedicationTrackingService _trackingService = MedicationTrackingService();
  final Map<String, bool> _reminderEnabled = {};
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  int? _extractNumber(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  List<Map<String, String>> _buildSchedule(Prescription p) {
    int intervalHours = 24;
    if (p.frequencyHours != null && p.frequencyHours! > 0) {
      intervalHours = p.frequencyHours!;
    } else {
      final count = _extractNumber(p.frequency);
      if (count != null && count > 0) intervalHours = 24 ~/ count;
    }

    final int times = 24 ~/ intervalHours;
    const int startHour = 9;
    final List<Map<String, String>> schedule = [];

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
      schedule.add({'time': '$display:00 $period', 'label': label, 'rawHour': hour.toString()});
    }
    return schedule;
  }

  Future<void> _toggleReminder(Prescription prescription) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final bool current = _reminderEnabled[prescription.medicineName] ?? false;

    if (current) {
      await _notificationService
          .cancelMedicationReminders(prescription.medicineName);
      await prefs.setBool('rem_ena_${prescription.medicineName}', false);
      if (mounted) {
        setState(() => _reminderEnabled[prescription.medicineName] = false);
      }
    } else {
      final now = DateTime.now();
      final startTime = DateTime(now.year, now.month, now.day, 9, 0);
      await _notificationService.scheduleMedicationReminders(
        medicineName: prescription.medicineName,
        dosage: prescription.dosage,
        frequency: prescription.frequency,
        frequencyHours: prescription.frequencyHours,
        duration: prescription.duration,
        startTime: startTime,
        isArabic: isArabic,
      );
      await prefs.setBool('rem_ena_${prescription.medicineName}', true);
      if (mounted) {
        setState(() => _reminderEnabled[prescription.medicineName] = true);
      }
    }
  }

  Future<bool> _getMedReminderState(String medName) async {
    if (_reminderEnabled.containsKey(medName)) {
      return _reminderEnabled[medName]!;
    }
    final prefs = await SharedPreferences.getInstance();
    final state = prefs.getBool('rem_ena_$medName') ?? false;
    _reminderEnabled[medName] = state;
    return state;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medicationsAsync = ref.watch(patientMedicationsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: medicationsAsync.when(
        data: (appointments) {
          int totalMeds = 0;
          for (var a in appointments) {
             totalMeds += a.prescriptions?.length ?? 0;
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 160,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.medication_rounded,
                                      color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic ? 'تتبع أدويتي' : 'Medication Tracker',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        isArabic
                                            ? '$totalMeds أدوية نشطة'
                                            : '$totalMeds Active Medicines',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const MedicationAnalyticsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Streak & Analytics Future Builder
              SliverToBoxAdapter(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _trackingService.calculateStreakAndAnalytics(appointments),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final data = snapshot.data!;
                    final streak = data['streak'] ?? 0;
                    final todayLeft = data['todayLeft'] ?? 0;
                    final todayTotal = data['todayTotal'] ?? 0;
                    final allCompleted = data['allCompleted'] == true;
                    final double dailyProgress = todayTotal > 0 ? (todayTotal - todayLeft) / todayTotal : 0.0;
                    
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: dailyProgress,
                                  strokeWidth: 6,
                                  backgroundColor: (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    allCompleted ? const Color(0xFF10B981) : const Color(0xFFF97316),
                                  ),
                                ),
                                if (allCompleted)
                                  const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 28)
                                else
                                  Text(
                                    "${(dailyProgress * 100).toInt()}%",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFF97316),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allCompleted 
                                    ? (isArabic ? 'رائع! أكملت كل جرعات اليوم' : 'Awesome! All doses completed today.')
                                    : (isArabic ? 'تبقى $todayLeft جرعات اليوم' : '$todayLeft doses remaining today.'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isArabic ? 'متتالية: $streak أيام' : '$streak Days Streak',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  }
                ),
              ),

              // Date Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setState(() {
                            _currentDate = _currentDate.subtract(const Duration(days: 1));
                          });
                        },
                      ),
                      Text(
                        _currentDate.day == DateTime.now().day && _currentDate.month == DateTime.now().month && _currentDate.year == DateTime.now().year
                            ? (isArabic ? 'اليوم' : 'Today')
                            : "${_currentDate.day}/${_currentDate.month}/${_currentDate.year}",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setState(() {
                            _currentDate = _currentDate.add(const Duration(days: 1));
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              if (appointments.isEmpty)
                SliverFillRemaining(child: _buildEmpty(isDark))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final appt = appointments[index];
                        return _buildAppointmentTrackerSection(appt, isDark);
                      },
                      childCount: appointments.length,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => _buildShimmerLoading(isDark),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAppointmentTrackerSection(Appointment appt, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFF10B981).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF10B981), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatDoctorNameAndSpecialty(appt),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? Colors.grey[300] : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...appt.prescriptions!
            .map((p) => _buildMedTrackerCard(appt, p, isDark)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMedTrackerCard(
      Appointment appt, Prescription med, bool isDark) {
    final schedule = _buildSchedule(med);
    final int totalDoses = schedule.length;

    return StreamBuilder<DocumentSnapshot>(
      stream: _trackingService.getTrackingStream(appt.id),
      builder: (context, snapshot) {
        List<String> takenDoseTimes = [];
        int takenCount = 0;
        double progress = 0.0;
        bool isCompleted = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          takenDoseTimes = _trackingService.getTakenDoses(
            snapshot: snapshot.data!,
            medicineName: med.medicineName,
            date: _currentDate,
          );
          takenCount = takenDoseTimes.length;
          progress = totalDoses > 0 ? (takenCount / totalDoses) : 0;
          isCompleted = takenCount >= totalDoses && totalDoses > 0;
        }

        final Color primaryColor =
            isCompleted ? const Color(0xFF10B981) : const Color(0xFF0EA5E9);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent),
              width: isCompleted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isCompleted
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04)),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 5,
                            backgroundColor: primaryColor.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        ),
                        Text(
                          "${(progress * 100).toInt()}%",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.medicineName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _chip(med.dosage, const Color(0xFF64748B), isDark),
                              const SizedBox(width: 6),
                              _chip(med.duration, const Color(0xFF64748B), isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FutureBuilder<bool>(
                        future: _getMedReminderState(med.medicineName),
                        builder: (context, remSnapshot) {
                          final isEnabled = remSnapshot.data ?? false;
                          return GestureDetector(
                            onTap: () => _toggleReminder(med),
                            child: Icon(
                              isEnabled
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: isEnabled
                                  ? const Color(0xFF10B981)
                                  : Colors.grey[400],
                              size: 22,
                            ),
                          );
                        }),
                  ],
                ),
                const SizedBox(height: 16),
                if (isCompleted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        isArabic ? 'أحسنت! أكملت جرعات اليوم' : 'Great! All doses taken today.',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  isArabic ? 'جرعات اليوم:' : 'Today\'s Doses:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: schedule.map((s) {
                    final doseTimeStr = s['time']!;
                    final isDoseTaken = takenDoseTimes.contains(doseTimeStr);
                    return GestureDetector(
                        onTap: () async {
                        HapticFeedback.lightImpact();
                        await _trackingService.toggleDoseTaken(
                          appointmentId: appt.id,
                          medicineName: med.medicineName,
                          doseTime: doseTimeStr,
                          date: _currentDate,
                          taken: !isDoseTaken,
                          totalDoses: totalDoses,
                        );
                        if (mounted) setState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDoseTaken
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDoseTaken
                                ? const Color(0xFF10B981)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDoseTaken
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isDoseTaken
                                  ? const Color(0xFF10B981)
                                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['time']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDoseTaken
                                        ? const Color(0xFF10B981)
                                        : (isDark
                                            ? Colors.white
                                            : const Color(0xFF334155)),
                                  ),
                                ),
                                Text(
                                  s['label']!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDoseTaken
                                        ? const Color(0xFF10B981)
                                        : Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF0EA5E9)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.medication_rounded,
                  size: 60, color: Colors.white),
            ),
            const SizedBox(height: 28),
            Text(
              isArabic ? 'لا توجد أدوية نشطة' : 'No Active Medicines',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey[300]!,
      highlightColor: isDark ? const Color(0xFF334155) : Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => Container(
          height: 150,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  String _formatDoctorNameAndSpecialty(Appointment appt) {
    String name = appt.doctorName.trim();
    final RegExp prefixRegExp = RegExp(r'^(dr\.|د\.|dr|د)\s*', caseSensitive: false);
    name = name.replaceAll(prefixRegExp, '').trim();
    name = isArabic ? "د. $name" : "Dr. $name";
    String specialty = appt.specialty;
    if (specialty.toLowerCase() == 'general' || specialty.isEmpty) {
      specialty = isArabic ? 'عام' : 'General';
    }
    return '$name  •  $specialty';
  }
}
