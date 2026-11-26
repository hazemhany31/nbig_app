import 'package:flutter_test/flutter_test.dart';
import 'package:nbig_app/services/appointment_flow.dart';

void main() {
  bookingTests();
  test('cancel: appointment updated first, denied cleanup is swallowed', () async {
    final log = <String>[];
    await cancelAppointmentFlow(
      updateAppointment: () async => log.add('update'),
      cleanupNotifications: () async {
        log.add('cleanup');
        throw Exception('permission-denied');
      },
    );
    expect(log, ['update', 'cleanup']);
  });

  test('cancel: appointment failure reaches the caller, cleanup not run', () async {
    final log = <String>[];
    await expectLater(
      cancelAppointmentFlow(
        updateAppointment: () async => throw Exception('permission-denied'),
        cleanupNotifications: () async => log.add('cleanup'),
      ),
      throwsException,
    );
    expect(log, isEmpty);
  });

  test('delete: denied cleanup does not block the delete', () async {
    final log = <String>[];
    await deleteAppointmentFlow(
      cleanupNotifications: () async {
        log.add('cleanup');
        throw Exception('permission-denied');
      },
      deleteAppointment: () async => log.add('delete'),
    );
    expect(log, ['cleanup', 'delete']);
  });

  test('delete: appointment delete failure reaches the caller', () async {
    await expectLater(
      deleteAppointmentFlow(
        cleanupNotifications: () async {},
        deleteAppointment: () async => throw Exception('permission-denied'),
      ),
      throwsException,
    );
  });
}

class _Denied implements Exception {}

void bookingTests() {
  bool denied(Object e) => e is _Denied;

  test('booking: normal success never touches the fallback', () async {
    var blind = 0;
    await bookSlotFlow(transactional: () async {}, blindSet: () async => blind++, isPermissionDenied: denied);
    expect(blind, 0);
  });

  test('booking: slot taken from the transaction passes through unchanged, no fallback', () async {
    var blind = 0;
    await expectLater(
      bookSlotFlow(
        transactional: () async => throw const SlotTakenException(),
        blindSet: () async => blind++,
        isPermissionDenied: denied,
      ),
      throwsA(isA<SlotTakenException>()),
    );
    expect(blind, 0);
  });

  test('booking: transaction read denied, plain write allowed (free slot) books', () async {
    var blind = 0;
    await bookSlotFlow(
      transactional: () async => throw _Denied(),
      blindSet: () async => blind++,
      isPermissionDenied: denied,
    );
    expect(blind, 1);
  });

  test('booking: both denied means slot taken, with the same message text as before', () async {
    await expectLater(
      bookSlotFlow(
        transactional: () async => throw _Denied(),
        blindSet: () async => throw _Denied(),
        isPermissionDenied: denied,
      ),
      throwsA(predicate((e) => e is SlotTakenException && e.toString() == 'Exception: ${SlotTakenException.message}')),
    );
  });

  test('booking: a non-permission error (network) is not reported as slot taken', () async {
    await expectLater(
      bookSlotFlow(
        transactional: () async => throw StateError('network'),
        blindSet: () async {},
        isPermissionDenied: denied,
      ),
      throwsStateError,
    );
  });

  test('booked times: slots and appointments merged, cancelled and unbooked ignored', () {
    final r = mergeBookedTimes(
      slotDocs: [
        {'time': '10:00 AM', 'booked': true},
        {'time': '11:00 AM', 'booked': false},
      ],
      appointmentDocs: [
        {'time': '10:00 AM', 'status': 'pending'},
        {'time': '12:00 PM', 'status': 'confirmed'},
        {'time': '01:00 PM', 'status': 'cancelled'},
      ],
    );
    expect(r.toSet(), {'10:00 AM', '12:00 PM'});
  });

  test('booked times: strict rules (appointments query denied) still show slot-based times', () {
    expect(mergeBookedTimes(slotDocs: [{'time': '09:00 AM', 'booked': true}], appointmentDocs: const []), ['09:00 AM']);
  });
}
