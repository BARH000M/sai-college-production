library;

enum RecoveryStep { idle, codeSent, verified, passwordUpdated, signedOut }

class RecoveryStepError implements Exception {
  const RecoveryStepError({required this.attempted, required this.actual});
  final RecoveryStep attempted;
  final RecoveryStep actual;
  @override
  String toString() =>
      'RecoveryStepError: attempted ${attempted.name} while in ${actual.name}';
}

class RecoveryRejected implements Exception {
  const RecoveryRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class RecoveryGateway {
  Future<void> requestCode(String email);
  Future<void> verifyCode({required String email, required String token});
  Future<void> setPassword(String password);
  Future<void> signOut();
}

abstract class RecoveryCooldownStore {
  Future<DateTime?> readSentAt(String email);
  Future<void> writeSentAt(String email, DateTime at);
  Future<void> clearSentAt(String email);
}

class PendingSignOut {
  const PendingSignOut({required this.email, required this.changedAt});
  final String email;
  final DateTime changedAt;
  @override
  String toString() => 'PendingSignOut($email @ $changedAt)';
}

abstract class RecoveryPendingSignOutStore {
  Future<PendingSignOut?> read();
  Future<void> write(PendingSignOut value);
  Future<void> clear();
}

const int recoveryMinPasswordLength = 8;
const Duration defaultResendCooldown = Duration(seconds: 60);
final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class RecoveryFlow {
  RecoveryFlow(
      {required RecoveryGateway gateway,
      this.minPasswordLength = recoveryMinPasswordLength,
      this.resendCooldown = defaultResendCooldown,
      RecoveryCooldownStore? cooldownStore,
      RecoveryPendingSignOutStore? pendingSignOutStore,
      DateTime Function()? now})
      : _gateway = gateway,
        _cooldownStore = cooldownStore,
        _pendingStore = pendingSignOutStore,
        _now = now ?? DateTime.now;

  final RecoveryGateway _gateway;
  final RecoveryCooldownStore? _cooldownStore;
  final RecoveryPendingSignOutStore? _pendingStore;
  final int minPasswordLength;
  final DateTime Function() _now;
  final Duration resendCooldown;
  final List<String> _steps = <String>[];
  RecoveryStep _step = RecoveryStep.idle;
  String _email = '';
  bool _busy = false;
  DateTime? _lastSentAt;
  String? _lastSentEmail;
  PendingSignOut? _pendingSignOut;

  RecoveryStep get step => _step;
  String get email => _email;
  bool get busy => _busy;
  bool get canSetPassword => _step == RecoveryStep.verified;
  bool get isComplete => _step == RecoveryStep.signedOut;
  bool get needsSignOut => _step == RecoveryStep.passwordUpdated;
  PendingSignOut? get pendingSignOut => _pendingSignOut;

  Duration get resendRemaining {
    final sentAt = _lastSentAt;
    if (sentAt == null) return Duration.zero;
    if (_lastSentEmail != null &&
        _email.isNotEmpty &&
        _lastSentEmail != _email) {
      return Duration.zero;
    }
    final left = resendCooldown - _now().difference(sentAt);
    return left.isNegative ? Duration.zero : left;
  }

  bool get canResend => resendRemaining == Duration.zero;
  List<String> get steps => List<String>.unmodifiable(_steps);

  Future<void> requestCode(String rawEmail) async {
    _guardIdle();
    final value = rawEmail.trim();
    if (!_emailPattern.hasMatch(value)) {
      throw const RecoveryRejected('صيغة البريد الإلكتروني غير صحيحة');
    }
    final stored = await _readStoredSentAt(value);
    if (stored != null &&
        (_lastSentAt == null || stored.isAfter(_lastSentAt!))) {
      _lastSentAt = stored;
      _lastSentEmail = value;
    }
    final wait = resendRemaining;
    if (wait > Duration.zero) {
      final seconds = (wait.inMilliseconds / 1000).ceil();
      throw RecoveryRejected('يمكنك إعادة الإرسال بعد $seconds ثانية');
    }
    _busy = true;
    try {
      await _gateway.requestCode(value);
      _email = value;
      _steps.add('request');
      _step = RecoveryStep.codeSent;
      _lastSentAt = _now();
      _lastSentEmail = value;
      await _persistSentAt(value, _lastSentAt!);
    } finally {
      _busy = false;
    }
  }

  Future<void> verifyCode(String rawToken) async {
    _guardIdle();
    if (_step != RecoveryStep.codeSent) {
      throw RecoveryStepError(attempted: RecoveryStep.verified, actual: _step);
    }
    final token = rawToken.trim();
    if (token.isEmpty) {
      throw const RecoveryRejected('أدخل الرمز المرسل إلى بريدك');
    }
    _busy = true;
    try {
      await _gateway.verifyCode(email: _email, token: token);
      _steps.add('verify');
      _step = RecoveryStep.verified;
    } catch (_) {
      _step = RecoveryStep.codeSent;
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> submitPassword(String password) async {
    _guardIdle();
    if (_step != RecoveryStep.verified) {
      throw RecoveryStepError(
          attempted: RecoveryStep.passwordUpdated, actual: _step);
    }
    if (password.length < minPasswordLength) {
      throw RecoveryRejected(
          'كلمة المرور يجب أن تكون $minPasswordLength أحرف على الأقل');
    }
    _busy = true;
    try {
      await _gateway.setPassword(password);
      _steps.add('password');
      _step = RecoveryStep.passwordUpdated;
    } finally {
      _busy = false;
    }
    final pending = PendingSignOut(email: _email, changedAt: _now());
    _pendingSignOut = pending;
    await _persistPending(pending);
    await completeSignOut();
  }

  Future<void> completeSignOut() async {
    _guardIdle();
    if (_step != RecoveryStep.passwordUpdated) {
      throw RecoveryStepError(attempted: RecoveryStep.signedOut, actual: _step);
    }
    _busy = true;
    try {
      await _gateway.signOut();
      _steps.add('signout');
      _step = RecoveryStep.signedOut;
    } finally {
      _busy = false;
    }
    _pendingSignOut = null;
    await _clearPending();
  }

  Future<bool> resumePendingSignOut() async {
    if (_step != RecoveryStep.idle) return false;
    final store = _pendingStore;
    if (store == null) return false;
    PendingSignOut? pending;
    try {
      pending = await store.read();
    } catch (_) {
      return false;
    }
    if (pending == null) return false;
    _pendingSignOut = pending;
    _email = pending.email;
    if (!_steps.contains('password')) _steps.add('password');
    _step = RecoveryStep.passwordUpdated;
    return true;
  }

  void reset() {
    _steps.clear();
    _step = RecoveryStep.idle;
    _email = '';
    _busy = false;
    _lastSentAt = null;
    _lastSentEmail = null;
  }

  void _guardIdle() {
    if (_busy) {
      throw const RecoveryRejected('عملية أخرى قيد التنفيذ — انتظر لحظة');
    }
  }

  Future<void> _persistPending(PendingSignOut value) async {
    final store = _pendingStore;
    if (store == null) return;
    try {
      await store.write(value);
    } catch (_) {}
  }

  Future<void> _clearPending() async {
    final store = _pendingStore;
    if (store == null) return;
    try {
      await store.clear();
    } catch (_) {}
  }

  Future<DateTime?> _readStoredSentAt(String email) async {
    final store = _cooldownStore;
    if (store == null) return null;
    try {
      return await store.readSentAt(email);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistSentAt(String email, DateTime at) async {
    final store = _cooldownStore;
    if (store == null) return;
    try {
      await store.writeSentAt(email, at);
    } catch (_) {}
  }
}
