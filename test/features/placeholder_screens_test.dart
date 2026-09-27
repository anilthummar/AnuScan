import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/di/injection.dart';
import 'package:anuscan/core/services/document_scanner_service.dart';
import 'package:anuscan/core/services/gallery_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/presentation/screens/document_preview_screen.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/scanner/presentation/screens/gallery_screen.dart';
import 'package:anuscan/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:anuscan/features/settings/presentation/screens/settings_screen.dart';

class MockScannerService implements DocumentScannerService {
  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> initialize() async {}

  @override
  bool get isInitialized => true;

  @override
  Widget buildPreview() => const SizedBox(key: Key('mock_camera_preview'));

  @override
  Stream<DocumentCornerPoints?> get detectedCornersStream =>
      const Stream.empty();

  @override
  Stream<DocumentDetectionResult> get detectionStream => const Stream.empty();

  @override
  DocumentCornerPoints? get currentCorners => null;

  @override
  DetectionState get currentDetectionState => DetectionState.searching;

  @override
  Future<String?> captureDocument() async => '/tmp/captured.jpg';

  @override
  Future<bool> toggleFlash() async => false;

  @override
  bool get isFlashOn => false;

  @override
  Future<void> dispose() async {}

  @override
  Future<List<String>> scanDocuments({int maxPages = 100}) async => [
        '/tmp/page1.jpg',
      ];
}

class MockGalleryService implements GalleryService {
  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<String>> pickMultipleImages() async => ['/tmp/img1.jpg'];

  @override
  Future<String?> pickSingleImage() async => '/tmp/img1.jpg';

  @override
  Future<bool> isImageValid(String path) async => true;
}

void main() {
  setUp(() async {
    await sl.reset();
    await setupDependencyInjection(
      customScannerService: MockScannerService(),
      customGalleryService: MockGalleryService(),
    );
  });

  group('Placeholder Screens', () {
    testWidgets('ScannerScreen renders camera preview and scanner controls', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ScannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mock_camera_preview')), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Searching for document...'), findsOneWidget);
    });

    testWidgets('GalleryScreen renders prompt and pick button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: GalleryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Gallery Import'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);
      expect(find.text('Select Images'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
      'DocumentPreviewScreen renders empty state when no document passed',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: DocumentPreviewScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Document Preview'), findsOneWidget);
        expect(find.text('No Document Selected'), findsOneWidget);
        expect(find.text('Back to Home'), findsOneWidget);
      },
    );

    testWidgets(
      'DocumentPreviewScreen renders document details when document provided',
      (WidgetTester tester) async {
        final doc = DocumentEntity(
          id: 'doc-123',
          title: 'Tax Invoice 2026',
          createdAt: DateTime(2026, 3, 15),
          updatedAt: DateTime(2026, 3, 15),
          pageCount: 0,
          pages: const [],
          pdfPath: '/tmp/tax_invoice.pdf',
        );

        await tester.pumpWidget(
          MaterialApp(home: DocumentPreviewScreen(document: doc)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tax Invoice 2026'), findsWidgets);
        expect(find.textContaining('0 Pages'), findsOneWidget);
      },
    );

    testWidgets('SettingsScreen renders options and offline badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('100% Offline & Private'), findsOneWidget);
      expect(find.text('High Quality Capture'), findsOneWidget);
      expect(find.text('Default PDF Page Format'), findsOneWidget);
      expect(find.text('Image Compression Quality'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('ABOUT ANUSCAN'), 200);
      expect(find.text('ABOUT ANUSCAN'), findsOneWidget);
    });
  });
}
