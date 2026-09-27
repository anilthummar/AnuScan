import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/document_session.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';

void main() {
  final now = DateTime(2026, 3, 22, 10, 30);

  group('DocumentSessionPage', () {
    test('instantiates with required and default properties', () {
      final page = DocumentSessionPage(
        id: 'p1',
        imagePath: '/path/p1.jpg',
        order: 0,
        createdAt: now,
      );

      expect(page.id, equals('p1'));
      expect(page.imagePath, equals('/path/p1.jpg'));
      expect(page.order, equals(0));
      expect(page.rotation, equals(0));
      expect(page.filter, equals(ScanFilter.original));
      expect(page.width, equals(0));
      expect(page.height, equals(0));
      expect(page.originalImagePath, isNull);
      expect(page.corners, isNull);
      expect(page.createdAt, equals(now));
    });

    test('copyWith updates properties correctly', () {
      final page = DocumentSessionPage(
        id: 'p1',
        imagePath: '/path/p1.jpg',
        order: 0,
        createdAt: now,
      );

      final updated = page.copyWith(
        order: 1,
        rotation: 90,
        filter: ScanFilter.grayscale,
        width: 1000,
        height: 1500,
      );

      expect(updated.id, equals('p1'));
      expect(updated.order, equals(1));
      expect(updated.rotation, equals(90));
      expect(updated.filter, equals(ScanFilter.grayscale));
      expect(updated.width, equals(1000));
      expect(updated.height, equals(1500));
    });

    test('fromScanPage and toScanPage convert correctly', () {
      final scanPage = ScanPage(
        id: 'p1',
        documentId: 'doc_1',
        pageIndex: 2,
        originalImagePath: '/path/orig_p1.jpg',
        processedImagePath: '/path/proc_p1.jpg',
        filterType: ScanFilter.blackAndWhite,
        rotationDegrees: 180,
        width: 1200,
        height: 1600,
        createdAt: now,
      );

      final sessionPage = DocumentSessionPage.fromScanPage(scanPage);

      expect(sessionPage.id, equals('p1'));
      expect(sessionPage.order, equals(2));
      expect(sessionPage.imagePath, equals('/path/proc_p1.jpg'));
      expect(sessionPage.originalImagePath, equals('/path/orig_p1.jpg'));
      expect(sessionPage.filter, equals(ScanFilter.blackAndWhite));
      expect(sessionPage.rotation, equals(180));
      expect(sessionPage.width, equals(1200));
      expect(sessionPage.height, equals(1600));

      final convertedBack = sessionPage.toScanPage(documentId: 'doc_1');
      expect(convertedBack.id, equals(scanPage.id));
      expect(convertedBack.documentId, equals('doc_1'));
      expect(convertedBack.pageIndex, equals(scanPage.pageIndex));
      expect(
        convertedBack.originalImagePath,
        equals(scanPage.originalImagePath),
      );
      expect(
        convertedBack.processedImagePath,
        equals(scanPage.processedImagePath),
      );
      expect(convertedBack.filterType, equals(scanPage.filterType));
      expect(convertedBack.rotationDegrees, equals(scanPage.rotationDegrees));
    });

    test('supports value equality', () {
      final page1 = DocumentSessionPage(
        id: 'p1',
        imagePath: '/path/p1.jpg',
        order: 0,
        createdAt: now,
      );
      final page2 = DocumentSessionPage(
        id: 'p1',
        imagePath: '/path/p1.jpg',
        order: 0,
        createdAt: now,
      );

      expect(page1, equals(page2));
    });
  });

  group('DocumentSession', () {
    test('instantiates with correct attributes and getters', () {
      final session = DocumentSession(
        id: 's1',
        name: 'My Scan',
        createdAt: now,
        updatedAt: now,
        pages: [
          DocumentSessionPage(
            id: 'p1',
            imagePath: '/p1.jpg',
            order: 0,
            createdAt: now,
          ),
          DocumentSessionPage(
            id: 'p2',
            imagePath: '/p2.jpg',
            order: 1,
            createdAt: now,
          ),
        ],
      );

      expect(session.id, equals('s1'));
      expect(session.name, equals('My Scan'));
      expect(session.pageCount, equals(2));
      expect(session.isEmpty, isFalse);
      expect(session.isNotEmpty, isTrue);
    });

    test('fromScanPages and toScanPages convert correctly', () {
      final scanPages = [
        ScanPage(
          id: 'p1',
          documentId: 's1',
          pageIndex: 0,
          originalImagePath: '/orig1.jpg',
          processedImagePath: '/proc1.jpg',
          createdAt: now,
        ),
      ];

      final session = DocumentSession.fromScanPages(
        id: 's1',
        name: 'Imported',
        createdAt: now,
        updatedAt: now,
        scanPages: scanPages,
      );

      expect(session.pageCount, equals(1));
      expect(session.pages.first.id, equals('p1'));

      final convertedBack = session.toScanPages();
      expect(convertedBack.length, equals(1));
      expect(convertedBack.first.id, equals('p1'));
      expect(convertedBack.first.documentId, equals('s1'));
    });

    test('copyWith updates session metadata and pages', () {
      final session = DocumentSession(
        id: 's1',
        name: 'Original Name',
        createdAt: now,
        updatedAt: now,
      );

      final updatedTime = now.add(const Duration(minutes: 5));
      final updated = session.copyWith(
        name: 'New Name',
        updatedAt: updatedTime,
      );

      expect(updated.name, equals('New Name'));
      expect(updated.updatedAt, equals(updatedTime));
      expect(updated.id, equals('s1'));
    });
  });
}
