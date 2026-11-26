import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nbig_app/models/medical_record.dart';
import 'package:nbig_app/screens/medical_records_screen.dart';
import 'package:nbig_app/services/medical_records_service.dart';

void main() {
  group('MedicalRecordsService.deleteMedicalRecord partial-failure handling', () {
    test('succeeds when both Storage and Firestore deletes succeed', () async {
      var storageCalls = 0;
      var firestoreCalls = 0;
      var markPendingCalls = 0;

      final service = MedicalRecordsService(
        retryDelay: Duration.zero,
        storageDeleteOverride: (url, path) async {
          storageCalls++;
        },
        firestoreDeleteOverride: (patientId, recordId) async {
          firestoreCalls++;
        },
        firestoreMarkPendingOverride: (patientId, recordId) async {
          markPendingCalls++;
        },
      );

      await service.deleteMedicalRecord(
        patientId: 'patient_1',
        recordId: 'rec_1',
        fileUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/file.pdf',
      );

      expect(storageCalls, 1);
      expect(firestoreCalls, 1);
      expect(markPendingCalls, 0);
    });

    test('Storage failure retries and preserves Firestore document (no false success)', () async {
      var storageCalls = 0;
      var firestoreCalls = 0;

      final service = MedicalRecordsService(
        retryDelay: Duration.zero,
        storageDeleteOverride: (url, path) async {
          storageCalls++;
          throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'unauthorized',
            message: 'Permission denied',
          );
        },
        firestoreDeleteOverride: (patientId, recordId) async {
          firestoreCalls++;
        },
      );

      await expectLater(
        () => service.deleteMedicalRecord(
          patientId: 'patient_1',
          recordId: 'rec_1',
          fileUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/file.pdf',
          maxAttempts: 2,
        ),
        throwsA(
          isA<MedicalRecordDeleteException>()
              .having((e) => e.code, 'code', 'storage-delete-failed')
              .having((e) => e.storageDeleted, 'storageDeleted', false)
              .having((e) => e.firestoreDeleted, 'firestoreDeleted', false),
        ),
      );

      expect(storageCalls, 2);
      // Critical: Firestore doc MUST NOT be deleted if Storage delete failed,
      // so the file reference is never lost.
      expect(firestoreCalls, 0);
    });

    test('Storage transient failure recovers on retry and deletes Firestore doc', () async {
      var storageCalls = 0;
      var firestoreCalls = 0;

      final service = MedicalRecordsService(
        retryDelay: Duration.zero,
        storageDeleteOverride: (url, path) async {
          storageCalls++;
          if (storageCalls == 1) {
            throw Exception('Transient network error');
          }
        },
        firestoreDeleteOverride: (patientId, recordId) async {
          firestoreCalls++;
        },
      );

      await service.deleteMedicalRecord(
        patientId: 'patient_1',
        recordId: 'rec_1',
        fileUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/file.pdf',
        maxAttempts: 2,
      );

      expect(storageCalls, 2);
      expect(firestoreCalls, 1);
    });

    test('Firestore failure after Storage delete marks pending cleanup and throws explicit error', () async {
      var storageCalls = 0;
      var firestoreCalls = 0;
      var markPendingCalls = 0;

      final service = MedicalRecordsService(
        retryDelay: Duration.zero,
        storageDeleteOverride: (url, path) async {
          storageCalls++;
        },
        firestoreDeleteOverride: (patientId, recordId) async {
          firestoreCalls++;
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Firestore unavailable',
          );
        },
        firestoreMarkPendingOverride: (patientId, recordId) async {
          markPendingCalls++;
        },
      );

      await expectLater(
        () => service.deleteMedicalRecord(
          patientId: 'patient_1',
          recordId: 'rec_1',
          fileUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/file.pdf',
          maxAttempts: 2,
        ),
        throwsA(
          isA<MedicalRecordDeleteException>()
              .having((e) => e.code, 'code', 'firestore-delete-failed')
              .having((e) => e.storageDeleted, 'storageDeleted', true)
              .having((e) => e.firestoreDeleted, 'firestoreDeleted', false),
        ),
      );

      expect(storageCalls, 1);
      expect(firestoreCalls, 2);
      expect(markPendingCalls, 1);
    });

    test('Retry after partial failure treats Storage object-not-found as already deleted and completes Firestore delete', () async {
      var storageCalls = 0;
      var firestoreCalls = 0;

      final service = MedicalRecordsService(
        retryDelay: Duration.zero,
        storageDeleteOverride: (url, path) async {
          storageCalls++;
          throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
            message: 'No object exists at the desired reference.',
          );
        },
        firestoreDeleteOverride: (patientId, recordId) async {
          firestoreCalls++;
        },
      );

      await service.deleteMedicalRecord(
        patientId: 'patient_1',
        recordId: 'rec_1',
        fileUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/file.pdf',
      );

      expect(storageCalls, 1);
      expect(firestoreCalls, 1);
    });
  });

  group('pendingDelete model, service completion, and UI state', () {
    test('MedicalRecord.fromMap reads pendingDelete flag and defaults to false', () {
      final pending = MedicalRecord.fromMap('rec_pending', {
        'name': 'Lab Result',
        'url': 'https://example.com/lab.pdf',
        'type': 'pdf',
        'date': '2026-08-20T10:00:00.000',
        'pendingDelete': true,
      });
      final normal = MedicalRecord.fromMap('rec_normal', {
        'name': 'X-Ray',
        'url': 'https://example.com/xray.png',
        'type': 'png',
        'date': '2026-08-20T10:00:00.000',
      });

      expect(pending.pendingDelete, isTrue);
      expect(normal.pendingDelete, isFalse);
    });

    test('completePendingDelete deletes Firestore doc directly without calling Storage', () async {
      var storageCalls = 0;
      var firestoreCalls = 0;

      final service = MedicalRecordsService(
        retryDelay: Duration.zero,
        storageDeleteOverride: (url, path) async {
          storageCalls++;
        },
        firestoreDeleteOverride: (patientId, recordId) async {
          firestoreCalls++;
        },
      );

      final record = MedicalRecord(
        id: 'rec_pending',
        name: 'Lab Result',
        url: 'https://firebasestorage.googleapis.com/v0/b/x/o/file.pdf',
        type: 'pdf',
        date: DateTime(2026, 8, 20),
        pendingDelete: true,
      );

      await service.completePendingDelete(
        patientId: 'patient_1',
        record: record,
      );

      expect(storageCalls, 0);
      expect(firestoreCalls, 1);
    });

    testWidgets('MedicalRecordListItem shows "الحذف لم يكتمل" and completes delete on tap',
        (WidgetTester tester) async {
      var completeCalled = 0;
      var openCalled = 0;

      final record = MedicalRecord(
        id: 'rec_pending',
        name: 'تحليل دم',
        url: 'https://example.com/blood.pdf',
        type: 'pdf',
        date: DateTime(2026, 8, 20),
        pendingDelete: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicalRecordListItem(
              record: record,
              isDark: false,
              isArabic: true,
              onOpen: () => openCalled++,
              onDelete: () {},
              onCompletePendingDelete: () => completeCalled++,
            ),
          ),
        ),
      );

      expect(find.text('الحذف لم يكتمل'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.delete_forever_rounded));
      await tester.pump();

      expect(completeCalled, 1);
      expect(openCalled, 0);
    });
  });
}
