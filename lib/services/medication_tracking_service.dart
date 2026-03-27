import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicationTrackingService {
  static final MedicationTrackingService _instance = MedicationTrackingService._internal();
  factory MedicationTrackingService() => _instance;
  MedicationTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> toggleDoseTaken({
    required String appointmentId,
    required String medicineName,
    required String doseTime,
    required DateTime date,
    required bool taken,
    required int totalDoses,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final String dateKey = _getDateKey(date);
    final String trackerPath = 'medicationTracker.$dateKey.$medicineName';

    if (taken) {
      await _firestore.collection('appointments').doc(appointmentId).update({
        '$trackerPath.takenDoses': FieldValue.arrayUnion([doseTime]),
        '$trackerPath.totalDoses': totalDoses,
        '$trackerPath.lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('appointments').doc(appointmentId).update({
        '$trackerPath.takenDoses': FieldValue.arrayRemove([doseTime]),
        '$trackerPath.lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> dismissMedicineForDay({
    required String appointmentId,
    required String medicineName,
    required DateTime date,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final String dateKey = _getDateKey(date);
    final String trackerPath = 'medicationTracker.$dateKey.$medicineName';

    await _firestore.collection('appointments').doc(appointmentId).update({
      '$trackerPath.isDismissed': true,
      '$trackerPath.lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> permanentlyDismissMedicine({
    required String appointmentId,
    required String medicineName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('appointments').doc(appointmentId).update({
      'medicationTracker.permanentDismissals.$medicineName': true,
      'medicationTracker.lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot> getTrackingStream(String appointmentId) {
    return _firestore.collection('appointments').doc(appointmentId).snapshots();
  }
}
