// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/emergency_service.dart';
import '../services/chat_service.dart';
import '../models/chat.dart';
import '../language_config.dart';
import 'chat/chat_screen.dart';

class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({super.key});

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen>
    with SingleTickerProviderStateMixin {
  final EmergencyService _emergencyService = EmergencyService();
  final ChatService _chatService = ChatService();

  bool _isSending = true;
  bool _noDoctor = false; // true when no online doctor is available
  String? _alertId;
  String _doctorName = '';
  String _doctorSpecialty = '';
  String _doctorId = '';
  String _doctorUserId = '';
  String _doctorPhone = '';
  bool _isAcknowledged = false;
  bool _isCancelledByDoctor = false;
  bool _limitReached = false;

  // Countdown: 5 minutes = 300 seconds
  int _secondsRemaining = 300;
  Timer? _countdownTimer;
  StreamSubscription? _alertSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sendAlert();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _alertSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _sendAlert() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic ? 'يجب تسجيل الدخول أولاً' : 'Please login first',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final result = await _emergencyService.sendEmergencyAlert(
        patientId: user.uid,
        patientName: user.displayName ?? (isArabic ? 'مريض' : 'Patient'),
      );

      // Limit reached for this user
      if (result['limitReached'] == true) {
        if (mounted) setState(() { _isSending = false; _limitReached = true; });
        return;
      }

      // No online doctor available
      if (result['noDoctor'] == true) {
        if (mounted) setState(() { _isSending = false; _noDoctor = true; });
        return;
      }

      if (mounted) {
        setState(() {
          _isSending = false;
          _alertId = result['alertId'];
          _doctorName = result['doctorName'] ?? '';
          _doctorSpecialty = result['doctorSpecialty'] ?? '';
          _doctorId = result['doctorId'] ?? '';
          _doctorUserId = result['doctorUserId'] ?? '';
          _doctorPhone = result['doctorPhone'] ?? '';
        });
        _startCountdown();
        if (_alertId != null) _watchAlert(_alertId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'حدث خطأ: $e' : 'Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  void _watchAlert(String alertId) {
    _alertSubscription = _emergencyService.watchAlert(alertId).listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      // Sync doctor details
      setState(() {
        if (data.containsKey('doctorId')) _doctorId = data['doctorId'] ?? '';
        if (data.containsKey('doctorUserId')) _doctorUserId = data['doctorUserId'] ?? '';
        if (data.containsKey('doctorName')) _doctorName = data['doctorName'] ?? '';
        if (data.containsKey('doctorSpecialty')) _doctorSpecialty = data['doctorSpecialty'] ?? '';
        if (data.containsKey('doctorPhone')) _doctorPhone = data['doctorPhone'] ?? '';

        if (data['status'] == 'acknowledged') {
          _isAcknowledged = true;
          _isCancelledByDoctor = false;
        } else if (data['status'] != 'pending') {
          _isCancelledByDoctor = true;
          _isAcknowledged = false;
        }
      });
    });
  }

  Future<void> _cancelAlert() async {
    if (_alertId != null) {
      await _emergencyService.cancelAlert(_alertId!);
    }
    if (mounted) Navigator.pop(context);
  }

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openChat() async {
    if (_doctorId.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final patientName = user.displayName ?? (isArabic ? 'مريض' : 'Patient');

      final chatId = await _chatService.createOrGetChat(
        doctorId: _doctorId,
        doctorUserId: _doctorUserId,
        doctorName: _doctorName,
        patientId: user.uid,
        patientName: patientName,
      );

      if (!mounted) return;

      final chat = Chat(
        id: chatId,
        doctorId: _doctorId,
        doctorUserId: _doctorUserId,
        doctorName: _doctorName,
        patientId: user.uid,
        patientName: patientName,
        createdAt: DateTime.now(),
      );

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(chat: chat)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'تعذّر فتح المحادثة: $e' : 'Could not open chat: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        body: SafeArea(
          child: _isSending
              ? _buildLoadingState()
              : _limitReached
                  ? _buildLimitReachedState(isDark)
                  : _noDoctor
                      ? _buildNoDoctorState(isDark)
                      : _buildAlertState(isDark),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium pulsing radar effect wrapper
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                ),
              ),
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(
                width: 50, height: 50,
                child: CircularProgressIndicator(
                  color: Color(0xFFEF4444), // Red
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            isArabic ? 'جارٍ البحث عن طبيب إنقاذ...' : 'Finding an available doctor...',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isArabic ? 'يرجى الانتظار، نحن معك' : 'Please hold on, we are with you',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFF991B1B)], // Red warning
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.block_rounded, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 32),
            Text(
              isArabic ? 'استنفدت المحاولات لليوم' : 'Daily Emergency Limit Reached',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              isArabic
                  ? 'عذراً، لقد استخدمت الحد الأقصى المسموح به لحالات الطوارئ المتاحة لك اليوم (محاولتين فقط).'
                  : 'Sorry, you have exhausted your 2 emergency alerts limit for today.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Go Back
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                label: Text(
                  isArabic ? 'العودة للرئيسية' : 'Go Back Home',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDoctorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFDE047), Color(0xFFF59E0B)], // Amber Gold
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.person_off_rounded, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 32),
            Text(
              isArabic ? 'لا يوجد طبيب متاح للإنقاذ فوراً' : 'No Rescuing Doctor Available Right Now',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              isArabic
                  ? 'جميع أطباء الطوارئ غير متصلين حالياً.\nيرجى المحاولة مرة أخرى أو الاتصال الفوري بالإسعاف.'
                  : 'All emergency doctors are currently offline.\nPlease try again or call emergency services immediately.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Try Again
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() { _isSending = true; _noDoctor = false; });
                  _sendAlert();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  isArabic ? 'إعادة المحاولة' : 'Try Again',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Go Back
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                label: Text(
                  isArabic ? 'العودة' : 'Go Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertState(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─── Glowing SOS Pulse ───
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isAcknowledged 
                    ? [const Color(0xFF10B981), const Color(0xFF065F46)] // Emerald to Deep Green
                    : (_isCancelledByDoctor 
                        ? [Colors.grey.shade600, Colors.grey.shade800] // Gray for cancelled
                        : [const Color(0xFFEF4444), const Color(0xFF991B1B)]), // Vivid Red to Deep Red
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isAcknowledged 
                        ? const Color(0xFF10B981) 
                        : (_isCancelledByDoctor ? Colors.grey : const Color(0xFFEF4444))).withValues(alpha: 0.4), 
                    blurRadius: 40, spreadRadius: 10
                  ),
                  BoxShadow(
                    color: (_isAcknowledged 
                        ? const Color(0xFF065F46) 
                        : (_isCancelledByDoctor ? Colors.grey.shade900 : const Color(0xFF991B1B))).withValues(alpha: 0.3), 
                    blurRadius: 20, spreadRadius: 5
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _isAcknowledged ? 'GO' : (_isCancelledByDoctor ? 'X' : 'SOS'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _isCancelledByDoctor
                ? (isArabic ? 'نعتذر، الطبيب مشغول حالياً' : 'Sorry, Doctor is Busy')
                : (_isAcknowledged
                    ? (isArabic ? 'الطبيب بانتظارك الآن!' : 'Doctor is waiting for you!')
                    : (isArabic ? 'إنذار طوارئ مُرسَل!' : 'Emergency Alert Sent!')),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _isCancelledByDoctor
                  ? Colors.orange
                  : (_isAcknowledged
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white : const Color(0xFF1E293B))),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _isCancelledByDoctor
                ? (isArabic
                    ? 'لم يتمكن الطبيب من قبول الطلب حالياً. يرجى المحاولة مرة أخرى أو الاتصال بالطوارئ.'
                    : 'The doctor could not accept the alert right now. Please try again or call emergency.')
                : (_isAcknowledged
                    ? (isArabic
                        ? 'يمكنك التوجه للعيادة فوراً، الطبيب مستعد لاستقبالك'
                        : 'You can head to the clinic now, the doctor is ready to see you')
                    : (isArabic
                        ? 'يتم الآن إخطار أقرب طبيب متاح للإنقاذ فوراً'
                        : 'The nearest available doctor is being notified for rescue')),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          // ─── Sleek Countdown Pill ───
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 48),
            decoration: BoxDecoration(
              color: _secondsRemaining < 60
                  ? const Color(0xFFFEF2F2)
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: _secondsRemaining < 60
                    ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                width: _secondsRemaining < 60 ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _secondsRemaining < 60
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  isArabic ? 'وقت الاستجابة المتوقع' : 'Expected Response Time',
                  style: TextStyle(
                    color: _secondsRemaining < 60
                        ? const Color(0xFFDC2626)
                        : (isDark ? Colors.grey[400] : Colors.grey[500]),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: _secondsRemaining < 60
                        ? const Color(0xFFDC2626)
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // ─── Premium Glass Doctor Card ───
          if (_doctorName.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                ),
                boxShadow: [
                  BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF0EA5E9).withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                children: [
                   Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 2), // Emerald 
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                        child: Text(
                          _doctorName.isNotEmpty ? _doctorName.substring(0, 1).toUpperCase() : 'D',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'الطبيب المُكلَف' : 'Assigned Doctor',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _doctorName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        if (_doctorSpecialty.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _doctorSpecialty,
                            style: const TextStyle(
                              color: Color(0xFF0EA5E9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ─── Try Again Button (When Cancelled) ───
          if (_isCancelledByDoctor) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isSending = true;
                    _isCancelledByDoctor = false;
                    _isAcknowledged = false;
                    _secondsRemaining = 300;
                  });
                  _sendAlert();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  isArabic ? 'إعادة المحاولة' : 'Try Again',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],

          if (!_isCancelledByDoctor) ...[
            // ─── Actions Grid ───
            if (_doctorId.isNotEmpty || _doctorPhone.isNotEmpty)
              Row(
                children: [
                  if (_doctorPhone.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final Uri url = Uri.parse('tel:$_doctorPhone');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        icon: const Icon(Icons.phone_rounded, color: Colors.indigo, size: 22),
                        label: Text(
                          isArabic ? 'اتصال هاتف' : 'Call',
                          style: const TextStyle(color: Colors.indigo, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  if (_doctorPhone.isNotEmpty && _doctorId.isNotEmpty) const SizedBox(width: 16),
                  if (_doctorId.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openChat,
                        icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                        label: Text(
                          isArabic ? 'محادثة' : 'Chat',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                ],
              ),

            if (_doctorId.isNotEmpty || _doctorPhone.isNotEmpty) const SizedBox(height: 16),

            // ─── Cancel Alert Button ───
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _cancelAlert,
                icon: const Icon(Icons.close_rounded),
                label: Text(
                  isArabic ? 'إلغاء حالة الطوارئ' : 'Cancel Emergency Alert',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
