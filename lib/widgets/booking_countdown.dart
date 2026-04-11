import 'dart:async';
import 'package:flutter/material.dart';

class BookingCountdown extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onConfirm;
  final VoidCallback onTimeout;
  final bool isArabic;

  const BookingCountdown({
    super.key,
    required this.expiresAt,
    required this.onConfirm,
    required this.onTimeout,
    required this.isArabic,
  });

  @override
  State<BookingCountdown> createState() => _BookingCountdownState();
}

class _BookingCountdownState extends State<BookingCountdown> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _startTimer();
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    if (widget.expiresAt.isAfter(now)) {
      setState(() {
        _timeLeft = widget.expiresAt.difference(now);
      });
    } else {
      setState(() {
        _timeLeft = Duration.zero;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      final now = DateTime.now();
      if (widget.expiresAt.isAfter(now)) {
        setState(() {
          _timeLeft = widget.expiresAt.difference(now);
        });
      } else {
        setState(() {
          _timeLeft = Duration.zero;
        });
        _timer.cancel();
        widget.onTimeout();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.inSeconds <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Text(
          widget.isArabic
              ? "انتهت المهلة، وتم إلغاء الحجز."
              : "Timeout expired, booking cancelled.",
          style: const TextStyle(
            color: Color(0xFFEF4444), // Red for expired
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      );
    }

    String minutes = _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.isArabic
                    ? "أكد خلال: $minutes:$seconds"
                    : "Confirm within: $minutes:$seconds",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: widget.onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981), // Green for confirm
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            widget.isArabic ? "تأكيد الحجز ✅" : "Confirm Booking ✅",
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
