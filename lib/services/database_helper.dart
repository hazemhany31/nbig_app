import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/doctor_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  static Database? _database;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) return null;
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "app_database_final.db");
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      ByteData data = await rootBundle.load(join("assets", "app_database.db"));
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(path).writeAsBytes(bytes, flush: true);
    }
    var db = await openDatabase(path, readOnly: false);
    await db.execute(
      'CREATE TABLE IF NOT EXISTS UserAppointments (id INTEGER PRIMARY KEY AUTOINCREMENT, doctorName TEXT, specialty TEXT, date TEXT, time TEXT, status TEXT)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS UserFavorites (doctorId TEXT PRIMARY KEY)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS Messages (id INTEGER PRIMARY KEY AUTOINCREMENT, doctorName TEXT, text TEXT, isMe INTEGER, timestamp TEXT, attachmentPath TEXT, attachmentType TEXT)',
    );

    // Migration logic simple
    try {
      await db.execute('ALTER TABLE Messages ADD COLUMN attachmentPath TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE Messages ADD COLUMN attachmentType TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE UserAppointments ADD COLUMN doctorId TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE UserAppointments ADD COLUMN isRated INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE UserAppointments ADD COLUMN firestoreId TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE UserAppointments ADD COLUMN isAcknowledged INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE UserAppointments ADD COLUMN cancelledBy TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE UserAppointments ADD COLUMN expiresAt TEXT');
    } catch (_) {}

    return db;
  }

  // === 1. جلب الدكاترة (بالعربي والإنجليزي) ===
  Future<List<Doctor>> getDoctors({String? category}) async {
    final db = await database;
    if (db == null) return [];
    final favList = await db.query('UserFavorites');
    final favIds = favList.map((e) => e['doctorId'].toString()).toSet();

    List<Map<String, dynamic>> maps;
    if (category == null || category == 'All') {
      maps = await db.query('DoctorV2', orderBy: "name ASC");
    } else {
      maps = await db.query(
        'DoctorV2',
        where: 'speciality LIKE ?',
        whereArgs: ['%$category%'],
        orderBy: "name ASC",
      );
    }

    return List.generate(maps.length, (i) {
      var doc = Doctor.fromMap(maps[i]);
      doc.isFavorite = favIds.contains(doc.id);
      return doc;
    });
  }

  Future<bool> toggleFavorite(String doctorId) async {
    final db = await database;
    if (db == null) return false;
    final maps = await db.query(
      'UserFavorites',
      where: 'doctorId = ?',
      whereArgs: [doctorId],
    );
    if (maps.isEmpty) {
      await db.insert('UserFavorites', {'doctorId': doctorId});
      return true;
    } else {
      await db.delete(
        'UserFavorites',
        where: 'doctorId = ?',
        whereArgs: [doctorId],
      );
      return false;
    }
  }

  Future<Set<String>> getFavoriteIds() async {
    final db = await database;
    if (db == null) return {};
    final favList = await db.query('UserFavorites');
    return favList.map((e) => e['doctorId'].toString()).toSet();
  }

  Future<List<Doctor>> searchDoctors(String keyword) async {
    final db = await database;
    if (db == null) return [];
    final List<Map<String, dynamic>> maps = await db.query(
      'DoctorV2',
      where: 'name LIKE ? OR speciality LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: "name ASC",
    );
    return List.generate(maps.length, (i) => Doctor.fromMap(maps[i]));
  }

  // === حذف وإضافة دكاترة (للأدمن أو التحديث) ===
  Future<void> recreateDoctorsTable() async {
    final db = await database;
    if (db == null) return;
    await db.execute('DROP TABLE IF EXISTS DoctorV2');
    await db.execute('''
      CREATE TABLE DoctorV2 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        arName TEXT,
        speciality TEXT,
        arSpeciality TEXT,
        rating TEXT,
        image TEXT,
        introduction TEXT,
        arIntroduction TEXT,
        reviews TEXT,
        gender TEXT
      )
    ''');
  }

  Future<void> insertDoctor(Map<String, dynamic> doctorData) async {
    final db = await database;
    if (db == null) return;
    await db.insert('DoctorV2', doctorData);
  }

  Future<void> addAppointment(
    String doctorId,
    String doctorName,
    String specialty,
    String date,
    String time,
    String? firestoreId,
    {String? expiresAt}
  ) async {
    final db = await database;
    if (db == null) return;
    
    // Check if appointment already exists (non-cancelled)
    if (await hasLocalAppointment(doctorId, date, time)) {
      debugPrint('⚠️ Duplicate local appointment ignored: $doctorName at $time on $date');
      return;
    }

    await db.insert('UserAppointments', {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'date': date,
      'time': time,
      'status': 'pending',
      'firestoreId': firestoreId,
      'expiresAt': expiresAt,
    });
  }

  Future<bool> hasLocalAppointment(String doctorId, String date, [String? time]) async {
    final db = await database;
    if (db == null) return false;
    
    // Check for any appointment on this date (day-locking rule)
    final maps = await db.query(
      'UserAppointments',
      where: 'doctorId = ? AND date = ?',
      whereArgs: [doctorId, date],
    );
    
    for (var m in maps) {
      final status = m['status'] as String?;
      final cancelledBy = m['cancelledBy'] as String?;
      
      if (status == 'cancelled' && cancelledBy == 'patient') {
        continue; // Don't block if patient cancelled
      }
      return true; // Found an active or doctor-cancelled appointment, which blocks the day
    }
    
    return false;
  }

  Future<List<Map<String, dynamic>>> getAppointments(String status) async {
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'UserAppointments',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: "id DESC",
    );
  }

  Future<int> cancelAppointment(int id) async {
    final db = await database;
    if (db == null) return -1;
    return await db.update(
      'UserAppointments',
      {'status': 'cancelled', 'cancelledBy': 'patient', 'isAcknowledged': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getAppointmentById(int id) async {
    final db = await database;
    if (db == null) return null;
    final results = await db.query(
      'UserAppointments',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> acknowledgeCancellations() async {
    final db = await database;
    if (db == null) return -1;
    return await db.update(
      'UserAppointments',
      {'isAcknowledged': 1},
      where: 'status = ? AND isAcknowledged = ?',
      whereArgs: ['cancelled', 0],
    );
  }

  Future<int> cleanupOldCancellations() async {
    final db = await database;
    if (db == null) return -1;
    final String todayStr = DateTime.now().toIso8601String().split('T')[0];
    return await db.delete(
      'UserAppointments',
      where: 'status = ? AND date < ?',
      whereArgs: ['cancelled', todayStr],
    );
  }

  Future<int> completeAppointment(int id) async {
    final db = await database;
    if (db == null) return -1;
    return await db.update(
      'UserAppointments',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAppointment(int id) async {
    final db = await database;
    if (db == null) return -1;
    return await db.delete(
      'UserAppointments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deduplicateAppointments() async {
    final db = await database;
    if (db == null) return;
    
    // Simple deduplication logic: keep the record with the largest ID (most recent)
    // for each unique doctorId, date, time combination where status is the same.
    try {
      await db.execute('''
        DELETE FROM UserAppointments 
        WHERE id NOT IN (
          SELECT MAX(id) 
          FROM UserAppointments 
          GROUP BY doctorId, date, time, status
        )
      ''');
      debugPrint('✅ Database deduplication complete');
    } catch (e) {
       debugPrint('❌ Error deduplicating appointments: $e');
    }
  }

  /// Returns all firestoreIds of appointments that are still active (pending/confirmed/accepted)
  Future<List<String>> getAllActiveFirestoreIds() async {
    final db = await database;
    if (db == null) return [];
    final results = await db.query(
      'UserAppointments',
      columns: ['firestoreId'],
      where: "firestoreId IS NOT NULL AND status IN ('pending', 'confirmed', 'accepted')",
    );
    return results
        .map((e) => e['firestoreId'] as String)
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<int> deleteAllAppointments() async {
    final db = await database;
    if (db == null) return -1;
    return await db.delete('UserAppointments');
  }

  Future<int> markAppointmentAsRated(int id) async {
    final db = await database;
    if (db == null) return -1;
    return await db.update(
      'UserAppointments',
      {'isRated': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateAppointmentStatusByFirestoreId(String firestoreId, String status, {String? cancelledBy}) async {
    final db = await database;
    if (db == null) return -1;
    return await db.update(
      'UserAppointments',
      {
        'status': status, 
        'isAcknowledged': status == 'cancelled' ? 0 : 1,
        'cancelledBy': cancelledBy ?? (status == 'cancelled' ? 'doctor' : null),
      },
      where: 'firestoreId = ?',
      whereArgs: [firestoreId],
    );
  }

  Future<List<String>> getBookedTimes(String doctorName, String date) async {
    final db = await database;
    if (db == null) return [];
    final result = await db.query(
      'UserAppointments',
      columns: ['time'],
      where: 'doctorName = ? AND date = ? AND status != ?',
      whereArgs: [doctorName, date, 'cancelled'],
    );
    return result.map((e) => e['time'] as String).toList();
  }

  // تعديل لحفظ الرسالة مع المرفقات
  Future<void> saveMessage(
    String doctorName,
    String text,
    bool isMe, {
    String? attachmentPath,
    String? attachmentType,
  }) async {
    final db = await database;
    if (db == null) return;
    final timestamp = DateTime.now().toIso8601String();
    await db.insert('Messages', {
      'doctorName': doctorName,
      'text': text,
      'isMe': isMe ? 1 : 0,
      'timestamp': timestamp,
      'attachmentPath': attachmentPath,
      'attachmentType': attachmentType,
    });
  }

  Future<List<Map<String, dynamic>>> getMessages(String doctorName) async {
    final db = await database;
    if (db == null) return [];
    try {
      final result = await db.query(
        'Messages',
        where: 'doctorName = ?',
        whereArgs: [doctorName],
        orderBy: 'timestamp ASC',
      );
      return result;
    } catch (e) {
      return [];
    }
  }
}
