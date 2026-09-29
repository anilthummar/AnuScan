import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/document_history/presentation/cubit/document_history_cubit.dart';
import 'features/security/presentation/cubit/app_lock_cubit.dart';
import 'features/security/presentation/widgets/app_lock_wrapper.dart';
import 'features/subscription/presentation/cubit/subscription_cubit.dart';

/// Main application widget with global providers, themes, and centralized routing.
class AnuScanApp extends StatelessWidget {
  const AnuScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DocumentHistoryCubit>(
          create: (context) => sl<DocumentHistoryCubit>(),
        ),
        BlocProvider<AppLockCubit>(
          create: (context) => sl<AppLockCubit>(),
        ),
        BlocProvider<SubscriptionCubit>(
          create: (context) =>
              sl<SubscriptionCubit>()..loadSubscription(),
        ),
      ],
      child: MaterialApp(
        title: 'AnuScan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRouter.onGenerateRoute,
        builder: (context, child) => AppLockWrapper(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
