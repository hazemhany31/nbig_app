// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import 'package:intl/intl.dart';

/// شاشة المحادثة مع الدكتور
class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isSendingImage = false;
  late Stream<List<Message>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.chat.id, 'patient');
    _messagesStream = _chatService.getChatMessages(widget.chat.id);
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear(); // Clear immediately for feel

    try {
      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        senderName: widget.chat.patientName,
        senderType: 'patient',
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل إرسال الرسالة: $e')));
      }
    }
  }

  void _sendImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isSendingImage = true);

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        senderName: widget.chat.patientName,
        senderType: 'patient',
        text: '📷 صورة',
        messageType: 'image',
        imageBase64: base64String,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل إرسال الصورة: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _sendCameraImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isSendingImage = true);

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        senderName: widget.chat.patientName,
        senderType: 'patient',
        text: '📷 صورة',
        messageType: 'image',
        imageBase64: base64String,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل إرسال الصورة: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9),
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      Directionality.of(context) == ui.TextDirection.rtl
                          ? 'إرسال مرفق'
                          : 'Send Attachment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAttachOption(
                          ctx,
                          Icons.photo_library_rounded,
                          Directionality.of(context) == ui.TextDirection.rtl
                              ? 'معرض الصور'
                              : 'Gallery',
                          const Color(0xFF8B5CF6),
                          _sendImage,
                        ),
                        _buildAttachOption(
                          ctx,
                          Icons.camera_alt_rounded,
                          Directionality.of(context) == ui.TextDirection.rtl
                              ? 'الكاميرا'
                              : 'Camera',
                          const Color(0xFF3B82F6),
                          _sendCameraImage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0.0, // Because reversed list
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == ui.TextDirection.rtl;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.8),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.chat.doctorName.isNotEmpty
                            ? widget.chat.doctorName[0].toUpperCase()
                            : 'د',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.chat.doctorName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isSendingImage)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isArabic ? 'جاري إرسال الصورة...' : 'Sending image...',
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ: ${snapshot.error}',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.waving_hand_rounded,
                            size: 60,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isArabic ? 'ابدأ المحادثة' : 'Say Hello!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Note: We are using reversed list to keep message input floating above recent messages
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  reverse: true, // Auto scrolls to bottom natively
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isPatient = message.senderType == 'patient';
                    // Since it's reversed, the "previous" chronological message is at index + 1
                    final showDate =
                        index == messages.length - 1 ||
                        !_isSameDay(messages[index + 1].sentAt, message.sentAt);

                    return Column(
                      children: [
                        if (showDate)
                          _buildDateDivider(message.sentAt, isArabic, isDark),
                        _MessageBubble(
                          message: message,
                          isPatient: isPatient,
                          isArabic: isArabic,
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Floating Glass Input Field
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 16,
            left: 16,
            right: 16,
          ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 22,
                      ),
                    ),
                    onPressed: _isSendingImage ? null : _showAttachmentOptions,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: isArabic
                            ? 'اكتب رسالة...'
                            : 'Type a message...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      margin: const EdgeInsets.only(left: 4, right: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateDivider(DateTime date, bool isArabic, bool isDark) {
    final now = DateTime.now();
    final difference = now.difference(date);
    String dateText;

    if (_isSameDay(date, now)) {
      dateText = isArabic ? 'اليوم' : 'Today';
    } else if (difference.inDays == 1) {
      dateText = isArabic ? 'أمس' : 'Yesterday';
    } else {
      dateText = DateFormat('dd/MM/yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isPatient;
  final bool isArabic;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.isPatient,
    required this.isArabic,
    required this.isDark,
  });

  void _showFullImage(BuildContext context, String base64String) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.black.withValues(alpha: 0.9)),
            ),
            Center(
              child: Hero(
                tag: message.id,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.memory(
                    base64Decode(base64String),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isPatient
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: EdgeInsets.all(message.isImage ? 4 : 16),
              decoration: BoxDecoration(
                gradient: isPatient
                    ? const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      )
                    : (isDark
                          ? LinearGradient(
                              colors: [
                                const Color(0xFF1E293B),
                                const Color(0xFF1E293B).withValues(alpha: 0.95),
                              ],
                            )
                          : LinearGradient(
                              colors: [Colors.white, Colors.grey.shade50],
                            )),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isPatient ? 24 : 6),
                  bottomRight: Radius.circular(isPatient ? 6 : 24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPatient
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: !isPatient
                    ? Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.1),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: isPatient
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.isImage && message.imageBase64 != null)
                    GestureDetector(
                      onTap: () =>
                          _showFullImage(context, message.imageBase64!),
                      child: Hero(
                        tag: message.id,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: constraintsBox(context, message.imageBase64!),
                        ),
                      ),
                    )
                  else
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isPatient
                            ? Colors.white
                            : (isDark
                                  ? Colors.grey[200]
                                  : const Color(0xFF1E293B)),
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.sentAt),
                        style: TextStyle(
                          color: isPatient
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isPatient && !message.isImage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget constraintsBox(BuildContext context, String base64Str) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: 250,
      ),
      child: Image.memory(base64Decode(base64Str), fit: BoxFit.cover),
    );
  }
}
