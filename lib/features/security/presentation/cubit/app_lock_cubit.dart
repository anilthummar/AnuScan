import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/local_auth_service.dart';
import '../../../../core/services/security_service.dart';
import 'app_lock_state.dart';

class AppLockCubit extends Cubit<AppLockState> {
  AppLockCubit({required this.securityService, required this.localAuthService})
    : super(const AppLockState());

  final SecurityService securityService;
  final LocalAuthService localAuthService;

  Future<void> initialize() async {
    final enabled = await securityService.isAppLockEnabled();
    final bioEnabled = await securityService.isBiometricsEnabled();
    final timeout = await securityService.getAutoLockTimeout();

    final canCheck = await localAuthService.canCheckBiometrics();
    final isSupported = await localAuthService.isDeviceSupported();
    final canUseBio = canCheck || isSupported;

    emit(
      state.copyWith(
        isInitialized: true,
        isAppLockEnabled: enabled,
        isBiometricsEnabled: bioEnabled,
        canUseBiometrics: canUseBio,
        autoLockTimeout: timeout,
        isLocked: enabled,
        clearError: true,
      ),
    );

    if (enabled && bioEnabled && canUseBio) {
      await unlockWithBiometric();
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final isValid = await securityService.verifyPin(pin);
    if (isValid) {
      securityService.resetBackgroundTracker();
      emit(
        state.copyWith(isLocked: false, failedAttempts: 0, clearError: true),
      );
      return true;
    } else {
      emit(
        state.copyWith(
          failedAttempts: state.failedAttempts + 1,
          errorMessage: 'Incorrect PIN. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.isAppLockEnabled ||
        !state.isBiometricsEnabled ||
        !state.canUseBiometrics) {
      return false;
    }

    emit(state.copyWith(isAuthenticating: true, clearError: true));

    // Exclude biometric prompt from auto-lock background triggers
    securityService.setTransientActivityActive(true);
    try {
      final success = await localAuthService.authenticate(
        localizedReason: 'Authenticate to access AnuScan',
      );
      if (success) {
        securityService.resetBackgroundTracker();
        emit(
          state.copyWith(
            isLocked: false,
            isAuthenticating: false,
            failedAttempts: 0,
            clearError: true,
          ),
        );
        return true;
      } else {
        emit(state.copyWith(isAuthenticating: false));
        return false;
      }
    } catch (_) {
      emit(state.copyWith(isAuthenticating: false));
      return false;
    } finally {
      securityService.setTransientActivityActive(false);
    }
  }

  void lock() {
    if (state.isAppLockEnabled) {
      emit(state.copyWith(isLocked: true, clearError: true));
    }
  }

  void onAppPaused() {
    securityService.onAppBackgrounded();
  }

  Future<void> onAppResumed() async {
    securityService.onAppResumed();
    final shouldLock = await securityService.shouldLockOnResume();
    if (shouldLock) {
      emit(state.copyWith(isLocked: true, clearError: true));
      if (state.isBiometricsEnabled && state.canUseBiometrics) {
        await unlockWithBiometric();
      }
    }
  }

  Future<void> enableLock(String pin, {bool enableBiometrics = false}) async {
    await securityService.setPin(pin);
    if (enableBiometrics) {
      await securityService.setBiometricsEnabled(true);
    }

    emit(
      state.copyWith(
        isAppLockEnabled: true,
        isBiometricsEnabled: enableBiometrics,
        isLocked: false,
        clearError: true,
      ),
    );
  }

  Future<bool> disableLock(String pin) async {
    final success = await securityService.disableAppLock(pin);
    if (success) {
      emit(
        state.copyWith(
          isAppLockEnabled: false,
          isBiometricsEnabled: false,
          isLocked: false,
          clearError: true,
        ),
      );
      return true;
    } else {
      emit(
        state.copyWith(
          errorMessage: 'Incorrect PIN. Could not disable App Lock.',
        ),
      );
      return false;
    }
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    final success = await securityService.changePin(oldPin, newPin);
    if (success) {
      emit(state.copyWith(clearError: true));
      return true;
    } else {
      emit(state.copyWith(errorMessage: 'Current PIN is incorrect.'));
      return false;
    }
  }

  Future<void> setAutoLockTimeout(int seconds) async {
    await securityService.setAutoLockTimeout(seconds);
    emit(state.copyWith(autoLockTimeout: seconds));
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await securityService.setBiometricsEnabled(enabled);
    emit(state.copyWith(isBiometricsEnabled: enabled));
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
