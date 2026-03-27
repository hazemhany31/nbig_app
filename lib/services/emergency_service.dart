import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing emergency alerts
class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send an emergency alert - finds nearest available ONLINE doctor and creates alert.
  /// Returns {'noDoctor': true} if no online doctor is available (alert is NOT created).
  Future<Map<String, dynamic>> sendEmergencyAlert({
    required String patientId,
    required String patientName,
    String? description,
  }) async {
    try {
      // --- DAILY LIMIT CHECK: 2 alerts per day (Robust Dart filtering) ---
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final allUserAlerts = await _firestore
          .collection('emergency_alerts')
          .where('patientId', isEqualTo: patientId)
          .get()
          .timeout(const Duration(seconds: 10));

      // Filter in Dart to avoid index issues and ensure reliability
      final todayAlerts = allUserAlerts.docs.where((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return true; // Count pending/new docs too
        final date = createdAt.toDate();
        return date.year == now.year && date.month == now.month && date.day == now.day;
      }).toList();

      if (todayAlerts.length >= 2) {
// debugPrint('⚠️ Daily alert limit reached for patient: $patientName (Count: ${todayAlerts.length})');
        return {'limitReached': true};
      }

      // Only assign an online doctor
      final doctor = await getNearestAvailableDoctor();

      // No online doctor → do NOT create the alert, return a special flag
      if (doctor == null) {
// debugPrint('⚠️ No online doctor found — alert not created');
        return {'noDoctor': true};
      }

      final expiresAt = DateTime.now().add(const Duration(minutes: 5));

      final alertData = {
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctor['id'] ?? '',
        'doctorUserId': doctor['userId'] ?? doctor['id'] ?? '',
        'doctorName': doctor['name'] ?? doctor['nameAr'] ?? '',
        'doctorSpecialty': doctor['specialty'] ?? '',
        'doctorPhone': doctor['phone'] ?? '',
        'description': description ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      };

      final docRef = await _firestore
          .collection('emergency_alerts')
          .add(alertData)
          .timeout(const Duration(seconds: 15));

// debugPrint('✅ Emergency alert created: ${docRef.id}');

      return {
        'alertId': docRef.id,
        'doctorId': doctor['id'] ?? '',
        'doctorUserId': doctor['userId'] ?? doctor['id'] ?? '',
        'doctorName': doctor['nameAr'] ?? doctor['name'] ?? '',
        'doctorSpecialty': doctor['specialtyAr'] ?? doctor['specialty'] ?? '',
        'doctorPhone': doctor['phone'] ?? '',
        'expiresAt': expiresAt,
      };
    } catch (e) {
// debugPrint('❌ Error sending emergency alert: $e');
      rethrow;
    }
  }

  /// Get the first available ONLINE doctor only. Returns null if none are online.
  Future<Map<String, dynamic>?> getNearestAvailableDoctor() async {
    try {
      final onlineQuery = await _firestore
          .collection('doctors')
          .where('isOnline', isEqualTo: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (onlineQuery.docs.isNotEmpty) {
        final data = onlineQuery.docs.first.data();
        data['id'] = onlineQuery.docs.first.id;
        data['userId'] = data['userId'] ?? onlineQuery.docs.first.id;
        return data;
      }

      // No online doctor found
      return null;
    } catch (e) {
// debugPrint('❌ Error finding online doctor: $e');
      return null;
    }
  }

  /// Cancel an emergency alert
  Future<void> cancelAlert(String alertId) async {
    try {
      await _firestore.collection('emergency_alerts').doc(alertId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
// debugPrint('✅ Emergency alert cancelled: $alertId');
    } catch (e) {
// debugPrint('❌ Error cancelling alert: $e');
      rethrow;
    }
  }

  /// Mark alert as acknowledged by doctor
  Future<void> acknowledgeAlert(String alertId) async {
    try {
      await _firestore.collection('emergency_alerts').doc(alertId).update({
        'status': 'acknowledged',
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
// debugPrint('❌ Error acknowledging alert: $e');
    }
  }

  /// Stream a specific alert to listen for doctor acknowledgement
  Stream<DocumentSnapshot> watchAlert(String alertId) {
    return _firestore.collection('emergency_alerts').doc(alertId).snapshots();
  }
}
