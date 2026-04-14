import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج محادثة بين دكتور ومريض
class Chat {
  final String id;
  final String doctorId;
  final String doctorUserId; // Firebase Auth UID
  final String doctorName;
  final String patientId;
  final String patientName;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCountDoctor;
  final int unreadCountPatient;
  final DateTime createdAt;
  final String? patientPhotoUrl;
  final String? doctorPhotoUrl;
  final String? doctorSpecialty;
  final String? doctorSpecialtyAr;

  Chat({
    required this.id,
    required this.doctorId,
    required this.doctorUserId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCountDoctor = 0,
    this.unreadCountPatient = 0,
    required this.createdAt,
    this.patientPhotoUrl,
    this.doctorPhotoUrl,
    this.doctorSpecialty,
    this.doctorSpecialtyAr,
  });

  /// إنشاء Chat من Firestore DocumentSnapshot
  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat.fromMap(doc.id, data);
  }

  /// إنشاء Chat من Map
  factory Chat.fromMap(String id, Map<String, dynamic> map) {
    return Chat(
      id: id,
      doctorId: map['doctorId'] ?? '',
      doctorUserId: map['doctorUserId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      lastMessage: map['lastMessage'],
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCountDoctor: map['unreadCountDoctor'] ?? 0,
      unreadCountPatient: map['unreadCountPatient'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      patientPhotoUrl: map['patientPhotoUrl'],
      doctorPhotoUrl: map['doctorPhotoUrl'],
      doctorSpecialty: map['doctorSpecialty'],
      doctorSpecialtyAr: map['doctorSpecialtyAr'],
    );
  }

  /// تحويل Chat إلى Map
  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'doctorUserId': doctorUserId,
      'doctorName': doctorName,
      'patientId': patientId,
      'patientName': patientName,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unreadCountDoctor': unreadCountDoctor,
      'unreadCountPatient': unreadCountPatient,
      'createdAt': Timestamp.fromDate(createdAt),
      'patientPhotoUrl': patientPhotoUrl,
      'doctorPhotoUrl': doctorPhotoUrl,
      'doctorSpecialty': doctorSpecialty,
      'doctorSpecialtyAr': doctorSpecialtyAr,
    };
  }

  Chat copyWith({
    String? id,
    String? doctorId,
    String? doctorUserId,
    String? doctorName,
    String? patientId,
    String? patientName,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCountDoctor,
    int? unreadCountPatient,
    DateTime? createdAt,
    String? patientPhotoUrl,
    String? doctorPhotoUrl,
    String? doctorSpecialty,
    String? doctorSpecialtyAr,
  }) {
    return Chat(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorUserId: doctorUserId ?? this.doctorUserId,
      doctorName: doctorName ?? this.doctorName,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCountDoctor: unreadCountDoctor ?? this.unreadCountDoctor,
      unreadCountPatient: unreadCountPatient ?? this.unreadCountPatient,
      createdAt: createdAt ?? this.createdAt,
      patientPhotoUrl: patientPhotoUrl ?? this.patientPhotoUrl,
      doctorPhotoUrl: doctorPhotoUrl ?? this.doctorPhotoUrl,
      doctorSpecialty: doctorSpecialty ?? this.doctorSpecialty,
      doctorSpecialtyAr: doctorSpecialtyAr ?? this.doctorSpecialtyAr,
    );
  }
}
