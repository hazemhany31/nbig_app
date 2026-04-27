// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// شاشة المحادثة — مريض مع طبيب، أو [isDoctorView] للطبيب مع المريض (نفس مستند Firestore)
class ChatScreen extends StatefulWidget {
  final Chat chat;
  /// `true` عند فتح المحادثة من واجهة الطبيب
  final bool isDoctorView;

  const ChatScreen({
    super.key,
    required this.chat,
    this.isDoctorView = false,
  });

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
  bool _hasText = false;
  final FocusNode _focusNode = FocusNode();
  bool _peerIsTyping = false;

  // Peer info
  String? _peerPhotoUrl;

  // Anti-spam variables
  DateTime? _lastMessageTime;
  int _rapidMessageCount = 0;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _peerPhotoUrl = widget.isDoctorView
        ? widget.chat.patientPhotoUrl
        : widget.chat.doctorPhotoUrl;
    _loadPeerPhoto();
    _chatService.markMessagesAsRead(
      widget.chat.id,
      widget.isDoctorView ? 'doctor' : 'patient',
    );
    _messagesStream = _chatService.getChatMessages(widget.chat.id);

    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);

      if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();
      _typingDebounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        final myField = widget.isDoctorView ? 'doctorIsTyping' : 'patientIsTyping';
        FirebaseFirestore.instance.collection('chats').doc(widget.chat.id)
            .set({myField: _messageController.text.isNotEmpty}, SetOptions(merge: true));
      });
    });

    _focusNode.addListener(() => setState(() {}));

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chat.id)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data() ?? {};
      final field = widget.isDoctorView ? 'patientIsTyping' : 'doctorIsTyping';
      setState(() => _peerIsTyping = data[field] == true);
    });
  }

  Future<void> _loadPeerPhoto() async {
    try {
      if (widget.isDoctorView) {
        // Doctor is viewing patient photo
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.chat.patientId)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _peerPhotoUrl = doc.data()?['photoUrl'];
          });
        }
      } else {
        // Patient is viewing doctor photo
        final doc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(widget.chat.doctorId)
            .get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _peerPhotoUrl = (data?['image'] ?? data?['photoUrl'])?.toString();
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading peer photo: $e');
    }
  }

  String get _displayNameMe {
    if (widget.isDoctorView) {
      return FirebaseAuth.instance.currentUser?.displayName ??
          widget.chat.doctorName;
    }
    return widget.chat.patientName;
  }

  String get _peerDisplayName =>
      widget.isDoctorView ? widget.chat.patientName : widget.chat.doctorName;

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // --- Anti-Spam Check ---
    final now = DateTime.now();
    if (_lastMessageTime != null) {
      if (now.difference(_lastMessageTime!).inSeconds < 1) {
        _rapidMessageCount++;
        if (_rapidMessageCount >= 3) {
          if (mounted) {
            final isArabic = Directionality.of(context) == ui.TextDirection.rtl;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isArabic 
                  ? 'الرجاء الانتظار قليلاً لتجنب إرسال رسائل متكررة' 
                  : 'Please wait a moment before sending more messages'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } else {
        _rapidMessageCount = 0;
      }
    }
    _lastMessageTime = now;
    // -----------------------

    _messageController.clear(); // Clear immediately for feel

    try {
      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        senderName: _displayNameMe,
        senderType: widget.isDoctorView ? 'doctor' : 'patient',
        text: text,
        recipientId: widget.isDoctorView
            ? widget.chat.patientId
            : (widget.chat.doctorUserId.isNotEmpty
                ? widget.chat.doctorUserId
                : null),
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

      final Uint8List bytes = await image.readAsBytes();

      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        senderName: _displayNameMe,
        senderType: widget.isDoctorView ? 'doctor' : 'patient',
        text: '📷 صورة',
        type: 'image',
        imageBytes: bytes,
        recipientId: widget.isDoctorView
            ? widget.chat.patientId
            : (widget.chat.doctorUserId.isNotEmpty
                ? widget.chat.doctorUserId
                : null),
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

      final Uint8List bytes = await image.readAsBytes();

      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        senderName: _displayNameMe,
        senderType: widget.isDoctorView ? 'doctor' : 'patient',
        text: '📷 صورة',
        type: 'image',
        imageBytes: bytes,
        recipientId: widget.isDoctorView
            ? widget.chat.patientId
            : (widget.chat.doctorUserId.isNotEmpty
                ? widget.chat.doctorUserId
                : null),
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
    _typingDebounce?.cancel();
    final myField = widget.isDoctorView ? 'doctorIsTyping' : 'patientIsTyping';
    FirebaseFirestore.instance.collection('chats').doc(widget.chat.id)
        .set({myField: false}, SetOptions(merge: true));

    _focusNode.dispose();
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
                    child: _peerPhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: _peerPhotoUrl!,
                              fit: BoxFit.cover,
                              width: 38,
                              height: 38,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  _peerDisplayName.isNotEmpty
                                      ? _peerDisplayName[0].toUpperCase()
                                      : (widget.isDoctorView ? 'P' : 'D'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _peerDisplayName.isNotEmpty
                                  ? _peerDisplayName[0].toUpperCase()
                                  : (widget.isDoctorView ? 'م' : 'د'),
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
                    _peerDisplayName,
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
                    // Prefer sender UID so doctor-app messages still align if senderType is wrong
                    final isPatient = message.senderId == _currentUserId;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_peerIsTyping)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      const TypingIndicator(),
                      const SizedBox(width: 8),
                      Text(isArabic ? 'يكتب...' : 'typing...', 
                           style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: _focusNode.hasFocus
                          ? Border.all(color: const Color(0xFF10B981), width: 1.5)
                          : Border.all(
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
                            focusNode: _focusNode,
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: _hasText
                          ? Container(
                              key: const ValueKey('active'),
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
                            )
                          : Container(
                              key: const ValueKey('inactive'),
                              margin: const EdgeInsets.only(left: 4, right: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.send_rounded,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
            ],
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

class _MessageBubble extends StatefulWidget {
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

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _popController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: Curves.easeOut),
    );
    _popController.forward();
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  /// Show full-screen image viewer. Supports both URL and legacy base64 data.
  void _showFullImage(BuildContext context, String imageData) {
    final bool isUrl = imageData.startsWith('http://') || imageData.startsWith('https://');
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
                tag: widget.message.id,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
                  child: isUrl
                      ? CachedNetworkImage(
                          imageUrl: imageData,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 64,
                          ),
                        )
                      : Image.memory(
                          base64Decode(imageData),
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
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        alignment: widget.isPatient ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: widget.isPatient
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: EdgeInsets.all(widget.message.isImage ? 4 : 16),
                  decoration: BoxDecoration(
                    gradient: widget.isPatient
                        ? const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          )
                        : (widget.isDark
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
                      bottomLeft: Radius.circular(widget.isPatient ? 24 : 6),
                      bottomRight: Radius.circular(widget.isPatient ? 6 : 24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isPatient
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: !widget.isPatient
                        ? Border.all(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.1),
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: widget.isPatient
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (widget.message.isImage && widget.message.imageUrl != null)
                        GestureDetector(
                          onTap: () =>
                              _showFullImage(context, widget.message.imageUrl!),
                          child: Hero(
                            tag: widget.message.id,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _buildImageWidget(context, widget.message.imageUrl!),
                            ),
                          ),
                        )
                      else
                        Text(
                          widget.message.text,
                          style: TextStyle(
                            color: widget.isPatient
                                ? Colors.white
                                : (widget.isDark
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
                            DateFormat('HH:mm').format(widget.message.sentAt),
                            style: TextStyle(
                              color: widget.isPatient
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.grey.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.isPatient && !widget.message.isImage) ...[
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
        ),
      ),
    );
  }

  /// Builds image widget supporting both Firebase Storage URLs and legacy base64 data.
  Widget _buildImageWidget(BuildContext context, String imageData) {
    final bool isUrl = imageData.startsWith('http://') || imageData.startsWith('https://');
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: 250,
      ),
      child: isUrl
          ? CachedNetworkImage(
              imageUrl: imageData,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
                    SizedBox(height: 8),
                    Text('فشل تحميل الصورة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )
          : Image.memory(base64Decode(imageData), fit: BoxFit.cover),
    );
  }
}

/// Animated typing indicator with bouncing dots
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _dotControllers;

  @override
  void initState() {
    super.initState();
    _dotControllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _dotControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _dotControllers[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8 + (_dotControllers[i].value * 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
