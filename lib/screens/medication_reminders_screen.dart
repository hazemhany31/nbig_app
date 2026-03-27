// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../language_config.dart';

class MedicationRemindersScreen extends StatefulWidget {
  const MedicationRemindersScreen({super.key});

  @override
  State<MedicationRemindersScreen> createState() =>
      _MedicationRemindersScreenState();
}

class _MedicationRemindersScreenState extends State<MedicationRemindersScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final NotificationService _notificationService = NotificationService();
  List<Appointment> _completedAppointments = [];
  // Local map to track which reminders are enabled (medicine name → bool)
  final Map<String, bool> _reminderEnabled = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load reminder states from prefs first
    final prefs = await SharedPreferences.getInstance();

    _appointmentService.getPatientAppointments(user.uid).listen((appointments) {
      if (!mounted) return;
      final List<Appointment> filtered = [];
      for (var a in appointments) {
        if ((a.status == 'completed' || a.status == 'confirmed') &&
            a.prescriptions != null &&
            a.prescriptions!.isNotEmpty) {
          final active = a.prescriptions!.where((p) {
            final days = _extractNumber(p.duration);
            if (days == null) return true;
            final expiry = a.dateTime.add(Duration(days: days));
            return DateTime.now().isBefore(expiry.add(const Duration(hours: 24)));
          }).toList();

          if (active.isNotEmpty) {
            filtered.add(Appointment(
              id: a.id,
              doctorId: a.doctorId,
              doctorName: a.doctorName,
              specialty: a.specialty,
              patientId: a.patientId,
              patientName: a.patientName,
              dateTime: a.dateTime,
              prescriptions: active,
              doctorNotes: a.doctorNotes,
              status: a.status,
            ));
            // Load reminder state for each med
            for (var p in active) {
              _reminderEnabled[p.medicineName] =
                  prefs.getBool('rem_ena_${p.medicineName}') ?? false;
            }
          }
        }
      }
      setState(() {
        _completedAppointments = filtered;
        _isLoading = false;
      });
    });
  }

  int? _extractNumber(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  /// Compute scheduled times as readable strings based on frequency / frequencyHours
  List<Map<String, String>> _buildSchedule(Prescription p) {
    int intervalHours = 24;
    if (p.frequencyHours != null && p.frequencyHours! > 0) {
      intervalHours = p.frequencyHours!;
    } else {
      final count = _extractNumber(p.frequency);
      if (count != null && count > 0) intervalHours = 24 ~/ count;
    }

    final int times = 24 ~/ intervalHours;
    const int startHour = 9; // start at 9 AM
    final List<Map<String, String>> schedule = [];

    for (int i = 0; i < times; i++) {
      final int hour = (startHour + i * intervalHours) % 24;
      final String period = hour >= 12 ? 'PM' : 'AM';
      final int display = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      // Label: Morning / Noon / Evening / Night
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
      schedule.add({'time': '$display:00 $period', 'label': label});
    }
    return schedule;
  }

  Future<void> _toggleReminder(Prescription prescription) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final bool current = _reminderEnabled[prescription.medicineName] ?? false;

    if (current) {
      await _notificationService.cancelMedicationReminders(prescription.medicineName);
      await prefs.setBool('rem_ena_${prescription.medicineName}', false);
      setState(() => _reminderEnabled[prescription.medicineName] = false);
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
      setState(() => _reminderEnabled[prescription.medicineName] = true);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(!current ? Icons.notifications_active : Icons.notifications_off,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(!current
                ? (isArabic ? 'تم تفعيل التنبيهات ✅' : 'Reminders enabled ✅')
                : (isArabic ? 'تم إيقاف التنبيهات' : 'Reminders disabled')),
          ]),
          backgroundColor: !current ? const Color(0xFF10B981) : Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── Premium AppBar ──────────────────────────────────────────
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
                                  isArabic ? 'أدويتي' : 'My Medications',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  isArabic
                                      ? 'الوصفات الطبية والتذكيرات'
                                      : 'Prescriptions & Reminders',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
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

          // ── Body ────────────────────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                      color: Color(0xFF10B981), strokeWidth: 3),
                ),
              ),
            )
          else if (_completedAppointments.isEmpty)
            SliverFillRemaining(child: _buildEmpty(isDark))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final appt = _completedAppointments[index];
                    return _buildAppointmentSection(appt, isDark);
                  },
                  childCount: _completedAppointments.length,
                ),
              ),
            ),
        ],
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
              isArabic ? 'لا توجد وصفات طبية' : 'No Prescriptions Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isArabic
                  ? 'ستظهر هنا الأدوية التي يصفها لك الأطباء بعد الكشف'
                  : 'Medicines prescribed by your doctors will appear here after your appointment',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentSection(Appointment appt, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doctor section header
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
                    color: isDark
                        ? Colors.grey[300]
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...appt.prescriptions!
            .map((p) => _buildMedCard(p, isDark)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMedCard(Prescription med, bool isDark) {
    final isEnabled = _reminderEnabled[med.medicineName] ?? false;
    final schedule = _buildSchedule(med);
    final Color activeColor =
        isEnabled ? const Color(0xFF10B981) : const Color(0xFF0EA5E9);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnabled
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
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
            // ── Top row: icon + name + toggle ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.medication_rounded,
                      color: activeColor, size: 26),
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
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _chip(med.dosage, const Color(0xFF0EA5E9), isDark),
                          const SizedBox(width: 6),
                          _chip(med.duration, const Color(0xFFF59E0B), isDark),
                        ],
                      ),
                    ],
                  ),
                ),
                // Reminder toggle
                GestureDetector(
                  onTap: () => _toggleReminder(med),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isEnabled
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEnabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: isEnabled
                              ? const Color(0xFF10B981)
                              : Colors.grey[500],
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isEnabled
                              ? (isArabic ? 'مفعّل' : 'ON')
                              : (isArabic ? 'إيقاف' : 'OFF'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isEnabled
                                ? const Color(0xFF10B981)
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Schedule times ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 15,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'مواعيد الجرعات:' : 'Dose Schedule:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.grey[300]
                              : const Color(0xFF475569),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        med.frequency,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: schedule
                          .map((s) => _timeChip(s, isDark))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Instructions ────────────────────────────────────────────
            if (med.instructions != null && med.instructions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        med.instructions!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey[300]
                              : const Color(0xFF475569),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
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

  Widget _timeChip(Map<String, String> s, bool isDark) {
    final IconData icon;
    final Color color;
    final String timeLabel = s['label']!;

    if (timeLabel == 'Morning' || timeLabel == 'صباحاً') {
      icon = Icons.wb_sunny_rounded;
      color = const Color(0xFFF59E0B);
    } else if (timeLabel == 'Noon' || timeLabel == 'ظهراً') {
      icon = Icons.brightness_high_rounded;
      color = const Color(0xFFEF4444);
    } else if (timeLabel == 'Evening' || timeLabel == 'مساءً') {
      icon = Icons.wb_twilight_rounded;
      color = const Color(0xFF8B5CF6);
    } else {
      icon = Icons.nightlight_round;
      color = const Color(0xFF0EA5E9);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            s['time']!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            s['label']!,
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDoctorNameAndSpecialty(Appointment appt) {
    String name = appt.doctorName.trim();
    // Remove existing Dr. prefixes (English & Arabic) to avoid duplication
    final RegExp prefixRegExp = RegExp(r'^(dr\.|د\.|dr|د)\s*', caseSensitive: false);
    name = name.replaceAll(prefixRegExp, '').trim();

    // Re-apply prefix based on current app language
    name = isArabic ? "د. $name" : "Dr. $name";

    // Handle specialty - if it's 'General' try to localize or use it
    String specialty = appt.specialty;
    if (specialty.toLowerCase() == 'general' || specialty.isEmpty) {
      specialty = isArabic ? 'عام' : 'General';
    }

    return '$name  •  $specialty';
  }
}
