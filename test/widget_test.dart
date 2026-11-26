import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nbig_app/screens/auth/biometric_gate.dart';
import 'package:nbig_app/services/biometric_service.dart';
import 'package:nbig_app/services/notification_dedupe.dart';
import 'package:nbig_app/services/notification_presenter.dart';
import 'package:nbig_app/widgets/biometric_toggle_tile.dart';

class FakeBackend implements BiometricBackend {
  bool supported;
  final List<bool> results; // authenticate results in order, last repeats
  int calls = 0;
  FakeBackend({this.supported = true, this.results = const [true]});
  @override
  Future<bool> canCheckBiometrics() async => supported;
  @override
  Future<bool> isDeviceSupported() async => supported;
  @override
  Future<bool> authenticate(String reason) async {
    final i = calls < results.length ? calls : results.length - 1;
    calls++;
    return results[i];
  }
}

Widget app(Widget child) => MaterialApp(home: child);

Future<void> openGate(WidgetTester t) async {
  await t.pumpWidget(app(const BiometricGate(uid: 'u1', child: Text('HOME'))));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  presenterTests();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationDedupe.reset();
  });

  test('NotificationDedupe shows each id once, always shows id-less', () {
    expect(NotificationDedupe.claim('a'), isTrue);
    expect(NotificationDedupe.claim('a'), isFalse);
    expect(NotificationDedupe.claim('b'), isTrue);
    expect(NotificationDedupe.claim(null), isTrue);
    expect(NotificationDedupe.claim(''), isTrue);
    expect(NotificationDedupe.claim(null), isTrue);
  });

  testWidgets('unsupported device: straight to app, no dialog', (t) async {
    BiometricService.overrideForTest(FakeBackend(supported: false));
    await openGate(t);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('first login offers Face ID; accepting needs real auth then persists', (t) async {
    final fake = FakeBackend();
    BiometricService.overrideForTest(fake);
    await openGate(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.tap(find.text('تفعيل'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(fake.calls, 1);
    expect(await BiometricService().isEnabledForUser('u1'), isTrue);
  });

  testWidgets('accepting but failing biometric does NOT enable', (t) async {
    final fake = FakeBackend(results: [false]);
    BiometricService.overrideForTest(fake);
    await openGate(t);
    await t.tap(find.text('تفعيل'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(await BiometricService().isEnabledForUser('u1'), isFalse);
  });

  testWidgets('Not now: not enabled, not asked again on next open', (t) async {
    BiometricService.overrideForTest(FakeBackend());
    await openGate(t);
    await t.tap(find.text('مش دلوقتي'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(await BiometricService().isEnabledForUser('u1'), isFalse);
    expect(await BiometricService().wasOffered('u1'), isTrue);
    await t.pumpWidget(const SizedBox());
    await openGate(t);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('enabled: app stays locked until biometric succeeds', (t) async {
    SharedPreferences.setMockInitialValues({'biometric_enabled_u1': true});
    final fake = FakeBackend(results: [false, true]);
    BiometricService.overrideForTest(fake);
    await openGate(t);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('التطبيق مقفول'), findsOneWidget);
    await t.tap(find.text('حاول تاني'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('HOME'), findsOneWidget);
    expect(fake.calls, 2);
  });

  testWidgets('settings toggle can disable only after biometric confirm', (t) async {
    SharedPreferences.setMockInitialValues({'biometric_enabled_u1': true});
    final fake = FakeBackend(results: [false, true]);
    BiometricService.overrideForTest(fake);
    await t.pumpWidget(app(const Scaffold(
        body: BiometricToggleTile(uid: 'u1', isArabic: true))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.byKey(const Key('biometric_toggle_switch')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(await BiometricService().isEnabledForUser('u1'), isTrue); // auth failed
    await t.tap(find.byKey(const Key('biometric_toggle_switch')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(await BiometricService().isEnabledForUser('u1'), isFalse);
  });
}

// ---- NotificationPresenter ----
void presenterTests() {
  group('NotificationPresenter', () {
    setUp(() {
      NotificationDedupe.reset();
      NotificationPresenter.isForegroundOverride = () => true;
    });

    test('foreground: shows immediately, once per id', () async {
      var shown = 0;
      Future<void> go() => NotificationPresenter.present(
          docId: 'n1', sentByFcm: () async => true, show: () async => shown++);
      await go();
      await go();
      expect(shown, 1);
    });

    test('background + FCM already sent: does not show locally', () async {
      NotificationPresenter.isForegroundOverride = () => false;
      var shown = 0;
      await NotificationPresenter.present(
          docId: 'n2',
          grace: Duration.zero,
          sentByFcm: () async => true,
          show: () async => shown++);
      expect(shown, 0);
    });

    test('background + FCM not sent: shows locally (no dropped message)', () async {
      NotificationPresenter.isForegroundOverride = () => false;
      var shown = 0;
      await NotificationPresenter.present(
          docId: 'n3',
          grace: Duration.zero,
          sentByFcm: () async => false,
          show: () async => shown++);
      expect(shown, 1);
    });

    test('background + check fails: shows locally', () async {
      NotificationPresenter.isForegroundOverride = () => false;
      var shown = 0;
      await NotificationPresenter.present(
          docId: 'n4',
          grace: Duration.zero,
          sentByFcm: () async => throw Exception('offline'),
          show: () async => shown++);
      expect(shown, 1);
    });

    test('FCM foreground claim after listener shown is a no-op', () async {
      await NotificationPresenter.present(
          docId: 'n5', sentByFcm: () async => false, show: () async {});
      expect(NotificationDedupe.claim('n5'), isFalse);
    });
  });
}
