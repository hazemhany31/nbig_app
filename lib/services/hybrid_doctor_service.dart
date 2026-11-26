import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_cache_service.dart';
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

  /// جلب جميع الدكاترة مع Fallback تلقائي لـ SQLite في حال تعذر Firestore
  Future<List<Doctor>> getDoctors({String? category}) async {
    List<Doctor> doctors = [];
    if (_useFirestore) {
      try {
        if (category == null || category == 'All') {
          doctors = await DoctorCacheService().getDoctors();
        } else {
          doctors = await DoctorCacheService().getDoctorsByCategory(
              category, DoctorService.categoryKeywords);
        }
      } catch (_) {
        doctors = [];
      }
    }

    // استرجاع احتياطي تلقائي من قاعدة البيانات المحلية عند عدم توفر بيانات Firestore
    if (doctors.isEmpty) {
      try {
        doctors = await _sqliteDb.getDoctors(category: category);
      } catch (_) {
        doctors = [];
      }
    }

    // الدمج مع المفضلات المحلية بأمان
    try {
      final favIds = await _sqliteDb.getFavoriteIds();
      for (var doc in doctors) {
        doc.isFavorite = favIds.contains(doc.id);
      }
    } catch (_) {}

    return doctors;
  }

  /// جلب دكتور معين مع Fallback
  Future<Doctor?> getDoctorById(String doctorId) async {
    Doctor? doc;
    if (_useFirestore) {
      try {
        final doctors = await DoctorCacheService().getDoctors();
        doc = doctors.where((d) => d.id == doctorId).firstOrNull;
      } catch (_) {}
    }

    if (doc == null) {
      try {
        final doctors = await _sqliteDb.getDoctors();
        doc = doctors.where((d) => d.id == doctorId).firstOrNull;
      } catch (_) {}
    }

    if (doc != null) {
      try {
        final favIds = await _sqliteDb.getFavoriteIds();
        doc.isFavorite = favIds.contains(doc.id);
      } catch (_) {}
    }
    return doc;
  }

  /// البحث عن دكاترة مع Fallback
  Future<List<Doctor>> searchDoctors(String keyword) async {
    List<Doctor> doctors = [];
    if (_useFirestore) {
      try {
        doctors = await DoctorCacheService().searchDoctors(keyword);
      } catch (_) {
        doctors = [];
      }
    }

    if (doctors.isEmpty) {
      try {
        doctors = await _sqliteDb.searchDoctors(keyword);
      } catch (_) {
        doctors = [];
      }
    }

    try {
      final favIds = await _sqliteDb.getFavoriteIds();
      for (var doc in doctors) {
        doc.isFavorite = favIds.contains(doc.id);
      }
    } catch (_) {}

    return doctors;
  }

  /// جلب التخصصات المتاحة
  Future<List<String>> getSpecialties() async {
    List<Doctor> doctors = [];
    if (_useFirestore) {
      try {
        doctors = await DoctorCacheService().getDoctors();
      } catch (_) {
        doctors = [];
      }
    }

    if (doctors.isEmpty) {
      try {
        doctors = await _sqliteDb.getDoctors();
      } catch (_) {
        doctors = [];
      }
    }

    final specialties = doctors
        .map((d) => d.specialty)
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();
    specialties.sort();
    return specialties;
  }

  /// Stream للدكاترة (فقط عند استخدام Firestore)
  Stream<List<Doctor>>? getDoctorsStream({String? category}) {
    if (_useFirestore) {
      return _firestoreService.getDoctorsStream(category: category);
    }
    return null;
  }
}
