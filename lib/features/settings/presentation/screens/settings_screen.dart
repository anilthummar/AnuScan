import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../security/presentation/cubit/app_lock_cubit.dart';
import '../../../security/presentation/cubit/app_lock_state.dart';
import '../../../security/presentation/screens/app_lock_screen.dart';

/// Settings screen for configuring app preferences, storage and offline mode.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _highResolutionCapture = true;
  String _defaultPageFormat = 'A4';
  int _imageCompressionQuality = 92;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Privacy & Offline Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppColors.success,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Offline & Private',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'All documents are stored exclusively on your device. No cloud sync, no tracking.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scanning & Processing Preferences
          const _SectionHeader(title: 'SCANNING & PROCESSING'),
          SwitchListTile(
            secondary: const Icon(Icons.high_quality),
            title: const Text('High Quality Capture'),
            subtitle: const Text('Retains original camera sensor resolution'),
            value: _highResolutionCapture,
            onChanged: (val) {
              setState(() => _highResolutionCapture = val);
            },
          ),
          ListTile(
            leading: const Icon(Icons.aspect_ratio),
            title: const Text('Default PDF Page Format'),
            subtitle: Text('Current: $_defaultPageFormat Standard'),
            trailing: DropdownButton<String>(
              value: _defaultPageFormat,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'A4', child: Text('A4 Standard')),
                DropdownMenuItem(value: 'Letter', child: Text('US Letter')),
                DropdownMenuItem(value: 'Fit', child: Text('Auto Fit')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _defaultPageFormat = val);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.compress),
            title: const Text('Image Compression Quality'),
            subtitle: Slider(
              value: _imageCompressionQuality.toDouble(),
              min: 50,
              max: 100,
              divisions: 10,
              label: '$_imageCompressionQuality%',
              onChanged: (val) {
                setState(() => _imageCompressionQuality = val.round());
              },
            ),
            trailing: Text(
              '$_imageCompressionQuality%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),

          const Divider(height: 32),

          // Security & App Lock
          const _SectionHeader(title: 'SECURITY & APP LOCK'),
          _buildSecuritySection(context),

          const Divider(height: 32),

          // About & Diagnostics
          const _SectionHeader(title: 'ABOUT ANUSCAN'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.architecture),
            title: Text('Architecture'),
            subtitle: Text(
              'Feature-First Clean Architecture • BLoC/Cubit • GetIt',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Local Storage Engine'),
            subtitle: Text('SQLite (sqflite) + Sandboxed Filesystem'),
          ),
        ],
      ),
    );
  }

  AppLockCubit? _getCubit(BuildContext context) {
    try {
      return context.read<AppLockCubit>();
    } catch (_) {
      if (sl.isRegistered<AppLockCubit>()) {
        return sl<AppLockCubit>();
      }
      return null;
    }
  }

  Widget _buildSecuritySection(BuildContext context) {
    final cubit = _getCubit(context);
    if (cubit == null) {
      return const Column(
        children: [
          SwitchListTile(
            secondary: Icon(Icons.lock_outline),
            title: Text('App Lock'),
            subtitle: Text('Require PIN to unlock AnuScan'),
            value: false,
            onChanged: null,
          ),
        ],
      );
    }

    return BlocBuilder<AppLockCubit, AppLockState>(
      bloc: cubit,
      builder: (context, lockState) {
        return Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text('App Lock'),
              subtitle: Text(
                lockState.isAppLockEnabled
                    ? 'Protected by PIN'
                    : 'Require PIN to unlock AnuScan',
              ),
              value: lockState.isAppLockEnabled,
              onChanged: (val) {
                if (val) {
                  _showSetPinDialog(context, cubit);
                } else {
                  _showDisablePinDialog(context, cubit);
                }
              },
            ),
            if (lockState.isAppLockEnabled) ...[
              if (lockState.canUseBiometrics)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric Unlock'),
                  subtitle: const Text(
                    'Unlock with Fingerprint or Face ID',
                  ),
                  value: lockState.isBiometricsEnabled,
                  onChanged: (val) {
                    cubit.setBiometricsEnabled(val);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: const Text('Change PIN'),
                subtitle: const Text('Update your 4-digit security PIN'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePinDialog(context, cubit),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Auto-Lock Timeout'),
                subtitle: Text(_formatTimeout(lockState.autoLockTimeout)),
                trailing: DropdownButton<int>(
                  value: lockState.autoLockTimeout,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Immediately'),
                    ),
                    DropdownMenuItem(value: 30, child: Text('After 30s')),
                    DropdownMenuItem(value: 60, child: Text('After 1m')),
                    DropdownMenuItem(value: 300, child: Text('After 5m')),
                    DropdownMenuItem(
                      value: 900,
                      child: Text('After 15m'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      cubit.setAutoLockTimeout(val);
                    }
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatTimeout(int seconds) {
    if (seconds == 0) return 'Immediately when backgrounded';
    if (seconds < 60) return 'After $seconds seconds';
    final mins = seconds ~/ 60;
    return 'After $mins minute${mins > 1 ? 's' : ''}';
  }

  void _showSetPinDialog(BuildContext context, AppLockCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        String? firstPin;
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AppLockScreen(
              isModal: true,
              title: firstPin == null ? 'Create 4-Digit PIN' : 'Confirm PIN',
              subtitle: firstPin == null
                  ? 'Enter a 4-digit PIN to secure AnuScan'
                  : 'Re-enter your PIN to confirm',
              onVerifyPin: (pin) async {
                if (firstPin == null) {
                  setLocalState(() {
                    firstPin = pin;
                  });
                  return true;
                } else {
                  if (pin == firstPin) {
                    final messenger = ScaffoldMessenger.of(context);
                    await cubit.enableLock(pin, enableBiometrics: true);
                    if (bottomSheetContext.mounted &&
                        Navigator.canPop(bottomSheetContext)) {
                      Navigator.pop(bottomSheetContext);
                    }
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('App Lock enabled successfully'),
                      ),
                    );
                    return true;
                  } else {
                    return false;
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  void _showDisablePinDialog(BuildContext context, AppLockCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return AppLockScreen(
          isModal: true,
          title: 'Disable App Lock',
          subtitle: 'Enter your current PIN to turn off App Lock',
          onVerifyPin: (pin) async {
            final messenger = ScaffoldMessenger.of(context);
            final success = await cubit.disableLock(pin);
            if (success) {
              if (bottomSheetContext.mounted &&
                  Navigator.canPop(bottomSheetContext)) {
                Navigator.pop(bottomSheetContext);
              }
              messenger.showSnackBar(
                const SnackBar(content: Text('App Lock disabled')),
              );
            }
            return success;
          },
        );
      },
    );
  }

  void _showChangePinDialog(BuildContext context, AppLockCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        String? oldPin;
        String? newPin;

        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            String title = 'Enter Current PIN';
            String subtitle = 'Verify your identity before changing PIN';
            if (oldPin != null && newPin == null) {
              title = 'Enter New PIN';
              subtitle = 'Choose a new 4-digit PIN';
            } else if (oldPin != null && newPin != null) {
              title = 'Confirm New PIN';
              subtitle = 'Re-enter your new PIN';
            }

            return AppLockScreen(
              isModal: true,
              title: title,
              subtitle: subtitle,
              onVerifyPin: (pin) async {
                if (oldPin == null) {
                  // Verify old PIN
                  final valid = await cubit.securityService.verifyPin(pin);
                  if (valid) {
                    setLocalState(() => oldPin = pin);
                    return true;
                  }
                  return false;
                } else if (newPin == null) {
                  setLocalState(() => newPin = pin);
                  return true;
                } else {
                  if (pin == newPin) {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await cubit.changePin(oldPin!, newPin!);
                    if (success) {
                      if (bottomSheetContext.mounted &&
                          Navigator.canPop(bottomSheetContext)) {
                        Navigator.pop(bottomSheetContext);
                      }
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('PIN changed successfully'),
                        ),
                      );
                      return true;
                    }
                    return false;
                  }
                  return false;
                }
              },
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
