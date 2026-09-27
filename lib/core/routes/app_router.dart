import 'package:flutter/material.dart';
import '../../features/document_editor/domain/entities/scanned_page.dart';
import '../../features/document_editor/presentation/screens/document_editor_screen.dart';
import '../../features/document_editor/presentation/screens/document_preview_screen.dart';
import '../../features/document_editor/presentation/screens/page_editor_screen.dart';
import '../../features/document_history/domain/entities/document_entity.dart';
import '../../features/document_history/presentation/screens/home_screen.dart';
import '../../features/pdf_viewer/presentation/screens/pdf_preview_screen.dart';
import '../../features/scanner/presentation/screens/gallery_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/ocr/presentation/screens/ocr_viewer_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/document_history/presentation/screens/folders_screen.dart';
import '../../features/document_history/presentation/screens/trash_screen.dart';
import '../../features/document_history/presentation/screens/document_details_screen.dart';
import 'app_routes.dart';

/// Arguments for navigating to [PdfPreviewScreen].
class PdfPreviewArgs {
  const PdfPreviewArgs({
    required this.documentId,
    required this.title,
    required this.pages,
    this.existingPdfPath,
  });

  final String documentId;
  final String title;
  final List<ScannedPage> pages;
  final String? existingPdfPath;
}

/// Arguments for navigating to [OcrViewerScreen].
class OcrViewerArgs {
  const OcrViewerArgs({
    required this.documentId,
    required this.title,
    required this.pages,
  });

  final String documentId;
  final String title;
  final List<ScannedPage> pages;
}

/// Central application route generator.
class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );

      case AppRoutes.scanner:
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => const ScannerScreen(),
        );

      case AppRoutes.gallery:
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => const GalleryScreen(),
        );

      case AppRoutes.pageEditor:
        final page = settings.arguments as ScannedPage?;
        if (page != null) {
          return MaterialPageRoute<ScannedPage?>(
            settings: settings,
            builder: (_) => PageEditorScreen(page: page),
          );
        }
        return _errorRoute(
          settings,
          'PageEditor requires a ScannedPage argument.',
        );

      case AppRoutes.documentEditor:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => DocumentEditorScreen(
            documentId:
                args?['documentId'] as String? ??
                'doc_${DateTime.now().millisecondsSinceEpoch}',
            initialTitle: args?['title'] as String? ?? 'New Document',
            initialImagePaths:
                (args?['imagePaths'] as List?)?.cast<String>() ?? const [],
          ),
        );

      case AppRoutes.documentPreview:
        final doc = settings.arguments as DocumentEntity?;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => DocumentPreviewScreen(document: doc),
        );

      case AppRoutes.pdfPreview:
        final args = settings.arguments;
        if (args is PdfPreviewArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PdfPreviewScreen(
              documentId: args.documentId,
              title: args.title,
              pages: args.pages,
              existingPdfPath: args.existingPdfPath,
            ),
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PdfPreviewScreen(
              documentId: args['documentId'] as String? ?? 'preview_id',
              title: args['title'] as String? ?? 'Document Preview',
              pages: (args['pages'] as List?)?.cast<ScannedPage>() ?? const [],
              existingPdfPath: args['existingPdfPath'] as String?,
            ),
          );
        }
        return _errorRoute(
          settings,
          'PdfPreview requires PdfPreviewArgs or arguments map.',
        );

      case AppRoutes.ocrViewer:
        final args = settings.arguments;
        if (args is OcrViewerArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OcrViewerScreen(
              documentId: args.documentId,
              title: args.title,
              pages: args.pages,
            ),
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OcrViewerScreen(
              documentId: args['documentId'] as String? ?? '',
              title: args['title'] as String? ?? 'Extracted Text',
              pages: (args['pages'] as List?)?.cast<ScannedPage>() ?? const [],
            ),
          );
        }
        return _errorRoute(
          settings,
          'OcrViewer requires OcrViewerArgs or arguments map.',
        );

      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );

      case AppRoutes.folders:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const FoldersScreen(),
        );

      case AppRoutes.trash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const TrashScreen(),
        );

      case AppRoutes.documentDetails:
        final docId = settings.arguments is String
            ? settings.arguments as String
            : settings.arguments is DocumentEntity
            ? (settings.arguments as DocumentEntity).id
            : settings.arguments is Map<String, dynamic>
            ? (settings.arguments as Map<String, dynamic>)['documentId']
                      as String? ??
                  ''
            : '';
        if (docId.isNotEmpty) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => DocumentDetailsScreen(documentId: docId),
          );
        }
        return _errorRoute(
          settings,
          'DocumentDetails requires a documentId argument.',
        );

      default:
        return _errorRoute(
          settings,
          'Route "${settings.name}" does not exist.',
        );
    }
  }

  static Route<dynamic> _errorRoute(RouteSettings settings, String message) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Navigation Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
