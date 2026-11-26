/// يمنع عرض نفس الإشعار مرتين (مستند Firestore + رسالة FCM + أكتر من listener).
/// أول مصدر يطلب يكسب، والباقي يتجاهل. الـ id هو id مستند notifications.
class NotificationDedupe {
  static final Set<String> _shown = <String>{};
  static const int _max = 500;

  /// true لو ده أول مرة نشوف الـ id (يعني اعرض الإشعار).
  static bool claim(String? id) {
    if (id == null || id.isEmpty) return true; // مفيش id: اعرض (ما نخسرش رسالة)
    if (_shown.contains(id)) return false;
    if (_shown.length >= _max) _shown.remove(_shown.first);
    _shown.add(id);
    return true;
  }

  static void reset() => _shown.clear();
}
