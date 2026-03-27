import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat.dart';
import '../models/message.dart';

/// خدمة إدارة المحادثات والرسائل للمريض
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// جلب رسائل محادثة معينة
  Stream<List<Message>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
        });
  }

  /// إنشاء أو جلب محادثة موجودة مع دكتور
  Future<String> createOrGetChat({
    required String doctorId,
    required String doctorUserId, // Added doctorUserId
    required String doctorName,
    required String patientId,
    required String patientName,
  }) async {
    try {
      // البحث عن محادثة موجودة
      final existingChats = await _firestore
          .collection('chats')
          .where('doctorId', isEqualTo: doctorId)
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();

      if (existingChats.docs.isNotEmpty) {
        return existingChats.docs.first.id;
      }

      // إنشاء محادثة جديدة
      final newChat = Chat(
        id: '',
        doctorId: doctorId,
        doctorUserId: doctorUserId, // Added doctorUserId
        doctorName: doctorName,
        patientId: patientId,
        patientName: patientName,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore.collection('chats').add(newChat.toMap());
      return docRef.id;
    } catch (e) {
// debugPrint('❌ خطأ في إنشاء المحادثة: $e');
      rethrow;
    }
  }

  /// إرسال رسالة جديدة
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderType,
    required String text,
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

      // تحديث آخر رسالة وعدد الرسائل غير المقروءة
      final chatRef = _firestore.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      if (chatDoc.exists) {
        final lastMessageText = messageType == 'image' ? '📷 صورة' : text;
        final updates = <String, dynamic>{
          'lastMessage': lastMessageText,
          'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        };

        // زيادة عدد الرسائل غير المقروءة للطرف الآخر
        if (senderType == 'doctor') {
          updates['unreadCountPatient'] = FieldValue.increment(1);
        } else {
          updates['unreadCountDoctor'] = FieldValue.increment(1);
        }

        await chatRef.update(updates);

        // Trigger notification for the doctor if sender is patient
        if (senderType == 'patient' || senderType == 'user') {
          // Use doctorUserId if available, fallback to doctorId
          final recipientId = chatDoc.data()?['doctorUserId'] ?? chatDoc.data()?['doctorId'] ?? '';
          await _triggerChatNotification(
            chatId: chatId,
            recipientId: recipientId,
            senderName: senderName,
            text: lastMessageText,
          );
        }
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
// debugPrint('🔔 Chat notification triggered for doctor: $recipientId');
    } catch (e) {
// debugPrint('⚠️ Failed to trigger chat notification: $e');
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
