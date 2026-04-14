import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicationTrackingService {
  static final MedicationTrackingService _instance =
      MedicationTrackingService._internal();
  factory MedicationTrackingService() => _instance;
  MedicationTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String getDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  /// Toggle a specific dose time as taken or not-taken for today.
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

    final String dateKey = getDateKey(date);
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

    final String dateKey = getDateKey(date);
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

  /// Stream of the full appointment document (used to extract tracking data).
  Stream<DocumentSnapshot> getTrackingStream(String appointmentId) {
    return _firestore.collection('appointments').doc(appointmentId).snapshots();
  }

  /// Extract the list of taken dose-times for a specific med+date from a snapshot.
  List<String> getTakenDoses({
    required DocumentSnapshot snapshot,
    required String medicineName,
    required DateTime date,
  }) {
    final dateKey = getDateKey(date);
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return [];
    final tracker = data['medicationTracker'] as Map<String, dynamic>?;
    if (tracker == null) return [];
    final dayData = tracker[dateKey] as Map<String, dynamic>?;
    if (dayData == null) return [];
    final medData = dayData[medicineName] as Map<String, dynamic>?;
    if (medData == null) return [];
    final taken = medData['takenDoses'];
    if (taken == null) return [];
    return List<String>.from(taken as List);
  }
  int extractNumber(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : 1; // Default to 1 if no number
  }

  int getDosesPerDay(String frequency, int? frequencyHours) {
    int intervalHours = 24;
    if (frequencyHours != null && frequencyHours > 0) {
      intervalHours = frequencyHours;
    } else {
      final count = extractNumber(frequency);
      if (count > 0) intervalHours = 24 ~/ count;
    }
    return 24 ~/ intervalHours;
  }

  Future<Map<String, dynamic>> calculateStreakAndAnalytics(List<dynamic> appointments) async {
    int streak = 0;
    List<double> weeklyAdherence = List.filled(7, 0.0);
    List<double> monthlyAdherence = List.filled(30, 0.0);
    int todayDosesLeft = 0;
    int todayTotalDoses = 0;
    bool allCompletedToday = false;

    if (appointments.isEmpty) {
      return {
        'streak': 0,
        'weekly': weeklyAdherence,
        'monthly': monthlyAdherence,
        'todayLeft': 0,
        'todayTotal': 0,
        'allCompleted': false,
      };
    }

    // Map to store {dateKey: {taken: int, total: int}}
    Map<String, Map<String, int>> history = {};
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    String todayKey = getDateKey(today);
    
    DateTime? earliestDate;

    // 1. Process all appointments to build history
    for (var appt in appointments) {
      // Find earliest date
      if (earliestDate == null || appt.dateTime.isBefore(earliestDate)) {
        earliestDate = appt.dateTime;
      }

      final tracker = appt.medicationTracker as Map<String, dynamic>?;
      if (tracker == null) continue;

      for (var dateKey in tracker.keys) {
        if (dateKey == 'lastUpdated' || dateKey == 'permanentDismissals') continue;

        final dayData = tracker[dateKey] as Map<String, dynamic>?;
        if (dayData == null) continue;

        int dayTaken = 0;
        int dayTotal = 0;

        for (var medName in dayData.keys) {
          final medInfo = dayData[medName] as Map<String, dynamic>?;
          if (medInfo == null) continue;

          final takenArr = medInfo['takenDoses'] as List<dynamic>? ?? [];
          dayTaken += takenArr.length;
          
          final total = medInfo['totalDoses'] as int? ?? 0;
          dayTotal += total;
        }

        if (!history.containsKey(dateKey)) {
          history[dateKey] = {'taken': 0, 'total': 0};
        }
        history[dateKey]!['taken'] = (history[dateKey]!['taken'] ?? 0) + dayTaken;
        history[dateKey]!['total'] = (history[dateKey]!['total'] ?? 0) + dayTotal;
      }
    }

    // 2. Determine today's requirements from active prescriptions
    for (var appt in appointments) {
      if (appt.prescriptions != null) {
        for (var p in appt.prescriptions!) {
          todayTotalDoses += getDosesPerDay(p.frequency, p.frequencyHours);
        }
      }
    }

    int takenToday = history.containsKey(todayKey) ? (history[todayKey]!['taken'] ?? 0) : 0;
    todayDosesLeft = (todayTotalDoses - takenToday).clamp(0, 999);
    allCompletedToday = (todayTotalDoses > 0 && takenToday >= todayTotalDoses);

    // 3. Calculate streak
    // Start from today if it's already completed
    DateTime checkDate = today;
    bool streakOngoing = true;
    
    // If today is completed, we start streak at 1
    if (allCompletedToday) {
      streak = 1;
      checkDate = today.subtract(const Duration(days: 1));
    } else {
      // If today is not completed yet, we look at yesterday
      streak = 0;
      checkDate = today.subtract(const Duration(days: 1));
    }

    DateTime limitDate = earliestDate != null 
        ? DateTime(earliestDate.year, earliestDate.month, earliestDate.day)
        : today.subtract(const Duration(days: 30));

    while (streakOngoing) {
      // Stop if we go before the earliest prescription
      if (checkDate.isBefore(limitDate)) break;

      String key = getDateKey(checkDate);
      if (history.containsKey(key)) {
        int taken = history[key]!['taken'] ?? 0;
        int total = history[key]!['total'] ?? 0;

        if (total > 0) {
          if (taken >= total) {
            streak++;
          } else {
            // Missed a day with meds
            streakOngoing = false;
          }
        } else {
          // No meds this day, skip it without breaking or incrementing streak
        }
      } else {
        // No data recorded for this day. 
        // If we expect meds today, it breaks. But we don't know the exact prescriptions for past days easily.
        // For simplicity: if no meds were prescribed today (total=0), it doesn't break.
        // However, we don't have historical 'total' info if the user never clicked anything.
        // Assuming no entry means 0 doses for now, BUT if we find a day with data later, we continue.
        // Change: If we have NO data for a day, let's assume it was a rest day (don't break).
        // BUT if it's within the duration of an appointment, it should probably break.
        // Let's stick to: skip untracked days unless we find a missed day.
      }
      
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (streak > 365) break; 
    }

    // 4. Populate weekly and monthly adherence
    for (int i = 0; i < 7; i++) {
      DateTime d = today.subtract(Duration(days: 6 - i));
      String key = getDateKey(d);
      if (history.containsKey(key)) {
        int taken = history[key]!['taken'] ?? 0;
        int total = history[key]!['total'] ?? 0;
        weeklyAdherence[i] = total > 0 ? (taken / total) : 0.0;
      }
    }
    
    for (int i = 0; i < 30; i++) {
      DateTime d = today.subtract(Duration(days: 29 - i));
      String key = getDateKey(d);
      if (history.containsKey(key)) {
        int taken = history[key]!['taken'] ?? 0;
        int total = history[key]!['total'] ?? 0;
        monthlyAdherence[i] = total > 0 ? (taken / total) : 0.0;
      }
    }

    return {
      'streak': streak,
      'weekly': weeklyAdherence,
      'monthly': monthlyAdherence,
      'todayLeft': todayDosesLeft,
      'todayTotal': todayTotalDoses,
      'allCompleted': allCompletedToday,
    };
  }
}
