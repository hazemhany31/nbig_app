import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';

/// مزود قائمة الأدوية النشطة للمريض
final patientMedicationsProvider = StreamProvider<List<Appointment>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value([]);

  final appointmentService = AppointmentService();
  
  return appointmentService.getPatientAppointments(user.uid).asyncMap((appointments) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Appointment> filtered = [];

    for (var a in appointments) {
      if ((a.status == 'completed' || a.status == 'confirmed') &&
          a.prescriptions != null &&
          a.prescriptions!.isNotEmpty) {
        
        final active = a.prescriptions!.where((p) {
          // التحقق مما إذا كان الدواء قد تم تعليمه كمكتمل
          final isDone = prefs.getBool('done_med_${a.id}_${p.medicineName}') ?? false;
          if (isDone) return false;

          // التحقق من مدة العلاج
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
        }
      }
    }
    return filtered;
  });
});

int? _extractNumber(String text) {
  final match = RegExp(r'(\d+)').firstMatch(text);
  return match != null ? int.parse(match.group(1)!) : null;
}
