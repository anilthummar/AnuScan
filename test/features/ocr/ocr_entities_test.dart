import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/features/ocr/domain/entities/ocr_entities.dart';

void main() {
  group('OcrTextBlockEntity Tests', () {
    test('instantiates with correct fields and calculates properties', () {
      const block = OcrTextBlockEntity(
        text: 'Invoice #12345',
        boundingBox: [10, 20, 110, 50],
        confidence: 0.95,
      );

      expect(block.text, 'Invoice #12345');
      expect(block.confidence, 0.95);
      expect(block.boundingBox, [10, 20, 110, 50]);
    });
  });

  group('OcrPageResult Tests', () {
    test('calculates wordCount, hasText correctly', () {
      final now = DateTime.now();
      final pageResult = OcrPageResult(
        id: 'ocr_p1',
        documentId: 'doc_1',
        pageId: 'p1',
        pageIndex: 0,
        imagePath: '/tmp/proc_0.jpg',
        extractedText: '  Hello world from AnuScan OCR engine!  ',
        status: OcrStatus.completed,
        processingDurationMs: 250,
        blocks: const [
          OcrTextBlockEntity(text: 'Hello world', confidence: 0.95),
          OcrTextBlockEntity(
            text: 'from AnuScan OCR engine!',
            confidence: 0.89,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(pageResult.pageIndex, 0);
      expect(pageResult.imagePath, '/tmp/proc_0.jpg');
      expect(pageResult.status, OcrStatus.completed);
      expect(pageResult.hasText, isTrue);
      expect(pageResult.wordCount, 6);
    });

    test('handles empty or whitespace text cleanly', () {
      final now = DateTime.now();
      final emptyResult = OcrPageResult(
        id: 'ocr_p2',
        documentId: 'doc_1',
        pageId: 'p2',
        pageIndex: 1,
        imagePath: '/tmp/proc_1.jpg',
        extractedText: '   ',
        status: OcrStatus.failed,
        createdAt: now,
        updatedAt: now,
      );

      expect(emptyResult.pageIndex, 1);
      expect(emptyResult.extractedText.trim(), isEmpty);
      expect(emptyResult.wordCount, 0);
      expect(emptyResult.hasText, isFalse);
      expect(emptyResult.blocks, isEmpty);
    });
  });

  group('DocumentOcrResult Tests', () {
    test(
      'aggregates page statistics and combines text with clean page headers',
      () {
        final now = DateTime.now();
        final page0 = OcrPageResult(
          id: 'ocr_p0',
          documentId: 'doc_456',
          pageId: 'p0',
          pageIndex: 0,
          imagePath: '/tmp/p0.jpg',
          extractedText: 'Invoice Details: Total \$150.00',
          status: OcrStatus.completed,
          createdAt: now,
          updatedAt: now,
        );
        final page1 = OcrPageResult(
          id: 'ocr_p1',
          documentId: 'doc_456',
          pageId: 'p1',
          pageIndex: 1,
          imagePath: '/tmp/p1.jpg',
          extractedText: 'Terms and conditions apply.',
          status: OcrStatus.completed,
          createdAt: now,
          updatedAt: now,
        );

        final docResult = DocumentOcrResult(
          documentId: 'doc_456',
          pageResults: [page0, page1],
          combinedText:
              'Invoice Details: Total \$150.00\n\nTerms and conditions apply.',
          status: OcrStatus.completed,
          lastProcessedAt: now,
        );

        expect(docResult.documentId, 'doc_456');
        expect(docResult.pageCount, 2);
        expect(docResult.hasText, isTrue);
        expect(docResult.totalWordCount, 8); // 4 + 4
        expect(
          docResult.combinedText,
          contains('Invoice Details: Total \$150.00'),
        );
        expect(docResult.combinedText, contains('Terms and conditions apply.'));
      },
    );

    test('detects empty document OCR', () {
      final now = DateTime.now();
      final emptyDoc = DocumentOcrResult(
        documentId: 'doc_empty',
        pageResults: const [],
        combinedText: '',
        status: OcrStatus.notProcessed,
        lastProcessedAt: now,
      );

      expect(emptyDoc.hasText, isFalse);
      expect(emptyDoc.totalWordCount, 0);
      expect(emptyDoc.combinedText, isEmpty);
    });
  });

  group('OcrSearchMatch Tests', () {
    test('instantiates with match count and snippet', () {
      const match = OcrSearchMatch(
        documentId: 'doc_1',
        documentTitle: 'Invoice Oct 2026',
        pageId: 'p1',
        pageIndex: 0,
        matchCount: 3,
        snippet: '... Total \$150.00 due on ...',
      );

      expect(match.documentId, 'doc_1');
      expect(match.documentTitle, 'Invoice Oct 2026');
      expect(match.pageIndex, 0);
      expect(match.matchCount, 3);
      expect(match.snippet, '... Total \$150.00 due on ...');
    });
  });
}
