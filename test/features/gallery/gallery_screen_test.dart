import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/di/injection.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:anuscan/features/gallery/presentation/screens/gallery_screen.dart';

class TestGalleryRepository implements GalleryRepository {
  Result<bool> permissionResult = const Result.success(true);
  Result<List<String>> pickResult = const Result.success(['/path/image1.jpg']);
  bool simulateSlowProcessing = false;

  @override
  Future<Result<bool>> checkPermission() async => permissionResult;

  @override
  Future<Result<bool>> requestPermission() async => permissionResult;

  @override
  Future<Result<List<String>>> pickImages() async => pickResult;

  @override
  Future<Result<String?>> pickSingleImage() async =>
      const Result.success('/path/single.jpg');

  @override
  Future<Result<List<ScannedPage>>> processImportedImages({
    required List<String> rawPaths,
    required String documentId,
    int startIndex = 0,
    void Function(int current, int total)? onProgress,
  }) async {
    onProgress?.call(1, 2);
    if (simulateSlowProcessing) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return Result.success([
      ScannedPage(
        id: 'p1',
        documentId: documentId,
        pageIndex: 0,
        originalImagePath: '/orig_1.jpg',
        processedImagePath: '/proc_1.jpg',
        filterType: DocumentFilterType.original,
        createdAt: DateTime.now(),
      ),
    ]);
  }
}

void main() {
  late TestGalleryRepository testRepo;

  setUp(() async {
    await sl.reset();
    testRepo = TestGalleryRepository();
    await setupDependencyInjection(customGalleryRepository: testRepo);
  });

  group('GalleryScreen Widget Tests', () {
    testWidgets('renders initial UI elements properly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: GalleryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Gallery Import'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);
      expect(find.text('Select Images'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(
        find.text('Original resolution & quality preserved'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Select Images triggers picker and completes import', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: GalleryScreen(documentId: 'doc-test')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select Images'));
      await tester.pump();

      // Completes flow
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('renders permission denied UI when permission is refused', (
      WidgetTester tester,
    ) async {
      testRepo.permissionResult = const Result<bool>.failure(
        PermissionFailure('Access denied'),
      );

      await tester.pumpWidget(
        const MaterialApp(home: GalleryScreen(documentId: 'doc-test')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select Images'));
      await tester.pumpAndSettle();

      expect(find.text('Photo Library Access Required'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('tapping Cancel returns to previous screen', (
      WidgetTester tester,
    ) async {
      var popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryScreen()),
                );
                popped = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Gallery Import'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });
  });
}
