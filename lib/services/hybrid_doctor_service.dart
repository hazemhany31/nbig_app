import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';
import 'database_helper.dart';
import 'doctor_service.dart';

/// خدمة هجينة للتعامل مع الدكاترة
/// تدعم SQLite (الحالي) و Firestore (المستقبل)
class HybridDoctorService {
  final DatabaseHelper _sqliteDb = DatabaseHelper();
  final DoctorService _firestoreService = DoctorService();

  // Flag للتحكم في مصدر البيانات
  // true = Firestore (الافتراضي الآن لضمان المزامنة واشعارات الحجز)
  // false = SQLite
  bool _useFirestore = true;

  /// تفعيل أو تعطيل استخدام Firestore
  void setUseFirestore(bool use) {
    _useFirestore = use;
  }

  /// تحقق من وجود بيانات في Firestore
  Future<bool> isFirestoreDataAvailable() async {
    try {
      final docs = await FirebaseFirestore.instance
          .collection('doctors')
          .limit(1)
          .get();
      return docs.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// جلب جميع الدكاترة
  Future<List<Doctor>> getDoctors({String? category}) async {
    List<Doctor> doctors;
    if (_useFirestore) {
      doctors = await _firestoreService.getAllDoctors(category: category);
    } else {
      doctors = await _sqliteDb.getDoctors(category: category);
    }

    // الدمج مع المفضلات المحلية دائماً لضمان المزامنة
    final favIds = await _sqliteDb.getFavoriteIds();
    for (var doc in doctors) {
      doc.isFavorite = favIds.contains(doc.id);
    }
    return doctors;
  }

  /// جلب دكتور معين
  Future<Doctor?> getDoctorById(String doctorId) async {
    Doctor? doc;
    if (_useFirestore) {
      doc = await _firestoreService.getDoctorById(doctorId);
    } else {
      final doctors = await _sqliteDb.getDoctors();
      try {
        doc = doctors.firstWhere((d) => d.id == doctorId);
      } catch (e) {
        doc = null;
      }
    }

    if (doc != null) {
      final favIds = await _sqliteDb.getFavoriteIds();
      doc.isFavorite = favIds.contains(doc.id);
    }
    return doc;
  }

  /// البحث عن دكاترة
  Future<List<Doctor>> searchDoctors(String keyword) async {
    List<Doctor> doctors;
    if (_useFirestore) {
      doctors = await _firestoreService.searchDoctors(keyword);
    } else {
      doctors = await _sqliteDb.searchDoctors(keyword);
    }

    final favIds = await _sqliteDb.getFavoriteIds();
    for (var doc in doctors) {
      doc.isFavorite = favIds.contains(doc.id);
    }
    return doctors;
  }

  /// جلب التخصصات المتاحة
  Future<List<String>> getSpecialties() async {
    if (_useFirestore) {
      return await _firestoreService.getSpecialties();
    } else {
      // جلب من SQLite
      final doctors = await _sqliteDb.getDoctors();
      final specialties = doctors.map((d) => d.specialty).toSet().toList();
      specialties.sort();
      return specialties;
    }
  }

  /// Stream للدكاترة (فقط عند استخدام Firestore)
  Stream<List<Doctor>>? getDoctorsStream({String? category}) {
    if (_useFirestore) {
      return _firestoreService.getDoctorsStream(category: category);
    }
    return null;
  }
}
