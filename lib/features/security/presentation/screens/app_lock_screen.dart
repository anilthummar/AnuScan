import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/app_lock_cubit.dart';
import '../cubit/app_lock_state.dart';

/// Screen displayed when the app is locked, or when prompting for PIN verification.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    this.title,
    this.subtitle,
    this.isModal = false,
    this.onVerifyPin,
    this.onSuccess,
    this.pinLength = 4,
  });

  final String? title;
  final String? subtitle;
  final bool isModal;
  final Future<bool> Function(String pin)? onVerifyPin;
  final VoidCallback? onSuccess;
  final int pinLength;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _enteredPin = '';
  bool _isVerifying = false;
  String? _localError;

  void _onKeyTap(String digit) {
    if (_isVerifying || _enteredPin.length >= widget.pinLength) return;

    setState(() {
      _localError = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == widget.pinLength) {
      _submitPin(_enteredPin);
    }
  }

  void _onBackspace() {
    if (_isVerifying || _enteredPin.isEmpty) return;
    setState(() {
      _localError = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _submitPin(String pin) async {
    setState(() => _isVerifying = true);

    try {
      bool success = false;
      if (widget.onVerifyPin != null) {
        success = await widget.onVerifyPin!(pin);
      } else {
        success = await context.read<AppLockCubit>().unlockWithPin(pin);
      }

      if (!mounted) return;

      if (success) {
        widget.onSuccess?.call();
        if (widget.isModal && Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _enteredPin = '';
          _localError = 'Incorrect PIN. Please try again.';
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enteredPin = '';
        _localError = 'Verification failed. Try again.';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<AppLockCubit, AppLockState>(
      listener: (context, state) {
        if (!state.isLocked && !widget.isModal) {
          widget.onSuccess?.call();
        }
      },
      builder: (context, state) {
        final errorText = _localError ?? state.errorMessage;

        return PopScope(
          canPop: widget.isModal,
          child: Scaffold(
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight,
            appBar: widget.isModal
                ? AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  )
                : null,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 1),
                      // Security Icon / Badge
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.title ?? 'AnuScan Protected',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle ?? 'Enter PIN to unlock',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // PIN Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.pinLength, (index) {
                          final isFilled = index < _enteredPin.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled
                                  ? (errorText != null
                                        ? AppColors.error
                                        : AppColors.primary)
                                  : Colors.transparent,
                              border: Border.all(
                                color: errorText != null
                                    ? AppColors.error
                                    : (isDark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Error message or loading state
                      SizedBox(
                        height: 24,
                        child: _isVerifying || state.isAuthenticating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : (errorText != null
                                  ? Text(
                                      errorText,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : null),
                      ),

                      const Spacer(flex: 1),

                      // Numeric Keypad
                      _buildKeypad(context, state),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeypad(BuildContext context, AppLockState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitButton('1'),
              _buildDigitButton('2'),
              _buildDigitButton('3'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitButton('4'),
              _buildDigitButton('5'),
              _buildDigitButton('6'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitButton('7'),
              _buildDigitButton('8'),
              _buildDigitButton('9'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Biometric or empty
              if (!widget.isModal &&
                  state.isBiometricsEnabled &&
                  state.canUseBiometrics)
                _buildActionButton(
                  icon: Icons.fingerprint,
                  onPressed: () =>
                      context.read<AppLockCubit>().unlockWithBiometric(),
                )
              else
                const SizedBox(width: 68, height: 68),
              _buildDigitButton('0'),
              _buildActionButton(
                icon: Icons.backspace_outlined,
                onPressed: _onBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitButton(String digit) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onKeyTap(digit),
          child: Center(
            child: Text(
              digit,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(child: Icon(icon, size: 28, color: AppColors.primary)),
        ),
      ),
    );
  }
}
