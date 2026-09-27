import 'package:local_auth/local_auth.dart';

/// Contract for biometric and local hardware authentication.
abstract class LocalAuthService {
  Future<bool> canCheckBiometrics();
  Future<bool> isDeviceSupported();
  Future<List<BiometricType>> getAvailableBiometrics();
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  });
  Future<bool> stopAuthentication();
}

/// Implementation of [LocalAuthService] utilizing [LocalAuthentication].
class LocalAuthServiceImpl implements LocalAuthService {
  LocalAuthServiceImpl({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopAuthentication() async {
    try {
      return await _auth.stopAuthentication();
    } catch (_) {
      return false;
    }
  }
}
