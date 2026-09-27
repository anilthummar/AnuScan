import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'secure_storage_service.dart';

/// Contract for application security, PIN management, and auto-lock lifecycle tracking.
abstract class SecurityService {
  Future<bool> isAppLockEnabled();
  Future<bool> isBiometricsEnabled();
  Future<void> setBiometricsEnabled(bool enabled);
  Future<int> getAutoLockTimeout();
  Future<void> setAutoLockTimeout(int seconds);

  Future<void> setPin(String pin);
  Future<bool> verifyPin(String pin);
  Future<bool> changePin(String oldPin, String newPin);
  Future<bool> disableAppLock(String pin);

  // Transient state tracking (scanner, camera, gallery picker, share sheet)
  void setTransientActivityActive(bool active);
  bool isTransientActivityActive();

  // Background / lifecycle tracking
  void onAppBackgrounded();
  void onAppResumed();
  Future<bool> shouldLockOnResume();
  void resetBackgroundTracker();
}

/// Implementation of [SecurityService] using salted SHA-256 hashing and [SecureStorageService].
class SecurityServiceImpl implements SecurityService {
  SecurityServiceImpl(this._secureStorage);

  final SecureStorageService _secureStorage;

  static const String keyPinSalt = 'anuscan_pin_salt';
  static const String keyPinHash = 'anuscan_pin_hash';
  static const String keyAppLockEnabled = 'anuscan_app_lock_enabled';
  static const String keyBiometricEnabled = 'anuscan_biometric_enabled';
  static const String keyAutoLockTimeout = 'anuscan_auto_lock_timeout';

  bool _isTransientActive = false;
  DateTime? _lastBackgroundedAt;

  @override
  Future<bool> isAppLockEnabled() async {
    final val = await _secureStorage.read(keyAppLockEnabled);
    if (val != 'true') return false;
    // Also verify pin hash exists
    final hash = await _secureStorage.read(keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  @override
  Future<bool> isBiometricsEnabled() async {
    final val = await _secureStorage.read(keyBiometricEnabled);
    return val == 'true';
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _secureStorage.write(keyBiometricEnabled, enabled ? 'true' : 'false');
  }

  @override
  Future<int> getAutoLockTimeout() async {
    final val = await _secureStorage.read(keyAutoLockTimeout);
    if (val == null) return 0; // Default: Immediately (0s)
    return int.tryParse(val) ?? 0;
  }

  @override
  Future<void> setAutoLockTimeout(int seconds) async {
    await _secureStorage.write(keyAutoLockTimeout, seconds.toString());
  }

  @override
  Future<void> setPin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits');
    }
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _secureStorage.write(keyPinSalt, salt);
    await _secureStorage.write(keyPinHash, hash);
    await _secureStorage.write(keyAppLockEnabled, 'true');
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final salt = await _secureStorage.read(keyPinSalt);
    final storedHash = await _secureStorage.read(keyPinHash);
    if (salt == null || storedHash == null) return false;

    final computedHash = _hashPin(pin, salt);
    return computedHash == storedHash;
  }

  @override
  Future<bool> changePin(String oldPin, String newPin) async {
    final isValid = await verifyPin(oldPin);
    if (!isValid) return false;

    await setPin(newPin);
    return true;
  }

  @override
  Future<bool> disableAppLock(String pin) async {
    final isValid = await verifyPin(pin);
    if (!isValid) return false;

    await _secureStorage.delete(keyPinSalt);
    await _secureStorage.delete(keyPinHash);
    await _secureStorage.write(keyAppLockEnabled, 'false');
    await _secureStorage.write(keyBiometricEnabled, 'false');
    return true;
  }

  @override
  void setTransientActivityActive(bool active) {
    _isTransientActive = active;
  }

  @override
  bool isTransientActivityActive() => _isTransientActive;

  @override
  void onAppBackgrounded() {
    if (!_isTransientActive) {
      _lastBackgroundedAt = DateTime.now();
    }
  }

  @override
  void onAppResumed() {
    // When resumed, if transient was active, we preserve the session
  }

  @override
  Future<bool> shouldLockOnResume() async {
    if (_isTransientActive) return false;

    final enabled = await isAppLockEnabled();
    if (!enabled) return false;

    if (_lastBackgroundedAt == null) return false;

    final timeoutSeconds = await getAutoLockTimeout();
    final elapsed = DateTime.now().difference(_lastBackgroundedAt!).inSeconds;

    return elapsed >= timeoutSeconds;
  }

  @override
  void resetBackgroundTracker() {
    _lastBackgroundedAt = null;
  }

  String _generateSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _hashPin(String pin, String saltHex) {
    final bytes = utf8.encode('$saltHex:$pin');
    return sha256.convert(bytes).toString();
  }
}
