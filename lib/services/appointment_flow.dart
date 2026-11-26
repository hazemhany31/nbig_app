/// Ordering and error rules for cancelling / deleting an appointment.
///
/// The appointment write is the operation that matters: its failure must reach
/// the caller. Related-notification cleanup is best-effort: with stricter
/// Firestore rules a patient may not be allowed to touch the doctor's
/// notifications, and that must never block (or fake) the appointment change.
Future<void> cancelAppointmentFlow({
  required Future<void> Function() updateAppointment,
  required Future<void> Function() cleanupNotifications,
}) async {
  await updateAppointment(); // throws -> caller sees it, cleanup is skipped
  try {
    await cleanupNotifications();
  } catch (_) {}
}

Future<void> deleteAppointmentFlow({
  required Future<void> Function() cleanupNotifications,
  required Future<void> Function() deleteAppointment,
}) async {
  try {
    await cleanupNotifications();
  } catch (_) {}
  await deleteAppointment(); // throws -> caller sees it
}

/// Same text and toString() as the plain Exception the booking code threw before,
/// so screens that show the message keep showing the identical text.
class SlotTakenException implements Exception {
  const SlotTakenException();
  static const message = 'عذراً، هذا الموعد تم حجزه للتو. يرجى اختيار موعد آخر.';
  @override
  String toString() => 'Exception: $message';
}

/// Booking with a rules-compatible fallback.
/// 1. Run the transaction (reads the slot's appointment document).
/// 2. If a stricter rule set denies that read (another patient's appointment),
///    try a plain write: Firestore rules accept it only for a free (cancelled)
///    slot, so a denial there means the slot is taken.
/// SlotTakenException and any non-permission error pass through unchanged.
Future<void> bookSlotFlow({
  required Future<void> Function() transactional,
  required Future<void> Function() blindSet,
  required bool Function(Object error) isPermissionDenied,
}) async {
  try {
    await transactional();
  } catch (e) {
    if (e is SlotTakenException || !isPermissionDenied(e)) rethrow;
    try {
      await blindSet();
    } catch (e2) {
      if (isPermissionDenied(e2)) throw const SlotTakenException();
      rethrow;
    }
  }
}

/// Booked times of one doctor/day. Two sources, either may be unavailable:
/// - occupancy documents (appointment_slots, written server-side), and
/// - appointment documents (readable only while rules are still open).
/// A time counts as booked unless its appointment is cancelled / its slot is not booked.
List<String> mergeBookedTimes({
  required Iterable<Map<String, dynamic>> slotDocs,
  required Iterable<Map<String, dynamic>> appointmentDocs,
}) {
  final out = <String>{};
  for (final d in slotDocs) {
    if (d['booked'] == true && d['time'] != null) out.add(d['time'].toString());
  }
  for (final d in appointmentDocs) {
    if (d['status'] != 'cancelled' && d['time'] != null) out.add(d['time'].toString());
  }
  return out.toList();
}
