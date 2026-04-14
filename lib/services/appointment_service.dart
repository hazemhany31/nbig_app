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
      // 0. Safety Check: Verify no existing appointment for this day with this specific doctor
      final hasExisting = await hasAppointmentOnDate(patientId, doctorId, date);
      if (hasExisting) {
        throw Exception('user_already_has_appointment_with_this_doctor');
      }

      // 1. Calculate dates and deterministic Document ID
      DateTime appointmentDateTime = _parseTimeToDateTime(date, time);
      final String dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      // Sanitized time for Document ID (e.g. 10:00_AM)
      final String safeTime = time.replaceAll(RegExp(r'\s+'), '_');
      final String appointmentId = '${doctorId}_${dateStr}_$safeTime';
      
      final docRef = _firestore.collection('appointments').doc(appointmentId);

      // 2. Transaction to prevent Race Conditions (Double Bookings) with 1-Hour Expiration
      // Calculate Expiration time
      DateTime expiresAtDate = DateTime.now().add(const Duration(hours: 1));
      
      // 1.5 Fetch current patient details (including photoUrl)
      String? patientPhotoUrl;
      try {
        final patientDoc = await _firestore.collection('users').doc(patientId).get();
        if (patientDoc.exists) {
          patientPhotoUrl = patientDoc.data()?['photoUrl'];
        }
      } catch (e) {
        debugPrint('⚠️ Failed to fetch patient photoUrl: $e');
      }

      final appointmentData = {
        'doctorId': doctorId,
        'doctorUserId': doctorUserId.isNotEmpty ? doctorUserId : doctorId,
        'doctorName': doctorName,
        'specialty': specialty,
        'patientId': patientId,
        'patientName': patientName,
        'patientPhotoUrl': patientPhotoUrl, // Include photoUrl
        'date': dateStr,
        'time': time,
        'dateTime': Timestamp.fromDate(appointmentDateTime),
        'duration': 20,
        'type': 'new',
        'status': 'pending', // Pending to indicate unconfirmed
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAtDate), // Automatically cancel after 1 hour if not confirmed
      };

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          final data = snapshot.data();
          // If the slot is cancelled, we allow re-booking
          if (data != null && data['status'] == 'cancelled') {
            transaction.update(docRef, appointmentData);
          } else {
            // Slot is taken! Throw an exception to stop transaction
            throw Exception('عذراً، هذا الموعد تم حجزه للتو. يرجى اختيار موعد آخر.');
          }
        } else {
          // Normal booking creation
          transaction.set(docRef, appointmentData);
        }
      }).timeout(const Duration(seconds: 15));

      // 3. Trigger notification for the doctor
      await _triggerDoctorNotification(
        recipientId: doctorUserId.isNotEmpty ? doctorUserId : doctorId,
        patientName: patientName,
        appointmentId: appointmentId,
      );

      return appointmentId;
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

  /// Check if patient already has an appointment with a specific doctor on a given date
  Future<bool> hasAppointmentOnDate(String patientId, String doctorId, DateTime date) async {
    final String dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final snapshot = await _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isEqualTo: dateStr)
        .get()
        .timeout(const Duration(seconds: 10));

    // ONLY block if it's NOT cancelled, OR if it was cancelled by the doctor
    final activeAppointments = snapshot.docs.where((doc) {
      final data = doc.data();
      final status = data['status'];
      final cancelledBy = data['cancelledBy'];
      
      if (status == 'cancelled') {
        // Only block if explicitly cancelled by doctor. 
        // If it's cancelled by patient or unknown (old data), allow re-booking.
        return cancelledBy == 'doctor';
      }
      // Block for all other active statuses (pending, confirmed, accepted, etc.)
      return true;
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
      // 1. Handle notifications cleanup
      final notifs = await _firestore
          .collection('notifications')
          .where('appointmentId', isEqualTo: appointmentId)
          .get();
      
      for (var doc in notifs.docs) {
        await doc.reference.update({
          'status': 'read', 
          'type': 'cancelled_appointment',
          'body': 'تم إلغاء هذا الموعد بواسطة المريض',
        });
      }

      // 2. Update appointment status
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'cancelledBy': 'patient',
        'cancelReason': 'ألغيت من المريض',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
// debugPrint('✅ Appointment cancelled');
    } catch (e) {
// debugPrint('❌ Error cancelling appointment: $e');
      rethrow;
    }
  }

  /// Delete an appointment completely (patient side)
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      // 1. Delete associated notifications
      final notifs = await _firestore
          .collection('notifications')
          .where('appointmentId', isEqualTo: appointmentId)
          .get();
      
      for (var doc in notifs.docs) {
        await doc.reference.delete();
      }

      // 2. Delete the appointment itself
      await _firestore.collection('appointments').doc(appointmentId).delete();
// debugPrint('✅ Appointment deleted from Firestore');
    } catch (e) {
// debugPrint('❌ Error deleting appointment: $e');
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

  /// Get all appointments for a doctor
  Stream<List<Appointment>> getDoctorAppointments(String doctorUserId) {
    return _firestore
        .collection('appointments')
        .where('doctorUserId', isEqualTo: doctorUserId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Appointment.fromFirestore(doc))
              .toList();
        });
  }

  /// Accept an appointment (doctor side)
  Future<void> acceptAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error accepting appointment: $e');
      rethrow;
    }
  }

  /// Reject/Cancel an appointment (doctor side)
  Future<void> rejectAppointment(String appointmentId, {String? reason}) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'cancelledBy': 'doctor',
        'cancelReason': reason ?? 'Cancelled by doctor',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error rejecting appointment: $e');
      rethrow;
    }
  }
}
