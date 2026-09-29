import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/local_auth_service.dart';
import 'package:anuscan/core/services/security_service.dart';
import 'package:anuscan/features/security/presentation/cubit/app_lock_cubit.dart';

class MockSecurityService extends Mock implements SecurityService {}
class MockLocalAuthService extends Mock implements LocalAuthService {}

void main() {
  late MockSecurityService mockSecurity;
  late MockLocalAuthService mockLocalAuth;
  late AppLockCubit cubit;

  setUp(() {
    mockSecurity = MockSecurityService();
    mockLocalAuth = MockLocalAuthService();

    when(() => mockSecurity.isAppLockEnabled()).thenAnswer((_) async => false);
    when(() => mockSecurity.isBiometricsEnabled()).thenAnswer((_) async => false);
    when(() => mockSecurity.getAutoLockTimeout()).thenAnswer((_) async => 0);
    when(() => mockLocalAuth.canCheckBiometrics()).thenAnswer((_) async => false);
    when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

    cubit = AppLockCubit(
      securityService: mockSecurity,
      localAuthService: mockLocalAuth,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('AppLockCubit Tests', () {
    test('initial state is uninitialized and unlocked', () {
      expect(cubit.state.isInitialized, isFalse);
      expect(cubit.state.isLocked, isFalse);
    });

    test('initialize loads disabled app lock correctly', () async {
      await cubit.initialize();

      expect(cubit.state.isInitialized, isTrue);
      expect(cubit.state.isAppLockEnabled, isFalse);
      expect(cubit.state.isLocked, isFalse);
    });

    test('initialize locks app when app lock is enabled', () async {
      when(() => mockSecurity.isAppLockEnabled()).thenAnswer((_) async => true);

      await cubit.initialize();

      expect(cubit.state.isInitialized, isTrue);
      expect(cubit.state.isAppLockEnabled, isTrue);
      expect(cubit.state.isLocked, isTrue);
    });

    test('unlockWithPin succeeds with valid PIN', () async {
      when(() => mockSecurity.isAppLockEnabled()).thenAnswer((_) async => true);
      when(() => mockSecurity.verifyPin('1234')).thenAnswer((_) async => true);

      await cubit.initialize();
      expect(cubit.state.isLocked, isTrue);

      final result = await cubit.unlockWithPin('1234');
      expect(result, isTrue);
      expect(cubit.state.isLocked, isFalse);
      expect(cubit.state.failedAttempts, equals(0));
      verify(() => mockSecurity.resetBackgroundTracker()).called(1);
    });

    test('unlockWithPin fails and increments failedAttempts with invalid PIN', () async {
      when(() => mockSecurity.isAppLockEnabled()).thenAnswer((_) async => true);
      when(() => mockSecurity.verifyPin('9999')).thenAnswer((_) async => false);

      await cubit.initialize();
      expect(cubit.state.isLocked, isTrue);

      final result = await cubit.unlockWithPin('9999');
      expect(result, isFalse);
      expect(cubit.state.isLocked, isTrue);
      expect(cubit.state.failedAttempts, equals(1));
      expect(cubit.state.errorMessage, isNotNull);
    });
  });
}
