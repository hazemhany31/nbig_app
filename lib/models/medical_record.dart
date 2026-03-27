import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalRecord {
  final String id;
  final String name;
  final String url;
  final String type;
  final DateTime date;

  MedicalRecord({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.date,
  });

  factory MedicalRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicalRecord.fromMap(doc.id, data);
  }

  factory MedicalRecord.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return MedicalRecord(
      id: id,
      name: map['name'] ?? 'ملف طبي',
      url: map['url'] ?? '',
      type: map['type'] ?? 'unknown',
      date: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'type': type,
      'date': date.toIso8601String(), // doctor_app expects ISO 8601 string
    };
  }
}
