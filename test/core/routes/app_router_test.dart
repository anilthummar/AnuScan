import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/di/injection.dart';
import 'package:anuscan/core/routes/app_router.dart';
import 'package:anuscan/core/routes/app_routes.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/presentation/screens/document_preview_screen.dart';
import 'package:anuscan/features/document_editor/presentation/screens/page_editor_screen.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_history/domain/repositories/document_repository.dart';
import 'package:anuscan/features/document_history/presentation/screens/home_screen.dart';
import 'package:anuscan/features/pdf_viewer/presentation/screens/pdf_preview_screen.dart';
import 'package:anuscan/features/scanner/presentation/screens/gallery_screen.dart';
import 'package:anuscan/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:anuscan/features/settings/presentation/screens/settings_screen.dart';

class MockDocumentRepository implements DocumentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  Future<List<DocumentEntity>> getAllDocuments() async => [];
  @override
  Future<DocumentEntity?> getDocumentById(String id) async => null;
  @override
  Future<void> saveDocument(DocumentEntity document) async {}
  @override
  Future<void> deleteDocument(String id) async {}
  @override
  Future<void> renameDocument(String id, String newTitle) async {}
  @override
  Future<List<DocumentEntity>> searchDocuments(String query) async => [];
}

void main() {
  setUp(() async {
    await sl.reset();
    await setupDependencyInjection(
      customDocumentRepository: MockDocumentRepository(),
    );
  });

  group('AppRouter', () {
    testWidgets('routes to HomeScreen for AppRoutes.home', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.home),
              );
              expect(route, isA<MaterialPageRoute>());
              final widget = (route as MaterialPageRoute).builder(context);
              expect(widget, isA<HomeScreen>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('routes to ScannerScreen for AppRoutes.scanner', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.scanner),
              );
              expect(route, isA<MaterialPageRoute>());
              final widget = (route as MaterialPageRoute).builder(context);
              expect(widget, isA<ScannerScreen>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('routes to GalleryScreen for AppRoutes.gallery', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.gallery),
              );
              expect(route, isA<MaterialPageRoute>());
              final widget = (route as MaterialPageRoute).builder(context);
              expect(widget, isA<GalleryScreen>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('routes to SettingsScreen for AppRoutes.settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.settings),
              );
              expect(route, isA<MaterialPageRoute>());
              final widget = (route as MaterialPageRoute).builder(context);
              expect(widget, isA<SettingsScreen>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets(
      'routes to DocumentPreviewScreen for AppRoutes.documentPreview',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final route = AppRouter.onGenerateRoute(
                  const RouteSettings(name: AppRoutes.documentPreview),
                );
                expect(route, isA<MaterialPageRoute>());
                final widget = (route as MaterialPageRoute).builder(context);
                expect(widget, isA<DocumentPreviewScreen>());
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'routes to PageEditorScreen when ScannedPage argument is provided',
      (tester) async {
        final samplePage = ScannedPage(
          id: 'p1',
          documentId: 'd1',
          pageIndex: 0,
          originalImagePath: '/tmp/orig.jpg',
          processedImagePath: '/tmp/proc.jpg',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final route = AppRouter.onGenerateRoute(
                  RouteSettings(
                    name: AppRoutes.pageEditor,
                    arguments: samplePage,
                  ),
                );
                expect(route, isA<MaterialPageRoute>());
                final widget = (route as MaterialPageRoute).builder(context);
                expect(widget, isA<PageEditorScreen>());
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );

    testWidgets('routes to error route when PageEditor lacks arguments', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.pageEditor),
              );
              expect(route, isA<MaterialPageRoute>());
              final widget = (route as MaterialPageRoute).builder(context);
              expect(widget, isA<Scaffold>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('routes to PdfPreviewScreen with PdfPreviewArgs', (
      tester,
    ) async {
      final args = PdfPreviewArgs(
        documentId: 'd1',
        title: 'Sample Doc',
        pages: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = AppRouter.onGenerateRoute(
                RouteSettings(name: AppRoutes.pdfPreview, arguments: args),
              );
              expect(route, isA<MaterialPageRoute>());
              final widget = (route as MaterialPageRoute).builder(context);
              expect(widget, isA<PdfPreviewScreen>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('routes to error route for unknown route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = AppRouter.onGenerateRoute(
                const RouteSettings(name: '/invalid-unknown-route'),
              );
              expect(route, isA<MaterialPageRoute>());
              final widget = (route as MaterialPageRoute).builder(context);
              expect(widget, isA<Scaffold>());
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
