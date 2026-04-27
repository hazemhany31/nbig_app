import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج رسالة في المحادثة
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderType; // 'doctor' أو 'patient'
  final String text;
  final DateTime sentAt;
  final bool isRead;
  final String type; // 'text', 'image'
  final String? imageUrl; // Firebase Storage URL for images

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.text,
    required this.sentAt,
    this.isRead = false,
    this.type = 'text',
    this.imageUrl,
  });

  /// إنشاء Message من Firestore DocumentSnapshot
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message.fromMap(doc.id, data);
  }

  /// إنشاء Message من Map
  /// Backward-compatible: reads both `type` (new) and `messageType` (legacy nbig_app)
  /// Backward-compatible: reads both `imageUrl` (new/doctor-app) and `imageBase64` (legacy nbig_app)
  factory Message.fromMap(String id, Map<String, dynamic> map) {
    // Resolve type: prefer `type`, fallback to `messageType` for old nbig_app messages
    final resolvedType = map['type'] ?? map['messageType'] ?? 'text';

    // Resolve image URL: prefer `imageUrl` (Storage URL from doctor-app or new nbig_app),
    // fallback to `imageBase64` for legacy nbig_app messages stored as base64 in Firestore
    final resolvedImageUrl = map['imageUrl'] ?? map['imageBase64'];

    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderType: map['senderType'] ?? 'patient',
      text: map['text'] ?? '',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      type: resolvedType,
      imageUrl: resolvedImageUrl,
    );
  }

  /// تحويل Message إلى Map
  /// Writes unified field names (`type`, `imageUrl`) compatible with doctor-app
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
      'type': type,
    };
    if (imageUrl != null) {
      map['imageUrl'] = imageUrl;
    }
    return map;
  }

  bool get isImage => type == 'image';

  /// Helper to check if imageUrl is a base64 string (legacy) vs a URL
  bool get isBase64Image =>
      imageUrl != null &&
      !imageUrl!.startsWith('http://') &&
      !imageUrl!.startsWith('https://');

  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderType,
    String? text,
    DateTime? sentAt,
    bool? isRead,
    String? type,
    String? imageUrl,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderType: senderType ?? this.senderType,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
