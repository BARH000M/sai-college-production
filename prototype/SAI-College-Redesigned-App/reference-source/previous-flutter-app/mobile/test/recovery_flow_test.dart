import 'package:flutter_test/flutter_test.dart';
import 'package:sai_school/auth/recovery_flow.dart';

class _Recorder implements RecoveryGateway {
  final List<String> calls = <String>[];
  bool rejectVerification = false;
  bool rejectRequest = false;
  int passwordWrites = 0;
  bool rejectSignOut = false;
  int signOuts = 0;
  @override
  Future<void> requestCode(String email) async {
    if (rejectRequest) throw const RecoveryRejected('تعذّر إرسال البريد');
    calls.add('request');
  }

  @override
  Future<void> verifyCode(
      {required String email, required String token}) async {
    if (rejectVerification) throw const RecoveryRejected('الرمز غير صحيح');
    calls.add('verify');
  }

  @override
  Future<void> setPassword(String password) async {
    passwordWrites += 1;
    calls.add('password');
  }

  @override
  Future<void> signOut() async {
    signOuts += 1;
    if (rejectSignOut) {
      throw const RecoveryRejected('تعذّر إنهاء الجلسة على هذا الجهاز');
    }
    calls.add('signout');
  }
}

class _MemoryStore implements RecoveryCooldownStore {
  final Map<String, DateTime> sent = <String, DateTime>{};
  int writes = 0;
  @override
  Future<DateTime?> readSentAt(String email) async =>
      sent[email.trim().toLowerCase()];
  @override
  Future<void> writeSentAt(String email, DateTime at) async {
    writes += 1;
    sent[email.trim().toLowerCase()] = at;
  }

  @override
  Future<void> clearSentAt(String email) async {
    sent.remove(email.trim().toLowerCase());
  }
}

class _MemoryPendingStore implements RecoveryPendingSignOutStore {
  PendingSignOut? value;
  int writes = 0;
  int clears = 0;
  @override
  Future<PendingSignOut?> read() async => value;
  @override
  Future<void> write(PendingSignOut v) async {
    writes += 1;
    value = v;
  }

  @override
  Future<void> clear() async {
    clears += 1;
    value = null;
  }
}

class _BrokenPendingStore implements RecoveryPendingSignOutStore {
  @override
  Future<PendingSignOut?> read() async =>
      throw StateError('storage unavailable');
  @override
  Future<void> write(PendingSignOut v) async =>
      throw StateError('storage unavailable');
  @override
  Future<void> clear() async => throw StateError('storage unavailable');
}

class _ThrowingStore implements RecoveryCooldownStore {
  @override
  Future<DateTime?> readSentAt(String email) async =>
      throw StateError('storage unavailable');
  @override
  Future<void> writeSentAt(String email, DateTime at) async =>
      throw StateError('storage unavailable');
  @override
  Future<void> clearSentAt(String email) async =>
      throw StateError('storage unavailable');
}

void main() {
  group('recovery step order', () {
    test('a password can never be written before a code is verified', () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      expect(flow.step, RecoveryStep.codeSent);
      await expectLater(flow.submitPassword('LongEnough#1'),
          throwsA(isA<RecoveryStepError>()));
      expect(gateway.passwordWrites, 0);
      expect(gateway.calls, <String>['request']);
      expect(flow.step, RecoveryStep.codeSent);
      expect(flow.canSetPassword, isFalse);
    });
    test('verification itself is refused before a code was requested',
        () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await expectLater(
          flow.verifyCode('123456'), throwsA(isA<RecoveryStepError>()));
      expect(gateway.calls, isEmpty);
      expect(flow.step, RecoveryStep.idle);
    });
    test(
        'the successful path runs request → verify → password → signout, in that order',
        () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await flow.submitPassword('LongEnough#1');
      expect(
          gateway.calls, <String>['request', 'verify', 'password', 'signout']);
      expect(flow.steps, <String>['request', 'verify', 'password', 'signout']);
      expect(flow.step, RecoveryStep.signedOut);
      expect(flow.isComplete, isTrue);
      expect(flow.needsSignOut, isFalse);
      expect(flow.canSetPassword, isFalse);
    });
    test('a rejected code rolls back to codeSent and blocks the password',
        () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      gateway.rejectVerification = true;
      await expectLater(
          flow.verifyCode('000000'), throwsA(isA<RecoveryRejected>()));
      expect(flow.step, RecoveryStep.codeSent);
      expect(flow.canSetPassword, isFalse);
      await expectLater(flow.submitPassword('LongEnough#1'),
          throwsA(isA<RecoveryStepError>()));
      expect(gateway.passwordWrites, 0);
      expect(gateway.calls, <String>['request']);
    });
    test('a failed send never moves the machine forward', () async {
      final gateway = _Recorder()..rejectRequest = true;
      final flow = RecoveryFlow(gateway: gateway);
      await expectLater(flow.requestCode('user@sai-college.com'),
          throwsA(isA<RecoveryRejected>()));
      expect(flow.step, RecoveryStep.idle);
      expect(flow.email, isEmpty);
      expect(flow.steps, isEmpty);
      await expectLater(
          flow.verifyCode('123456'), throwsA(isA<RecoveryStepError>()));
    });
    test('requesting a new code invalidates a previous verification', () async {
      var clock = DateTime(2026, 3, 1, 9);
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway, now: () => clock);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      expect(flow.canSetPassword, isTrue);
      clock = clock.add(const Duration(seconds: 61));
      await flow.requestCode('user@sai-college.com');
      expect(flow.step, RecoveryStep.codeSent);
      expect(flow.canSetPassword, isFalse);
      await expectLater(flow.submitPassword('LongEnough#1'),
          throwsA(isA<RecoveryStepError>()));
      expect(gateway.passwordWrites, 0);
    });
    test('a password is submitted exactly once', () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await flow.submitPassword('LongEnough#1');
      await expectLater(flow.submitPassword('AnotherPass#2'),
          throwsA(isA<RecoveryStepError>()));
      expect(gateway.passwordWrites, 1);
    });
  });

  group('input validation before any gateway call', () {
    test('a malformed address is refused locally', () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      for (final bad in <String>[
        '',
        '   ',
        'not-an-email',
        'a@b',
        '@sai-college.com'
      ]) {
        await expectLater(
            flow.requestCode(bad), throwsA(isA<RecoveryRejected>()),
            reason: '«$bad» must be rejected before the network');
      }
      expect(gateway.calls, isEmpty);
      expect(flow.step, RecoveryStep.idle);
    });
    test('a blank token is refused without calling verify', () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      await expectLater(
          flow.verifyCode('   '), throwsA(isA<RecoveryRejected>()));
      expect(gateway.calls, <String>['request']);
      expect(flow.step, RecoveryStep.codeSent);
    });
    test('a short password is refused without calling setPassword', () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await expectLater(
          flow.submitPassword('short'), throwsA(isA<RecoveryRejected>()));
      expect(gateway.passwordWrites, 0);
      expect(flow.step, RecoveryStep.verified);
      expect(flow.canSetPassword, isTrue);
    });
  });

  group('ordering invariant', () {
    test('no recorded step log can ever contain password before verify',
        () async {
      final scenarios = <Future<void> Function(RecoveryFlow, _Recorder)>[
        (flow, _) async => flow.requestCode('user@sai-college.com'),
        (flow, gateway) async {
          await flow.requestCode('user@sai-college.com');
          gateway.rejectVerification = true;
          try {
            await flow.verifyCode('000000');
          } on RecoveryRejected {
            expect(gateway.calls, <String>['request']);
          }
        },
        (flow, _) async {
          await flow.requestCode('user@sai-college.com');
          await flow.verifyCode('123456');
        },
        (flow, _) async {
          await flow.requestCode('user@sai-college.com');
          await flow.verifyCode('123456');
          await flow.submitPassword('LongEnough#1');
        },
      ];
      for (final run in scenarios) {
        final gateway = _Recorder();
        final flow = RecoveryFlow(gateway: gateway);
        await run(flow, gateway);
        if (flow.steps.contains('password')) {
          expect(flow.steps.indexOf('verify'),
              lessThan(flow.steps.indexOf('password')));
        }
        if (flow.steps.contains('signout')) {
          expect(flow.steps.indexOf('password'),
              lessThan(flow.steps.indexOf('signout')));
          expect(flow.isComplete, isTrue);
        }
        expect(gateway.passwordWrites,
            flow.steps.where((s) => s == 'password').length);
      }
    });
  });

  group('explicit sign-out step', () {
    test('the session is dropped exactly once, after the password write',
        () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await flow.submitPassword('LongEnough#1');
      expect(gateway.signOuts, 1);
      expect(flow.steps.last, 'signout');
      expect(flow.isComplete, isTrue);
    });
    test('a failed sign-out is NOT reported as a completed recovery', () async {
      final gateway = _Recorder()..rejectSignOut = true;
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await expectLater(flow.submitPassword('LongEnough#1'),
          throwsA(isA<RecoveryRejected>()));
      expect(flow.step, RecoveryStep.passwordUpdated);
      expect(flow.isComplete, isFalse);
      expect(flow.needsSignOut, isTrue);
      expect(flow.steps, <String>['request', 'verify', 'password']);
      expect(flow.steps.contains('signout'), isFalse);
    });
    test('the sign-out can be retried without writing the password again',
        () async {
      final gateway = _Recorder()..rejectSignOut = true;
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await expectLater(flow.submitPassword('LongEnough#1'),
          throwsA(isA<RecoveryRejected>()));
      gateway.rejectSignOut = false;
      await flow.completeSignOut();
      expect(gateway.passwordWrites, 1);
      expect(flow.step, RecoveryStep.signedOut);
      expect(flow.steps, <String>['request', 'verify', 'password', 'signout']);
    });
    test('a sign-out cannot be claimed before a password was written',
        () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await expectLater(
          flow.completeSignOut(), throwsA(isA<RecoveryStepError>()));
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await expectLater(
          flow.completeSignOut(), throwsA(isA<RecoveryStepError>()));
      expect(gateway.signOuts, 0);
      expect(flow.isComplete, isFalse);
    });
  });

  group('resend cooldown', () {
    test('a second request inside 60 seconds never reaches the gateway',
        () async {
      var clock = DateTime(2026, 3, 1, 9);
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway, now: () => clock);
      await flow.requestCode('user@sai-college.com');
      expect(flow.canResend, isFalse);
      expect(flow.resendRemaining, const Duration(seconds: 60));
      await expectLater(flow.requestCode('user@sai-college.com'),
          throwsA(isA<RecoveryRejected>()));
      expect(gateway.calls, <String>['request']);
      expect(flow.step, RecoveryStep.codeSent);
    });
    test(
        'the cooldown releases at exactly 60 seconds, and not a millisecond before',
        () async {
      var clock = DateTime(2026, 3, 1, 9);
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway, now: () => clock);
      await flow.requestCode('user@sai-college.com');
      clock = clock.add(const Duration(seconds: 59, milliseconds: 999));
      expect(flow.canResend, isFalse);
      await expectLater(flow.requestCode('user@sai-college.com'),
          throwsA(isA<RecoveryRejected>()));
      clock = clock.add(const Duration(milliseconds: 1));
      expect(flow.canResend, isTrue);
      expect(flow.resendRemaining, Duration.zero);
      await flow.requestCode('user@sai-college.com');
      expect(gateway.calls, <String>['request', 'request']);
    });
    test('a failed send does not start a cooldown', () async {
      final gateway = _Recorder()..rejectRequest = true;
      final flow = RecoveryFlow(gateway: gateway);
      await expectLater(flow.requestCode('user@sai-college.com'),
          throwsA(isA<RecoveryRejected>()));
      expect(flow.canResend, isTrue);
      expect(flow.resendRemaining, Duration.zero);
      expect(flow.step, RecoveryStep.idle);
    });
    test('the remaining time counts down and never goes negative', () async {
      var clock = DateTime(2026, 3, 1, 9);
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway, now: () => clock);
      await flow.requestCode('user@sai-college.com');
      clock = clock.add(const Duration(seconds: 15));
      expect(flow.resendRemaining, const Duration(seconds: 45));
      clock = clock.add(const Duration(seconds: 40));
      expect(flow.resendRemaining, const Duration(seconds: 5));
      clock = clock.add(const Duration(days: 3));
      expect(flow.resendRemaining, Duration.zero);
      expect(flow.canResend, isTrue);
    });
    test('resetting the flow clears the cooldown', () async {
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway);
      await flow.requestCode('user@sai-college.com');
      expect(flow.canResend, isFalse);
      flow.reset();
      expect(flow.canResend, isTrue);
      expect(flow.step, RecoveryStep.idle);
      await flow.requestCode('user@sai-college.com');
      expect(gateway.calls, <String>['request', 'request']);
    });
  });

  group('persisted cooldown (survives a force-quit)', () {
    test('a fresh flow on the same device is still blocked by the stored stamp',
        () async {
      final store = _MemoryStore();
      final clock = DateTime(2026, 3, 1, 9);
      final first = RecoveryFlow(
          gateway: _Recorder(), cooldownStore: store, now: () => clock);
      await first.requestCode('user@sai-college.com');
      expect(store.writes, 1);
      final appKilled = _Recorder();
      final second = RecoveryFlow(
          gateway: appKilled,
          cooldownStore: store,
          now: () => clock.add(const Duration(seconds: 5)));
      await expectLater(second.requestCode('user@sai-college.com'),
          throwsA(isA<RecoveryRejected>()));
      expect(appKilled.calls, isEmpty);
      expect(second.step, RecoveryStep.idle);
    });
    test('the persisted cooldown releases once the real minute has passed',
        () async {
      final store = _MemoryStore();
      final clock = DateTime(2026, 3, 1, 9);
      await RecoveryFlow(
          gateway: _Recorder(),
          cooldownStore: store,
          now: () => clock).requestCode('user@sai-college.com');
      final gateway = _Recorder();
      final reopened = RecoveryFlow(
          gateway: gateway,
          cooldownStore: store,
          now: () => clock.add(const Duration(seconds: 60)));
      await reopened.requestCode('user@sai-college.com');
      expect(gateway.calls, <String>['request']);
    });
    test('the stamp is keyed per address, so it cannot block a colleague',
        () async {
      final store = _MemoryStore();
      final clock = DateTime(2026, 3, 1, 9);
      await RecoveryFlow(
          gateway: _Recorder(),
          cooldownStore: store,
          now: () => clock).requestCode('first@sai-college.com');
      final gateway = _Recorder();
      final second = RecoveryFlow(
          gateway: gateway, cooldownStore: store, now: () => clock);
      await second.requestCode('second@sai-college.com');
      expect(gateway.calls, <String>['request']);
    });
    test('a failed send writes nothing to the store', () async {
      final store = _MemoryStore();
      final flow = RecoveryFlow(
          gateway: _Recorder()..rejectRequest = true, cooldownStore: store);
      await expectLater(flow.requestCode('user@sai-college.com'),
          throwsA(isA<RecoveryRejected>()));
      expect(store.writes, 0);
      expect(await store.readSentAt('user@sai-college.com'), isNull);
    });
    test('a broken store degrades to in-memory enforcement instead of failing',
        () async {
      final flow =
          RecoveryFlow(gateway: _Recorder(), cooldownStore: _ThrowingStore());
      await flow.requestCode('user@sai-college.com');
      expect(flow.step, RecoveryStep.codeSent);
      expect(flow.canResend, isFalse);
    });
  });

  group('persisted pending sign-out (survives a force-quit mid-recovery)', () {
    test('the marker is written before the sign-out is attempted', () async {
      final store = _MemoryPendingStore();
      final gateway = _Recorder()..rejectSignOut = true;
      final flow = RecoveryFlow(gateway: gateway, pendingSignOutStore: store);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await expectLater(flow.submitPassword('LongEnough#1'),
          throwsA(isA<RecoveryRejected>()));
      expect(store.writes, 1);
      expect(store.value, isNotNull);
      expect(store.value!.email, 'user@sai-college.com');
      expect(store.clears, 0);
    });
    test(
        'a fresh process resumes at finish the sign-out, not at the email step',
        () async {
      final store = _MemoryPendingStore();
      final clock = DateTime(2026, 3, 1, 9);
      final first = RecoveryFlow(
          gateway: _Recorder()..rejectSignOut = true,
          pendingSignOutStore: store,
          now: () => clock);
      await first.requestCode('user@sai-college.com');
      await first.verifyCode('123456');
      await expectLater(first.submitPassword('LongEnough#1'),
          throwsA(isA<RecoveryRejected>()));
      final gateway = _Recorder();
      final reopened =
          RecoveryFlow(gateway: gateway, pendingSignOutStore: store);
      expect(reopened.step, RecoveryStep.idle);
      expect(await reopened.resumePendingSignOut(), isTrue);
      expect(reopened.step, RecoveryStep.passwordUpdated);
      expect(reopened.needsSignOut, isTrue);
      expect(reopened.isComplete, isFalse);
      expect(reopened.email, 'user@sai-college.com');
      expect(reopened.steps, <String>['password']);
      await reopened.completeSignOut();
      expect(reopened.step, RecoveryStep.signedOut);
      expect(reopened.isComplete, isTrue);
      expect(gateway.passwordWrites, 0);
      expect(gateway.calls, <String>['signout']);
    });
    test('the marker is cleared only after a sign-out that actually worked',
        () async {
      final store = _MemoryPendingStore();
      final gateway = _Recorder();
      final flow = RecoveryFlow(gateway: gateway, pendingSignOutStore: store);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await flow.submitPassword('LongEnough#1');
      expect(flow.isComplete, isTrue);
      expect(store.clears, 1);
      expect(store.value, isNull);
      final later =
          RecoveryFlow(gateway: _Recorder(), pendingSignOutStore: store);
      expect(await later.resumePendingSignOut(), isFalse);
      expect(later.step, RecoveryStep.idle);
    });
    test('resume never overwrites a flow that already has state', () async {
      final store = _MemoryPendingStore()
        ..value = PendingSignOut(
            email: 'old@sai-college.com', changedAt: DateTime(2026, 3, 1));
      final flow =
          RecoveryFlow(gateway: _Recorder(), pendingSignOutStore: store);
      await flow.requestCode('new@sai-college.com');
      expect(await flow.resumePendingSignOut(), isFalse);
      expect(flow.step, RecoveryStep.codeSent);
      expect(flow.email, 'new@sai-college.com');
    });
    test('a broken pending store cannot stop the app from starting', () async {
      final flow = RecoveryFlow(
          gateway: _Recorder(), pendingSignOutStore: _BrokenPendingStore());
      expect(await flow.resumePendingSignOut(), isFalse);
      expect(flow.step, RecoveryStep.idle);
      await flow.requestCode('user@sai-college.com');
      await flow.verifyCode('123456');
      await flow.submitPassword('LongEnough#1');
      expect(flow.isComplete, isTrue);
    });
  });
}
