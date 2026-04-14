import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';

/// خدمة إدارة بيانات الدكاترة من Firestore
class DoctorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Map from English UI category keyword → all possible values in Firebase
  /// (doctor_app saves new doctors in English, old ones may have Arabic)
  static const Map<String, List<String>> categoryKeywords = {
    'All':        [],
    'Cardio':     ['Cardiology', 'قلب'],
    'Dermatology':['Dermatology', 'جلدية', 'جلدية وتجميل', 'Cosmetology'],
    'Neurology':  ['Neurology', 'مخ وأعصاب', 'Neurosurgery', 'جراحة مخ'],
    'Orthopedics':['Orthopedics', 'عظام', 'طب بشري عظام'],
    'Pediatric':  ['Pediatrics', 'أطفال', 'اطفال'],
    'Dent':       ['Dentistry', 'أسنان', 'اسنان', 'Dent'],
    'Ophthalmology':['Ophthalmology', 'عيون', 'رمد', 'طب وجراحة عيون'],
    'Internal Medicine': ['Internal Medicine', 'باطنة', 'بشري', 'طب بشري', 'General Practice', 'General Medicine'],
    'Obstetrics & Gynecology': ['Obstetrics & Gynecology', 'نساء وتوليد'],
    'General Surgery': ['General Surgery', 'جراحة عامة', 'Surgery', 'جراحة'],
    'ENT': ['ENT', 'أنف وأذن وحنجرة', 'اخصائي انف واذن', 'انف واذن'],
    'Psychiatry': ['Psychiatry', 'نفسية'],
    'Urology': ['Urology', 'مسالك بولية'],
    'Physical Therapy': ['Physical Therapy', 'علاج طبيعي', 'Physiotherapy'],
    'Radiology': ['Radiology', 'أشعة'],
    'Nutrition': ['Nutrition', 'تغذية'],
    'Other': ['Other', 'أخرى'],
  };

  /// جلب جميع الدكاترة
  Future<List<Doctor>> getAllDoctors({String? category}) async {
    try {
      final snapshot = await _firestore.collection('doctors').get();

      return snapshot.docs.where((doc) {
        if (category == null || category == 'All') return true;
        
        final data = doc.data();
        final spec = (data['specialization'] ?? data['speciality'] ?? data['specialty'] ?? '').toString();
        final keywords = categoryKeywords[category] ?? [category];
        
        return keywords.any((k) => spec.toLowerCase().contains(k.toLowerCase()));
      }).map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['doctorId'] = doc.id;
        data['userId'] = data['userId'] ?? doc.id; // Map userId explicitly
        return Doctor.fromMap(data);
      }).toList();
    } catch (e) {
// debugPrint('❌ خطأ في جلب الدكاترة: $e');
      return [];
    }
  }

  /// جلب ملف الدكتور من `doctors` باستخدام `userId` = Firebase Auth UID (لجلسة الطبيب)
  Future<Doctor?> getDoctorByFirebaseAuthUid(String firebaseAuthUid) async {
    try {
      final q = await _firestore
          .collection('doctors')
          .where('userId', isEqualTo: firebaseAuthUid)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      final doc = q.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      data['doctorId'] = doc.id;
      data['userId'] = data['userId'] ?? doc.id;
      return Doctor.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  /// جلب دكتور معين بـ Firebase UID
  Future<Doctor?> getDoctorById(String doctorId) async {
    try {
      final doc = await _firestore.collection('doctors').doc(doctorId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      data['doctorId'] = doc.id;
      data['userId'] = data['userId'] ?? doc.id;
      return Doctor.fromMap(data);
    } catch (e) {
// debugPrint('❌ خطأ في جلب الدكتور: $e');
      return null;
    }
  }

  /// البحث عن دكاترة
  Future<List<Doctor>> searchDoctors(String keyword) async {
    try {
      // البحث في الاسم أو التخصص
      final snapshot = await _firestore.collection('doctors').get();

      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString().toLowerCase();
            final nameAr = (data['nameAr'] ?? data['arName'] ?? '').toString().toLowerCase();
            final specialty = (data['specialization'] ?? data['speciality'] ?? data['specialty'] ?? '')
                .toString()
                .toLowerCase();
            final specialtyAr = (data['specialtyAr'] ?? data['arSpeciality'] ?? data['specializationAr'] ?? '')
                .toString()
                .toLowerCase();
            final searchLower = keyword.toLowerCase();

            return name.contains(searchLower) ||
                nameAr.contains(searchLower) ||
                specialty.contains(searchLower) ||
                specialtyAr.contains(searchLower);
          })
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['doctorId'] = doc.id;
            data['userId'] = data['userId'] ?? doc.id;
            return Doctor.fromMap(data);
          })
          .toList();
    } catch (e) {
// debugPrint('❌ خطأ في البحث: $e');
      return [];
    }
  }

  /// جلب التخصصات المتاحة
  Future<List<String>> getSpecialties() async {
    try {
      final snapshot = await _firestore.collection('doctors').get();

      final specialties = <String>{};
      for (var doc in snapshot.docs) {
        final specialty = doc.data()['specialty'];
        if (specialty != null) {
          specialties.add(specialty.toString());
        }
      }

      return specialties.toList()..sort();
    } catch (e) {
// debugPrint('❌ خطأ في جلب التخصصات: $e');
      return [];
    }
  }

  /// Stream لمتابعة تحديثات الدكاترة في الوقت الفعلي
  Stream<List<Doctor>> getDoctorsStream({String? category}) {
    Query<Map<String, dynamic>> query = _firestore.collection('doctors');

    if (category != null && category != 'All') {
      query = query.where('specialty', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['doctorId'] = doc.id;
        data['userId'] = data['userId'] ?? doc.id;
        return Doctor.fromMap(data);
      }).toList();
    });
  }

  /// إضافة دكتور جديد (للإدارة)
  /// يستخدم Firebase Auth UID كـ document ID
  Future<void> addDoctor(
    String firebaseUid,
    Map<String, dynamic> doctorData,
  ) async {
    try {
      await _firestore.collection('doctors').doc(firebaseUid).set(doctorData);
    } catch (e) {
// debugPrint('❌ خطأ في إضافة الدكتور: $e');
      rethrow;
    }
  }

  /// تحديث بيانات دكتور
  Future<void> updateDoctor(
    String doctorId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).update(updates);
    } catch (e) {
// debugPrint('❌ خطأ في تحديث الدكتور: $e');
      rethrow;
    }
  }

  /// تحديث تقييم الدكتور
  Future<void> rateDoctor(String doctorId, double newRatingValue) async {
    try {
      final docRef = _firestore.collection('doctors').doc(doctorId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final currentRating = double.tryParse(data['rating']?.toString() ?? '0') ?? 0.0;
        final currentReviews = (data['reviews'] as num?)?.toInt() ?? 0;

        final totalRating = currentRating * currentReviews;
        final updatedReviews = currentReviews + 1;
        final updatedRating = (totalRating + newRatingValue) / updatedReviews;

        transaction.update(docRef, {
          'rating': updatedRating.toStringAsFixed(1),
          'reviews': updatedReviews,
        });
      });
    } catch (e) {
// debugPrint('❌ خطأ في تقييم الدكتور: $e');
      rethrow;
    }
  }
}
