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
    if (_useFirestore) {
      return await _firestoreService.getAllDoctors(category: category);
    } else {
      return await _sqliteDb.getDoctors(category: category);
    }
  }

  /// جلب دكتور معين
  /// في حالة SQLite، يستخدم ID المحلي
  /// في حالة Firestore، يستخدم Firebase UID
  Future<Doctor?> getDoctorById(String doctorId) async {
    if (_useFirestore) {
      return await _firestoreService.getDoctorById(doctorId);
    } else {
      // جلب من SQLite (يحتاج implementation)
      final doctors = await _sqliteDb.getDoctors();
      try {
        return doctors.firstWhere((d) => d.id == doctorId);
      } catch (e) {
        return null;
      }
    }
  }

  /// البحث عن دكاترة
  Future<List<Doctor>> searchDoctors(String keyword) async {
    if (_useFirestore) {
      return await _firestoreService.searchDoctors(keyword);
    } else {
      return await _sqliteDb.searchDoctors(keyword);
    }
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
