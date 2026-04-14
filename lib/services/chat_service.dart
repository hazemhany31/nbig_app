import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../models/message.dart';

/// خدمة إدارة المحادثات والرسائل للمريض
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// معرّف مستند Firestore واحد لكل زوج (مريض + طبيب) — نفس الصيغة لازم تتبع في **تطبيق الدكتور**
  /// عشان الاتنين يفتحوا `chats/{id}` من غير ما يعتمدوا على بحث أو `add()`.
  ///
  /// [patientAuthUid] و [doctorAuthUid] هما `FirebaseAuth.instance.currentUser.uid`.
  static String stableDocumentIdForPair(
    String patientAuthUid,
    String doctorAuthUid,
  ) {
    if (patientAuthUid.isEmpty || doctorAuthUid.isEmpty) {
      throw ArgumentError(
        'patientAuthUid and doctorAuthUid must be non-empty for stable chat id',
      );
    }
    final lo = patientAuthUid.compareTo(doctorAuthUid) <= 0
        ? patientAuthUid
        : doctorAuthUid;
    final hi = patientAuthUid.compareTo(doctorAuthUid) <= 0
        ? doctorAuthUid
        : patientAuthUid;
    return 'nbig_chat_${lo}_$hi';
  }

  /// جلب محادثات الطبيب (نفس `doctorUserId` في المستند = Firebase Auth UID للطبيب)
  Stream<List<Chat>> getDoctorChats(String doctorAuthUid) {
    return _firestore
        .collection('chats')
        .where('doctorUserId', isEqualTo: doctorAuthUid)
        .snapshots()
        .map((snapshot) {
          final list =
              snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();
          list.sort((a, b) {
            final ta = a.lastMessageTime ?? a.createdAt;
            final tb = b.lastMessageTime ?? b.createdAt;
            return tb.compareTo(ta);
          });
          return list;
        });
  }

  /// جلب جميع محادثات المريض
  Stream<List<Chat>> getPatientChats(String patientId) {
    return _firestore
        .collection('chats')
        .where('patientId', isEqualTo: patientId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();
        });
  }

  /// جلب رسائل محادثة معينة مع دعم التقسيم (Pagination) لتقليل الاستهلاك والتكلفة
  Stream<List<Message>> getChatMessages(String chatId, {int limit = 20}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
        });
  }

  /// إنشاء أو جلب محادثة موجودة مع دكتور
  ///
  /// 1) لو فيه [doctorUserId] (UID الطبيب من Auth): نجرب أولاً مستند ثابت
  ///    [stableDocumentIdForPair] — نفس المستند في تطبيق المريض والدكتور من الأساس.
  /// 2) نبحث في محادثات قديمة (معرّف عشوائي أو اختلاف تسمية doctorId).
  Future<String> createOrGetChat({
    required String doctorId,
    required String doctorUserId, // Added doctorUserId
    required String doctorName,
    required String patientId,
    required String patientName,
    String? doctorSpecialty,
    String? doctorSpecialtyAr,
  }) async {
    try {
      final candidateIds = <String>{
        if (doctorId.isNotEmpty) doctorId,
        if (doctorUserId.isNotEmpty) doctorUserId,
      };

      String? stableId;
      if (doctorUserId.isNotEmpty) {
        stableId = stableDocumentIdForPair(patientId, doctorUserId);
        final stableSnap =
            await _firestore.collection('chats').doc(stableId).get();
        if (stableSnap.exists) {
          return stableId;
        }
      }

      final patientChats = await _firestore
          .collection('chats')
          .where('patientId', isEqualTo: patientId)
          .get();

      for (final doc in patientChats.docs) {
        final data = doc.data();
        final did = (data['doctorId'] ?? '').toString();
        final duid = (data['doctorUserId'] ?? '').toString();
        if (candidateIds.contains(did) || candidateIds.contains(duid)) {
          return doc.id;
        }
      }

      // Fetch current patient details (including photoUrl)
      String? patientPhotoUrl;
      try {
        final patientDoc =
            await _firestore.collection('users').doc(patientId).get();
        if (patientDoc.exists) {
          patientPhotoUrl = patientDoc.data()?['photoUrl'];
        }
      } catch (e) {
        debugPrint('⚠️ Failed to fetch patient photoUrl for chat: $e');
      }

      // Fetch doctor details (including photoUrl and specialty)
      String? doctorPhotoUrl;
      String? fetchedSpecialty;
      String? fetchedSpecialtyAr;
      try {
        final docSnap =
            await _firestore.collection('doctors').doc(doctorId).get();
        if (docSnap.exists) {
          final data = docSnap.data();
          doctorPhotoUrl = (data?['image'] ?? data?['photoUrl'])?.toString();
          fetchedSpecialty = data?['specialty'] ?? data?['specialization'];
          fetchedSpecialtyAr = data?['specialtyAr'] ?? data?['specializationAr'];
        }
      } catch (e) {
        debugPrint('⚠️ Failed to fetch doctor details for chat: $e');
      }

      final newChat = Chat(
        id: '',
        doctorId: doctorId,
        doctorUserId: doctorUserId, // Added doctorUserId
        doctorName: doctorName,
        patientId: patientId,
        patientName: patientName,
        patientPhotoUrl: patientPhotoUrl, // Include photoUrl
        doctorPhotoUrl: doctorPhotoUrl, // Include doctor photoUrl
        doctorSpecialty: doctorSpecialty ?? fetchedSpecialty,
        doctorSpecialtyAr: doctorSpecialtyAr ?? fetchedSpecialtyAr,
        createdAt: DateTime.now(),
      );

      if (stableId != null) {
        await _firestore
            .collection('chats')
            .doc(stableId)
            .set(newChat.toMap(), SetOptions(merge: true));
        return stableId;
      }

      final docRef = await _firestore.collection('chats').add(newChat.toMap());
      return docRef.id;
    } catch (e) {
// debugPrint('❌ خطأ في إنشاء المحادثة: $e');
      rethrow;
    }
  }

  /// فتح/إنشاء محادثة من جلسة الطبيب (نفس معرّف المستند الثابت مع تطبيق المريض)
  Future<String> openChatWithPatient({
    required String patientId,
    required String patientName,
    required String doctorFirestoreId,
    required String doctorAuthUid,
    required String doctorName,
  }) {
    return createOrGetChat(
      doctorId: doctorFirestoreId,
      doctorUserId: doctorAuthUid,
      doctorName: doctorName,
      patientId: patientId,
      patientName: patientName,
    );
  }

  /// إرسال رسالة جديدة
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderType,
    required String text,
    String? recipientId, // Optional recipient ID for notifications
    String messageType = 'text',
    String? imageBase64,
  }) async {
    try {
      final message = Message(
        id: '',
        senderId: senderId,
        senderName: senderName,
        senderType: senderType,
        text: text,
        sentAt: DateTime.now(),
        isRead: false,
        messageType: messageType,
        imageBase64: imageBase64,
      );

      // إضافة الرسالة
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      // تحديث آخر رسالة وعدد الرسائل غير المقروءة باستخدام merge لتجنب الفشل الصامت
      final chatRef = _firestore.collection('chats').doc(chatId);
      final lastMessageText = messageType == 'image' ? '📷 صورة' : text;
      
      final updates = <String, dynamic>{
        'lastMessage': lastMessageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
      };

      // زيادة عدد الرسائل غير المقروءة للطرف الآخر
      if (senderType == 'doctor') {
        updates['unreadCountPatient'] = FieldValue.increment(1);
      } else {
        updates['unreadCountDoctor'] = FieldValue.increment(1);
      }

      await chatRef.set(updates, SetOptions(merge: true));

      // إشعار الطرف الآخر (مريض ↔ طبيب)
      String notifyRecipient = recipientId ?? '';
      if (notifyRecipient.isEmpty) {
        final chatDoc = await chatRef.get();
        if (chatDoc.exists) {
          final data = chatDoc.data();
          if (senderType == 'doctor') {
            notifyRecipient = (data?['patientId'] ?? '').toString();
          } else {
            // التحقق من doctorUserId أولاً لأنه الأساس في استلام الإشعارات
            notifyRecipient = (data?['doctorUserId'] ?? '').toString();
            
            // لو ناقص، نحاول نجيبه من doctorId كـ fallback أخير
            if (notifyRecipient.isEmpty) {
              final dId = (data?['doctorId'] ?? '').toString();
              if (dId.isNotEmpty) {
                final docSnap = await _firestore.collection('doctors').doc(dId).get();
                if (docSnap.exists) {
                  notifyRecipient = (docSnap.data()?['userId'] ?? '').toString();
                  // نحدث الشات بالمرة عشان المرة الجاية ميعملش lookup
                  if (notifyRecipient.isNotEmpty) {
                    await chatRef.update({'doctorUserId': notifyRecipient});
                  }
                }
              }
            }
          }
        }
      }
      
      if (notifyRecipient.isNotEmpty) {
        await _triggerChatNotification(
          chatId: chatId,
          recipientId: notifyRecipient,
          senderName: senderName,
          text: lastMessageText,
        );
      }
    } catch (e) {
// debugPrint('❌ خطأ في إرسال الرسالة: $e');
      rethrow;
    }
  }

  /// Trigger a notification document for the recipient
  Future<void> _triggerChatNotification({
    required String chatId,
    required String recipientId,
    required String senderName,
    required String text,
  }) async {
    try {
      if (recipientId.isEmpty) return;
      
      await _firestore.collection('notifications').add({
        'recipientId': recipientId,
        'title': 'رسالة جديدة من $senderName',
        'body': text,
        'type': 'new_message',
        'chatId': chatId,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔔 Chat notification triggered for recipient: $recipientId');
    } catch (e) {
      debugPrint('⚠️ Failed to trigger chat notification: $e');
    }
  }

  /// تحديد الرسائل كمقروءة
  Future<void> markMessagesAsRead(String chatId, String userType) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);

      // إعادة تعيين عدد الرسائل غير المقروءة
      if (userType == 'doctor') {
        await chatRef.update({'unreadCountDoctor': 0});
      } else {
        await chatRef.update({'unreadCountPatient': 0});
      }

      // تحديد جميع الرسائل كمقروءة
      final messagesSnapshot = await chatRef
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderType', isNotEqualTo: userType)
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
// debugPrint('❌ خطأ في تحديد الرسائل كمقروءة: $e');
    }
  }

  /// جلب إجمالي عدد الرسائل غير المقروءة للمريض
  Stream<int> getTotalUnreadCount(String patientId) {
    return _firestore
        .collection('chats')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            total += (data['unreadCountPatient'] ?? 0) as int;
          }
          return total;
        });
  }

  /// جلب محادثة معينة
  Future<Chat?> getChat(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (doc.exists) {
        return Chat.fromFirestore(doc);
      }
      return null;
    } catch (e) {
// debugPrint('❌ خطأ في جلب المحادثة: $e');
      return null;
    }
  }
}
