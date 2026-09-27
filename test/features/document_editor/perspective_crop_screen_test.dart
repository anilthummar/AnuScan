import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/presentation/screens/perspective_crop_screen.dart';
import 'package:anuscan/features/document_editor/presentation/widgets/perspective_crop_widget.dart';

void main() {
  late Directory tempDir;
  late File testFile;
  late ScanPage testPage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crop_test_');
    testFile = File('${tempDir.path}/crop_test_image.jpg');
    final dummyImg = img.Image(width: 100, height: 100);
    testFile.writeAsBytesSync(img.encodeJpg(dummyImg));

    testPage = ScanPage(
      id: 'page_crop_1',
      documentId: 'doc_crop',
      pageIndex: 0,
      originalImagePath: testFile.path,
      processedImagePath: testFile.path,
      width: 100,
      height: 100,
      createdAt: DateTime(2026, 1, 1),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'PerspectiveCropScreen renders guide, widget, action buttons, and applies crop',
    (tester) async {
      CropCorners? appliedCorners;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                appliedCorners = await Navigator.push<CropCorners>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PerspectiveCropScreen(page: testPage),
                  ),
                );
              },
              child: const Text('Open Crop'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Crop'));
      await tester.pumpAndSettle();

      expect(find.text('Crop & Perspective'), findsOneWidget);
      expect(
        find.text('Drag corners to align with the document boundaries'),
        findsOneWidget,
      );
      expect(find.byType(PerspectiveCropWidget), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Apply Crop'), findsOneWidget);
      expect(find.byTooltip('Reset Crop'), findsOneWidget);

      // Tapping Reset Crop
      await tester.tap(find.byTooltip('Reset Crop'));
      await tester.pumpAndSettle();

      // Tapping Apply Crop
      await tester.tap(find.text('Apply Crop'));
      await tester.pumpAndSettle();

      expect(appliedCorners, isNotNull);
      expect(appliedCorners!.isFullBounds, isTrue);
    },
  );

  testWidgets('PerspectiveCropScreen tapping Cancel returns null', (
    tester,
  ) async {
    CropCorners? appliedCorners = const CropCorners(
      topLeftX: 0.2,
      topLeftY: 0.2,
      topRightX: 0.8,
      topRightY: 0.2,
      bottomLeftX: 0.2,
      bottomLeftY: 0.8,
      bottomRightX: 0.8,
      bottomRightY: 0.8,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              appliedCorners = await Navigator.push<CropCorners>(
                context,
                MaterialPageRoute(
                  builder: (_) => PerspectiveCropScreen(page: testPage),
                ),
              );
            },
            child: const Text('Open Crop'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Crop'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(appliedCorners, isNull);
  });
}
