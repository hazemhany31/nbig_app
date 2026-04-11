import 'package:cloud_firestore/cloud_firestore.dart';

/// Medication model for prescriptions
class Prescription {
  final String medicineName;
  final String dosage;
  final String frequency;
  final int? frequencyHours; // e.g., 8 for "Every 8 hours"
  final String duration;
  final String? instructions;
  final DateTime? reminderTime;
  final bool isTaken;

  Prescription({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    this.frequencyHours,
    required this.duration,
    this.instructions,
    this.reminderTime,
    this.isTaken = false,
  });

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      medicineName: map['medicineName'] ?? map['name'] ?? map['medicine_name'] ?? map['medicine'] ?? '',
      dosage: map['dosage'] ?? map['dose'] ?? '',
      frequency: map['frequency'] ?? map['freq'] ?? '',
      frequencyHours: (map['frequencyHours'] ?? map['freqHours']) is int ? (map['frequencyHours'] ?? map['freqHours']) : null,
      duration: map['duration'] ?? map['period'] ?? '',
      instructions: map['instructions'] ?? map['notes'] ?? map['desc'] ?? '',
      reminderTime: map['reminderTime'] != null
          ? (map['reminderTime'] as Timestamp).toDate()
          : null,
      isTaken: map['isTaken'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'frequencyHours': frequencyHours,
      'duration': duration,
      'instructions': instructions,
      'reminderTime': reminderTime != null ? Timestamp.fromDate(reminderTime!) : null,
      'isTaken': isTaken,
    };
  }
}

/// Appointment model representing a patient's appointment with a doctor
class Appointment {
  final String id;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final String patientId;
  final String patientName;
  final DateTime dateTime; // Combined date + time
  final int duration; // Duration in minutes
  final String type; // Type: new, followup
  final String status; // pending, confirmed, cancelled, completed
  final DateTime? createdAt;
  final String? cancelReason;
  final String? cancelledBy; // patient, doctor
  final List<Prescription>? prescriptions;
  final DateTime? medicationReminderTime;
  final String? doctorNotes;

  Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.patientId,
    required this.patientName,
    required this.dateTime,
    this.duration = 20,
    this.type = 'new',
    this.status = 'pending',
    this.createdAt,
    this.cancelReason,
    this.cancelledBy,
    this.prescriptions,
    this.medicationReminderTime,
    this.doctorNotes,
  });

  /// Create Appointment from Firestore document
  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      specialty: data['specialty'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      duration: data['duration'] ?? 20,
      type: data['type'] ?? 'new',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      cancelReason: data['cancelReason'],
      cancelledBy: data['cancelledBy'],
      prescriptions: data['prescriptions'] != null
          ? (data['prescriptions'] as List<dynamic>)
              .map((e) => Prescription.fromMap(e as Map<String, dynamic>))
              .toList()
          : null,
      medicationReminderTime: data['medicationReminderTime'] != null
          ? (data['medicationReminderTime'] as Timestamp).toDate()
          : null,
      doctorNotes: data['doctorNotes'],
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'patientId': patientId,
      'patientName': patientName,
      'dateTime': Timestamp.fromDate(dateTime),
      'duration': duration,
      'type': type,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'cancelReason': cancelReason,
      'cancelledBy': cancelledBy,
      'prescriptions': prescriptions?.map((e) => e.toMap()).toList(),
      'medicationReminderTime': medicationReminderTime != null
          ? Timestamp.fromDate(medicationReminderTime!)
          : null,
      'doctorNotes': doctorNotes,
    };
  }

  /// Get status in Arabic
  String get statusAr {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'مؤكد';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  /// Check if appointment is in the future
  bool get isFuture {
    return dateTime.isAfter(DateTime.now());
  }

  /// Check if appointment is today
  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// Get formatted time
  String get formattedTime {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}
