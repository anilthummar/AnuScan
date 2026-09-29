import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/services/secure_storage_service.dart';
import 'package:anuscan/core/services/security_service.dart';

class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }
}

void main() {
  late InMemorySecureStorageService secureStorage;
  late SecurityServiceImpl securityService;

  setUp(() {
    secureStorage = InMemorySecureStorageService();
    securityService = SecurityServiceImpl(secureStorage);
  });

  group('SecurityService Tests', () {
    test('initial state has app lock disabled', () async {
      expect(await securityService.isAppLockEnabled(), isFalse);
      expect(await securityService.isBiometricsEnabled(), isFalse);
    });

    test('setPin enables app lock and verifies valid PIN', () async {
      await securityService.setPin('1234');
      expect(await securityService.isAppLockEnabled(), isTrue);

      expect(await securityService.verifyPin('1234'), isTrue);
      expect(await securityService.verifyPin('0000'), isFalse);
      expect(await securityService.verifyPin(''), isFalse);
    });

    test('changePin validates old pin before updating', () async {
      await securityService.setPin('1234');

      final failed = await securityService.changePin('wrong', '5678');
      expect(failed, isFalse);
      expect(await securityService.verifyPin('1234'), isTrue);

      final success = await securityService.changePin('1234', '5678');
      expect(success, isTrue);
      expect(await securityService.verifyPin('5678'), isTrue);
      expect(await securityService.verifyPin('1234'), isFalse);
    });

    test('disableAppLock requires valid PIN', () async {
      await securityService.setPin('1234');

      final failed = await securityService.disableAppLock('9999');
      expect(failed, isFalse);
      expect(await securityService.isAppLockEnabled(), isTrue);

      final success = await securityService.disableAppLock('1234');
      expect(success, isTrue);
      expect(await securityService.isAppLockEnabled(), isFalse);
    });

    test('biometrics toggle and auto lock timeout settings', () async {
      await securityService.setBiometricsEnabled(true);
      expect(await securityService.isBiometricsEnabled(), isTrue);

      await securityService.setAutoLockTimeout(60);
      expect(await securityService.getAutoLockTimeout(), equals(60));
    });

    test('transient activity and background tracker lifecycle', () async {
      securityService.setTransientActivityActive(true);
      expect(securityService.isTransientActivityActive(), isTrue);

      securityService.setTransientActivityActive(false);
      expect(securityService.isTransientActivityActive(), isFalse);
    });
  });
}
