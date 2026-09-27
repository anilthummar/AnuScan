import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/app_lock_cubit.dart';
import '../cubit/app_lock_state.dart';
import '../screens/app_lock_screen.dart';

/// Wraps the entire application to enforce auto-locking and render [AppLockScreen] when locked.
class AppLockWrapper extends StatefulWidget {
  const AppLockWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppLockCubit>().initialize();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    final cubit = context.read<AppLockCubit>();
    if (state == AppLifecycleState.paused) {
      cubit.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      cubit.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppLockCubit, AppLockState>(
      builder: (context, state) {
        return Stack(
          children: [
            widget.child,
            if (state.isLocked) const Positioned.fill(child: AppLockScreen()),
          ],
        );
      },
    );
  }
}
