import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/document_history/domain/usecases/document_usecases.dart';
import 'features/document_history/presentation/cubit/document_history_cubit.dart';
import 'features/document_history/presentation/screens/home_screen.dart';

/// Main application widget with global providers, themes, and home route.
class AnuScanApp extends StatelessWidget {
  const AnuScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DocumentHistoryCubit>(
          create: (context) => DocumentHistoryCubit(
            getDocumentsUseCase: sl<GetDocumentsUseCase>(),
            deleteDocumentUseCase: sl<DeleteDocumentUseCase>(),
            renameDocumentUseCase: sl<RenameDocumentUseCase>(),
            searchDocumentsUseCase: sl<SearchDocumentsUseCase>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'AnuScan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
