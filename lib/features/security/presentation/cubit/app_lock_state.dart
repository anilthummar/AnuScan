import 'package:equatable/equatable.dart';

class AppLockState extends Equatable {
  const AppLockState({
    this.isInitialized = false,
    this.isAppLockEnabled = false,
    this.isLocked = false,
    this.isBiometricsEnabled = false,
    this.canUseBiometrics = false,
    this.autoLockTimeout = 0,
    this.isAuthenticating = false,
    this.errorMessage,
    this.failedAttempts = 0,
  });

  final bool isInitialized;
  final bool isAppLockEnabled;
  final bool isLocked;
  final bool isBiometricsEnabled;
  final bool canUseBiometrics;
  final int autoLockTimeout;
  final bool isAuthenticating;
  final String? errorMessage;
  final int failedAttempts;

  AppLockState copyWith({
    bool? isInitialized,
    bool? isAppLockEnabled,
    bool? isLocked,
    bool? isBiometricsEnabled,
    bool? canUseBiometrics,
    int? autoLockTimeout,
    bool? isAuthenticating,
    String? errorMessage,
    bool clearError = false,
    int? failedAttempts,
  }) {
    return AppLockState(
      isInitialized: isInitialized ?? this.isInitialized,
      isAppLockEnabled: isAppLockEnabled ?? this.isAppLockEnabled,
      isLocked: isLocked ?? this.isLocked,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }

  @override
  List<Object?> get props => [
    isInitialized,
    isAppLockEnabled,
    isLocked,
    isBiometricsEnabled,
    canUseBiometrics,
    autoLockTimeout,
    isAuthenticating,
    errorMessage,
    failedAttempts,
  ];
}
