import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';

/// خدمة cache ذكية للأطباء — تمنع جلب نفس البيانات من Firestore أكثر من مرة
/// تحتفظ بالبيانات في الذاكرة لمدة 5 دقائق، وبعدها تجلب من Firestore تلقائياً
class DoctorCacheService {
  // Singleton — نسخة واحدة فقط في التطبيق كله
  static final DoctorCacheService _instance = DoctorCacheService._internal();
  factory DoctorCacheService() => _instance;
  DoctorCacheService._internal();

  List<Doctor>? _cachedDoctors;
  DateTime? _lastFetch;

  /// مدة صلاحية الـ cache = 5 دقائق
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// هل البيانات في الـ cache لا تزال صالحة؟
  bool get _isCacheValid =>
      _cachedDoctors != null &&
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < _cacheDuration;

  /// جلب جميع الأطباء — من الـ cache أو من Firestore حسب الحاجة
  /// [forceRefresh] = true يجبر الجلب من Firestore حتى لو الـ cache صالح
  Future<List<Doctor>> getDoctors({bool forceRefresh = false}) async {
    // إرجاع البيانات من الـ cache إذا كانت صالحة
    if (!forceRefresh && _isCacheValid) {
      return List.unmodifiable(_cachedDoctors!);
    }

    // جلب من Firestore مرة واحدة فقط
    final snapshot =
        await FirebaseFirestore.instance.collection('doctors').get(
      // الاستفادة من الـ offline cache الخاص بـ Firestore إذا كانت الشبكة بطيئة
      const GetOptions(source: Source.serverAndCache),
    );

    _cachedDoctors = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['doctorId'] = doc.id;
      data['userId'] = data['userId'] ?? doc.id;
      return Doctor.fromMap(data);
    }).toList();

    _lastFetch = DateTime.now();
    return List.unmodifiable(_cachedDoctors!);
  }

  /// البحث المحلي في الـ cache (بدون أي Firestore call)
  Future<List<Doctor>> searchDoctors(String keyword) async {
    final doctors = await getDoctors();
    final searchLower = keyword.trim().toLowerCase();
    if (searchLower.isEmpty) return doctors;

    return doctors.where((doc) {
      return doc.name.toLowerCase().contains(searchLower) ||
          doc.nameAr.toLowerCase().contains(searchLower) ||
          doc.specialty.toLowerCase().contains(searchLower) ||
          doc.specialtyAr.toLowerCase().contains(searchLower);
    }).toList();
  }

  /// جلب أطباء حسب التخصص (فلترة محلية)
  Future<List<Doctor>> getDoctorsByCategory(
    String category,
    Map<String, List<String>> categoryKeywords,
  ) async {
    final doctors = await getDoctors();
    if (category == 'All') return doctors;

    final keywords = categoryKeywords[category] ?? [category];
    return doctors.where((doc) {
      return keywords.any((k) =>
          doc.specialty.toLowerCase().contains(k.toLowerCase()) ||
          doc.specialtyAr.toLowerCase().contains(k.toLowerCase()));
    }).toList();
  }

  /// إبطال الـ cache (عند الإضافة أو التعديل)
  void invalidate() {
    _cachedDoctors = null;
    _lastFetch = null;
  }

  /// تحديث cache بعد التعديل بدون Firestore call جديد
  void updateDoctorInCache(String doctorId, Map<String, dynamic> updates) {
    if (_cachedDoctors == null) return;
    final idx = _cachedDoctors!.indexWhere((d) => d.id == doctorId);
    if (idx == -1) return;

    final existing = _cachedDoctors![idx];
    final updatedData = existing.toMap()..addAll(updates);
    _cachedDoctors![idx] = Doctor.fromMap(updatedData);
  }
}
