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
  ) async {
    final db = await database;
    if (db == null) return;
    await db.insert('UserAppointments', {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'date': date,
      'time': time,
      'status': 'upcoming',
      'firestoreId': firestoreId,
    });
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
      {'status': 'canceled'},
      where: 'id = ?',
      whereArgs: [id],
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

  Future<List<String>> getBookedTimes(String doctorName, String date) async {
    final db = await database;
    if (db == null) return [];
    final result = await db.query(
      'UserAppointments',
      columns: ['time'],
      where: 'doctorName = ? AND date = ? AND status != ?',
      whereArgs: [doctorName, date, 'canceled'],
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
