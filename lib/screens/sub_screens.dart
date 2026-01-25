import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart'; // عشان صفحة اتصل بنا
import '../services/database_helper.dart';
import '../models/doctor_model.dart'; // Added import
import '../services/notification_service.dart'; // عشان إشعار الحجز
import 'main_layout.dart'; // عشان متغير اللغة isArabic

// === 1. DOCTOR DETAILS SCREEN (HERO + DB FAVORITES) ===
class DoctorDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const DoctorDetailsScreen({super.key, required this.doctor});
  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  late bool isFav;
  @override
  void initState() {
    super.initState();
    isFav = widget.doctor['isFavorite'] ?? false;
  }

  String _cleanHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }

  Widget _buildDoctorImage(String imagePath, String gender) {
    if (imagePath.isEmpty) {
      return Icon(
        gender == 'Female' ? Icons.female : Icons.male,
        size: 100,
        color: Colors.white.withOpacity(0.8),
      );
    }
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => Icon(
          gender == 'Female' ? Icons.female : Icons.male,
          size: 100,
          color: Colors.white.withOpacity(0.8),
        ),
      );
    } else if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (context, url, error) => Icon(
          gender == 'Female' ? Icons.female : Icons.male,
          size: 100,
          color: Colors.white.withOpacity(0.8),
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => Icon(
          gender == 'Female' ? Icons.female : Icons.male,
          size: 100,
          color: Colors.white.withOpacity(0.8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFemale = widget.doctor['gender'] == 'Female';
    String cleanAbout = _cleanHtml(widget.doctor['about'] ?? "");

    return Scaffold(
      backgroundColor: widget.doctor['color'] ?? Colors.blue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () async {
              setState(() {
                isFav = !isFav;
                widget.doctor['isFavorite'] = isFav;
              });
              await DatabaseHelper().toggleFavorite(widget.doctor['id']);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // === HERO ANIMATION (الصورة الطائرة) ===
          Hero(
            tag: widget.doctor['id'],
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: _buildDoctorImage(
                widget.doctor['image'] ?? '',
                widget.doctor['gender'] ?? 'Male',
              ),
            ),
          ),
          // =======================================
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor, // لون حسب الثيم
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.doctor['name'],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.doctor['specialty'],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.doctor['rating'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InfoCard(
                        label: isArabic ? 'مرضى' : 'Patients',
                        value: widget.doctor['patients'] ?? '500+',
                      ),
                      InfoCard(
                        label: isArabic ? 'خبرة' : 'Experience',
                        value: widget.doctor['experience'] ?? '10 Yrs',
                      ),
                      InfoCard(
                        label: isArabic ? 'تقييم' : 'Rating',
                        value: widget.doctor['rating'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    isArabic ? 'عن الطبيب' : 'About Doctor',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        cleanAbout.isNotEmpty
                            ? cleanAbout
                            : "No details available.",
                        style: const TextStyle(color: Colors.grey, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // زرار الشات
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChatScreen(doctorName: widget.doctor['name']),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // زرار الحجز
                      Expanded(
                        child: SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AppointmentScreen(
                                    doctorName: widget.doctor['name'],
                                    specialty: widget.doctor['specialty'],
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  widget.doctor['color'] ?? Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              isArabic ? 'احجز موعد' : 'Book Appointment',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
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
}

class InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const InfoCard({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // متوافق مع الدارك مود
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

// === 2. CHAT SCREEN (PERSISTENT) ===
class ChatScreen extends StatefulWidget {
  final String doctorName;
  const ChatScreen({super.key, required this.doctorName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _loadMessages() async {
    try {
      final msgs = await DatabaseHelper().getMessages(widget.doctorName);
      if (mounted) {
        setState(() {
          _messages = msgs;
        });
        _scrollToBottom();
      }
    } catch (e) {
      // لو في مشكلة، نعمل قائمة فاضية
      if (mounted) {
        setState(() {
          _messages = [];
        });
      }
    }
  }

  void _sendMessage({String? attachmentPath, String? attachmentType}) async {
    String text = _msgController.text.trim();
    if (attachmentPath == null && text.isEmpty) return;

    if (attachmentPath == null) {
      _msgController.clear();
    }

    HapticFeedback.lightImpact();
    await DatabaseHelper().saveMessage(
      widget.doctorName,
      text,
      true,
      attachmentPath: attachmentPath,
      attachmentType: attachmentType,
    );
    _loadMessages();

    // Auto-reply logic (only for text messages for simplicity, or always)
    Future.delayed(const Duration(seconds: 1), () async {
      if (mounted) {
        await DatabaseHelper().saveMessage(
          widget.doctorName,
          isArabic
              ? "أهلاً بك، كيف يمكنني مساعدتك؟"
              : "Hello! How can I help you?",
          false,
        );
        _loadMessages();
      }
    });
  }

  void _pickAttachment() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: Text(isArabic ? 'كاميرا' : 'Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                );
                if (image != null) {
                  _sendMessage(
                    attachmentPath: image.path,
                    attachmentType: 'image',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.blue),
              title: Text(isArabic ? 'معرض الصور' : 'Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  _sendMessage(
                    attachmentPath: image.path,
                    attachmentType: 'image',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.blue),
              title: Text(isArabic ? 'ملف' : 'File'),
              onTap: () async {
                Navigator.pop(ctx);
                FilePickerResult? result = await FilePicker.platform
                    .pickFiles();
                if (result != null && result.files.single.path != null) {
                  _sendMessage(
                    attachmentPath: result.files.single.path!,
                    attachmentType: 'file',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doctorName),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isArabic ? "لا توجد رسائل بعد" : "No messages yet",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isArabic
                              ? "ابدأ المحادثة مع الطبيب"
                              : "Start a conversation with the doctor",
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      bool isMe = msg['isMe'] == 1;
                      String? attachPath = msg['attachmentPath'];
                      String? attachType = msg['attachmentType'];

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 200 + (index * 30)),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(
                                isMe ? 20 * (1 - value) : -20 * (1 - value),
                                0,
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.blue
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(15).copyWith(
                                bottomRight: isMe
                                    ? Radius.zero
                                    : const Radius.circular(15),
                                bottomLeft: !isMe
                                    ? Radius.zero
                                    : const Radius.circular(15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (attachPath != null && attachType == 'image')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        File(attachPath),
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(
                                          Icons.broken_image,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (attachPath != null && attachType == 'file')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.insert_drive_file,
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            attachPath.split('/').last,
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.underline,
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (msg['text'] != null &&
                                    msg['text'].toString().isNotEmpty)
                                  Text(
                                    msg['text'],
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black),
                                      fontSize: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: _pickAttachment,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? "اكتب رسالة..."
                          : "Type a message...",
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.color?.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === 3. APPOINTMENT SCREEN (SMART - WITH CALENDAR & SLOTS) ===
class AppointmentScreen extends StatefulWidget {
  final String doctorName;
  final String specialty;
  const AppointmentScreen({
    super.key,
    required this.doctorName,
    required this.specialty,
  });
  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  DateTime _selectedDate = DateTime.now();
  int _selectedTime = -1;
  bool _isSaving = false;
  List<String> _bookedTimes = [];

  @override
  void initState() {
    super.initState();
    _checkBookedTimes();
  }

  String _formatDate(DateTime date) {
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return "${days[date.weekday - 1]}, ${date.day}";
  }

  String _formatTime(int hour) {
    String period = hour >= 12 ? 'PM' : 'AM';
    int h = hour > 12 ? hour - 12 : hour;
    if (h == 0) h = 12;
    return '$h:00 $period';
  }

  void _checkBookedTimes() async {
    String date = _formatDate(_selectedDate);
    final booked = await DatabaseHelper().getBookedTimes(
      widget.doctorName,
      date,
    );
    setState(() {
      _bookedTimes = booked;
      // لو الوقت اللي مختاره طلع محجوز، الغي الاختيار
      if (_selectedTime != -1 &&
          _bookedTimes.contains(_formatTime(9 + _selectedTime))) {
        _selectedTime = -1;
      }
    });
  }

  // فتح التقويم
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = -1;
      });
      _checkBookedTimes();
    }
  }

  void _onConfirmPressed() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          isArabic ? "تأكيد الحجز" : "Confirm Booking",
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Text(
          isArabic
              ? "هل أنت متأكد من حجز موعد مع ${widget.doctorName} يوم ${_formatDate(_selectedDate)} الساعة ${_formatTime(9 + _selectedTime)}؟"
              : "Are you sure you want to book with ${widget.doctorName} on ${_formatDate(_selectedDate)} at ${_formatTime(9 + _selectedTime)}?",
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isArabic ? "إلغاء" : "Cancel",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveBooking();
            },
            child: Text(
              isArabic ? "تأكيد" : "Confirm",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[300]
                    : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBooking() async {
    setState(() => _isSaving = true);
    try {
      String timeStr = _formatTime(9 + _selectedTime);
      await DatabaseHelper().addAppointment(
        widget.doctorName,
        widget.specialty,
        _formatDate(_selectedDate),
        timeStr,
      );

      await NotificationService().showNotification(
        isArabic ? "تم تأكيد الحجز ✅" : "Appointment Confirmed ✅",
        isArabic
            ? "تم حجز موعد مع ${widget.doctorName} الساعة $timeStr"
            : "You booked with ${widget.doctorName} at $timeStr",
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuccessScreen()),
        );
      }
    } catch (e) {
      /* Error */
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isArabic ? 'حجز موعد' : 'Book Appointment'),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'اختر اليوم' : 'Select Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 15),

            // === تقويم (Calendar Button) ===
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.withOpacity(0.5)
                        : Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_formatDate(_selectedDate)} ${isArabic ? '(اضغط للتغيير)' : '(Tap to change)'}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Icon(Icons.calendar_month, color: Colors.blue),
                  ],
                ),
              ),
            ),

            // ==============================
            const SizedBox(height: 30),
            Text(
              isArabic ? 'اختر الوقت' : 'Select Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 15),

            // === الساعات ===
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(9, (index) {
                String timeString = _formatTime(9 + index);
                bool isBooked = _bookedTimes.contains(timeString);
                bool isSelected = !isBooked && _selectedTime == index;
                bool isDark = Theme.of(context).brightness == Brightness.dark;

                return ChoiceChip(
                  label: Text(timeString),
                  selected: isBooked ? true : isSelected,
                  selectedColor: isBooked ? Colors.grey : Colors.blue,
                  disabledColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  backgroundColor: isDark ? Colors.grey[700] : Colors.white,
                  labelStyle: TextStyle(
                    color: isBooked
                        ? Colors.white
                        : (isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black)),
                  ),
                  onSelected: isBooked
                      ? null
                      : (selected) => setState(
                          () => _selectedTime = (selected ? index : -1),
                        ),
                );
              }),
            ),

            const Spacer(),

            // === زر التأكيد ===
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_selectedTime == -1 || _isSaving)
                    ? null
                    : _onConfirmPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isArabic ? 'تأكيد الحجز' : 'Confirm Booking',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === 4. SUCCESS SCREEN ===
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            Text(
              isArabic ? 'تم الحجز بنجاح!' : 'Appointment Booked!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  isArabic ? 'العودة للرئيسية' : 'Back to Home',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === 5. CONTACT US SCREEN ===
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});
  Future<void> _launch(String url) async {
    if (!await launchUrl(Uri.parse(url))) throw 'Could not launch $url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Contact Us"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Image.asset('assets/images/doctor_big_preview.png', height: 150),
            const Icon(Icons.support_agent, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "We are here to help you!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue, size: 30),
              title: const Text("Hotline"),
              subtitle: const Text("19938"),
              onTap: () => _launch("tel:19938"),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green, size: 30),
              title: const Text("WhatsApp"),
              subtitle: const Text("01112221121"),
              onTap: () => _launch("whatsapp://send?phone=+201112221121"),
            ),
          ],
        ),
      ),
    );
  }
}

// === 6. ABOUT & PRIVACY ===
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? "عنا" : "About Us"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.local_hospital, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "Doctor App",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              isArabic
                  ? "نحن نقدم أفضل الخدمات الطبية من خلال ربط المرضى بأفضل الأطباء."
                  : "We provide the best medical consultation services connecting patients with top doctors worldwide.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue, size: 30),
              title: Text(isArabic ? "رقم التواصل" : "Contact Number"),
              subtitle: const Text("+20 11 12221121"),
              onTap: () => _launch("tel:+201112221121"),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue, size: 30),
              title: Text(isArabic ? "البريد الإلكتروني" : "Email"),
              subtitle: const Text("info@new-build-egypt.com"),
              onTap: () => _launch("mailto:info@new-build-egypt.com"),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? "سياسة الخصوصية" : "Privacy Policy"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          isArabic
              ? "خصوصيتك مهمة بالنسبة لنا. إنها سياسة تطبيق Doctor App أن نحترم خصوصيتك فيما يتعلق بأي معلومات قد نجمعها منك."
              : "Your privacy is important to us. It is Doctor App's policy to respect your privacy regarding any information we may collect from you.",
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// === 8. DONATE SCREEN ===
class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'تبرع' : 'Donate'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.volunteer_activism,
                size: 100,
                color: Colors.blue[300],
              ),
              const SizedBox(height: 20),
              Text(
                isArabic
                    ? 'نحن نعمل على توفير هذه الخدمة قريباً.'
                    : 'We are working on this feature soon.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isArabic ? 'حسناً' : 'OK',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === 9. CATEGORY DOCTORS SCREEN ===
class CategoryDoctorsScreen extends StatefulWidget {
  final String category;
  final String categoryKeyword;
  const CategoryDoctorsScreen({
    super.key,
    required this.category,
    required this.categoryKeyword,
  });

  @override
  State<CategoryDoctorsScreen> createState() => _CategoryDoctorsScreenState();
}

class _CategoryDoctorsScreenState extends State<CategoryDoctorsScreen> {
  List<Doctor> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    // If 'All', we fetch all doctors. If specific, fetch filtered.
    // Assuming getDoctors handles 'All' by returning all?
    // Usually 'All' keyword might need handling.
    // Check DatabaseHelper or just pass empty if All.
    // In main_layout, 'All' passed 'All'.
    // If logic in DatabaseHelper uses 'All' to filter, it might return empty if no doc has specialty 'All'.
    // I should check DatabaseHelper later. For now, trust existing logic or improve.
    final data = await DatabaseHelper().getDoctors(
      category: widget.categoryKeyword == 'All'
          ? 'All'
          : widget.categoryKeyword,
    );
    if (mounted) {
      setState(() {
        _doctors = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            iconTheme: IconThemeData(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.category,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue.withOpacity(0.1),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_doctors.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 15),
                    Text(
                      isArabic
                          ? 'لا يوجد أطباء في هذا القسم'
                          : 'No doctors found',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final doc = _doctors[index];
                return _buildDoctorCard(context, doc, index);
              }, childCount: _doctors.length),
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, Doctor doc, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DoctorDetailsScreen(
                  doctor: {
                    'id': doc.id,
                    'name': isArabic ? doc.nameAr : doc.name,
                    'specialty': isArabic ? doc.specialtyAr : doc.specialty,
                    'rating': doc.rating,
                    'image': doc.image,
                    'about': isArabic ? doc.aboutAr : doc.about,
                    'gender': doc.gender,
                    'color': Colors.blue,
                    'isFavorite': doc.isFavorite,
                    'patients': doc.patients,
                    'experience': doc.experience,
                  },
                ),
              ),
            );
            _loadDoctors();
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Hero(
                  tag: doc.id,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.grey[200],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _buildDoctorImage(doc.image, doc.gender),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? doc.nameAr : doc.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isArabic ? doc.specialtyAr : doc.specialty,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors
                                .orange, // Keep star orange as per design generally, user asked for blue search button not star.
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            doc.rating.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (doc.isFavorite)
                            const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 20,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorImage(String imagePath, String gender) {
    if (imagePath.isEmpty) {
      return Icon(
        gender == 'Female' ? Icons.female : Icons.male,
        size: 40,
        color: Colors.grey,
      );
    }
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => Icon(
          gender == 'Female' ? Icons.female : Icons.male,
          size: 40,
          color: Colors.grey,
        ),
      );
    } else if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        memCacheWidth: 200,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Icon(
          gender == 'Female' ? Icons.female : Icons.male,
          size: 40,
          color: Colors.grey,
        ),
      );
    } else {
      // Local File
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => Icon(
          gender == 'Female' ? Icons.female : Icons.male,
          size: 40,
          color: Colors.grey,
        ),
      );
    }
  }
}
