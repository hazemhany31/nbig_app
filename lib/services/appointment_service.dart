import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

/// Service for managing appointments in Firestore
class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createAppointment({
    required String doctorId,
    required String doctorName,
    required String specialty,
    required String patientId,
    required String patientName,
    required DateTime date,
    required String time,
    required String doctorUserId, // Added doctorUserId
  }) async {
    try {
      // 1. Calculate the exact DateTime
      DateTime appointmentDateTime = _parseTimeToDateTime(date, time);

      // 2. Add to Firestore — store BOTH doctorId (doc ID) and doctorUserId (Auth UID)
      //    so that doctor_app can always find this appointment regardless of which ID it uses
      final appointmentData = {
        'doctorId': doctorId,
        'doctorUserId': doctorUserId.isNotEmpty ? doctorUserId : doctorId, // ← KEY FIX
        'doctorName': doctorName,
        'specialty': specialty,
        'patientId': patientId,
        'patientName': patientName,
        'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'time': time,
        'dateTime': Timestamp.fromDate(
          appointmentDateTime,
        ),
        'duration': 20,
        'type': 'new',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

// debugPrint('📝 Adding appointment doc: $appointmentData');
      final docRef = await _firestore
          .collection('appointments')
          .add(appointmentData)
          .timeout(const Duration(seconds: 15));

      // 3. Trigger notification for the doctor (Use Auth UID as recipientId)
      await _triggerDoctorNotification(
        recipientId: doctorUserId.isNotEmpty ? doctorUserId : doctorId,
        patientName: patientName,
        appointmentId: docRef.id,
      );

      return docRef.id;
    } catch (e) {
// debugPrint('❌ Error in createAppointment: $e');
      rethrow;
    }
  }

  /// Trigger a notification document for the doctor
  Future<void> _triggerDoctorNotification({
    required String recipientId,
    required String patientName,
    required String appointmentId,
  }) async {
    try {
      // Create a notification document that a Cloud Function can pick up
      // OR the doctor app can listen to in a stream for foreground alerts
      final notifData = {
        'recipientId': recipientId,
        'title': 'حجز جديد',
        'body': 'قام المريض $patientName بحجز موعد جديد',
        'type': 'new_appointment',
        'appointmentId': appointmentId,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
      };
/*
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚀 NOTIFICATION TARGET: $recipientId');
      print('📝 Data: $notifData');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
*/
      await _firestore.collection('notifications').add(notifData).timeout(const Duration(seconds: 10));
      debugPrint('🔔 Notification document created in Firestore for doctor: $recipientId');

    } catch (e) {
// debugPrint('⚠️ Failed to create notification record: $e');
    }
  }

  /// Parse time string like "10:00 AM" and combine with date
  DateTime _parseTimeToDateTime(DateTime date, String timeStr) {
    try {
      // Parse "10:00 AM" or "2:00 PM"
      final parts = timeStr.trim().split(' ');
      final timePart = parts[0]; // "10:00"
      final period = parts.length > 1
          ? parts[1].toUpperCase()
          : 'AM'; // "AM" or "PM"

      final hourMinute = timePart.split(':');
      int hour = int.parse(hourMinute[0]);
      final minute = hourMinute.length > 1 ? int.parse(hourMinute[1]) : 0;

      // Convert to 24-hour format
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
// debugPrint('⚠️ Error parsing time: $timeStr, using default');
      return DateTime(
        date.year,
        date.month,
        date.day,
        10,
        0,
      ); // Default 10:00 AM
    }
  }

  /// Check if patient already has an appointment on a given date
  Future<bool> hasAppointmentOnDate(String patientId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where(
          'dateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get()
        .timeout(const Duration(seconds: 10));

    // Exclude cancelled appointments
    final activeAppointments = snapshot.docs.where((doc) {
      final data = doc.data();
      return data['status'] != 'cancelled';
    });

    return activeAppointments.isNotEmpty;
  }

  /// Get all appointments for a patient
  Stream<List<Appointment>> getPatientAppointments(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Appointment.fromFirestore(doc))
              .toList();
        });
  }

  /// Get all appointments for a patient (Future version)
  Future<List<Appointment>> getPatientAppointmentsFuture(String patientId) async {
    final snapshot = await _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('dateTime', descending: false)
        .get()
        .timeout(const Duration(seconds: 10));

    return snapshot.docs
        .map((doc) => Appointment.fromFirestore(doc))
        .toList();
  }

  /// Get a single appointment by ID
  Future<Appointment?> getAppointment(String appointmentId) async {
    try {
      final doc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        return Appointment.fromFirestore(doc);
      }
      return null;
    } catch (e) {
// debugPrint('❌ Error getting appointment: $e');
      return null;
    }
  }

  /// Cancel an appointment (patient side)
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'cancelReason': 'ألغيت من المريض',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
// debugPrint('✅ Appointment cancelled');
    } catch (e) {
// debugPrint('❌ Error cancelling appointment: $e');
      rethrow;
    }
  }

  /// Send consultation report to doctor after appointment
  Future<void> sendConsultationReport({
    required String appointmentId,
    required String symptoms,
    required String notes,
    String? treatmentPlan,
  }) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'report': {
          'symptoms': symptoms,
          'notes': notes,
          'treatmentPlan': treatmentPlan ?? '',
          'sentAt': FieldValue.serverTimestamp(),
        },
        'hasReport': true,
        'status': 'completed',
      });
// debugPrint('✅ Consultation report sent for appointment: $appointmentId');
    } catch (e) {
// debugPrint('❌ Error sending consultation report: $e');
      rethrow;
    }
  }

  /// Get the most recent appointment ID for a patient
  Future<String?> getLastAppointmentId(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
// debugPrint('❌ Error getting last appointment: $e');
      return null;
    }
  }
  /// Update the "taken" status of a specific medicine in an appointment
  Future<void> updatePrescriptionStatus(String appointmentId, String medicineName, bool isTaken) async {
    try {
      final docRef = _firestore.collection('appointments').doc(appointmentId);
      final docSnap = await docRef.get();
      
      if (docSnap.exists) {
        final data = docSnap.data()!;
        final List<dynamic> prescriptionsRaw = data['prescriptions'] ?? [];
        
        final List<Map<String, dynamic>> updatedPrescriptions = prescriptionsRaw.map((p) {
          final map = Map<String, dynamic>.from(p as Map<String, dynamic>);
          final name = map['name'] ?? map['medicineName'] ?? '';
          if (name == medicineName) {
            map['isTaken'] = isTaken;
          }
          return map;
        }).toList();
        
        await docRef.update({'prescriptions': updatedPrescriptions});
      }
    } catch (e) {
      debugPrint('❌ Error updating prescription status: $e');
      rethrow;
    }
  }
}
