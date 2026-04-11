import 'package:flutter/material.dart';

class AppAnimations {
  // === التوقيتات (Durations) ===
  
  /// حركات سريعة مثل الهوفر (Hover) أو الأزرار (Buttons)
  static const Duration fast = Duration(milliseconds: 150);
  
  /// حركات متوسطة مثل الانتقال من مكان لآخر أو إظهار الكروت (Cards)
  static const Duration medium = Duration(milliseconds: 300);
  
  /// حركات بطيئة مثل تأثيرات الخلفية أو الشاشات المعقدة
  static const Duration slow = Duration(milliseconds: 500);

  /// توقيت الشيمر (Shimmer)
  static const Duration shimmer = Duration(milliseconds: 1200);

  // === المنحنيات (Curves) ===
  
  /// أسلوب ناعم جدًا (يبدأ بسرعة وينتهي ببطء) مريح للعين ومتوافق مع واجهات المرضى
  static const Curve smoothIn = Curves.fastOutSlowIn;
  
  /// مناسب للأزرار والـ Scale أينما نحتاج لارتداد هادئ غير مزعج
  static const Curve gentleBounce = Curves.easeOutBack;
  
  /// تأثير هدوء مستمر مناسب للـ Opacity أو الـ Fade
  static const Curve fadeCurve = Curves.easeInOut;
}
