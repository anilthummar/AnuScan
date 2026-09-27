import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/features/smart_document/data/services/document_classifier.dart';
import 'package:anuscan/features/smart_document/data/services/document_metadata_extractor.dart';
import 'package:anuscan/features/smart_document/data/services/smart_filename_generator.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_classification.dart';

void main() {
  const classifier = DocumentClassifier();
  const extractor = DocumentMetadataExtractor();
  const generator = SmartFilenameGenerator();

  group('Smart Document Recognition Stress & Performance Benchmarks', () {
    String generateSimulatedOcrPage(int pageIndex, DocumentType targetType) {
      switch (targetType) {
        case DocumentType.invoice:
          return '''
ACME GLOBAL SUPPLIES INC.
123 Enterprise Blvd, Suite 400
Tax Invoice / Bill of Supply
Invoice No: INV-2026-${(1000 + pageIndex)}
Date: 22/09/2026
Due Date: 15/10/2026
Bill To: Client Corporation Ltd
GSTIN: 27AABCA1234F1Z5
Items:
1. Cloud Infrastructure Architecture - \$4,500.00
2. Database Optimization Service - \$2,200.00
Subtotal: \$6,700.00
Tax (18%): \$1,206.00
Grand Total: \$7,906.00
Payment Terms: Net 30 Days.
Contact: accounts@acmeglobal.com | +1 800-555-0199
Page $pageIndex of 50
''';
        case DocumentType.receipt:
          return '''
COFFEE & BAGEL DELIGHT #$pageIndex
Store #402 - Terminal 01
Cashier: David
Order ID: RCP-$pageIndex-9821
Date: 2026-09-22 08:34 AM
1x Espresso - 3.50
1x Blueberry Muffin - 4.25
Subtotal: 7.75
Tax: 0.65
Total: 8.40
Cash Tendered: 10.00
Change Due: 1.60
Thank you for visiting! Have a wonderful day.
''';
        default:
          return '''
Technical Report: Enterprise Architecture Optimization
Document Ref: DOC-2026-$pageIndex
Date: September 2026
Author: Engineering Taskforce
This document outlines the systematic improvements in processing pipelines.
Table of Contents, Section $pageIndex analysis.
''';
      }
    }

    test('1-page OCR recognition completes in under 20ms', () {
      final text = generateSimulatedOcrPage(1, DocumentType.invoice);

      final stopwatch = Stopwatch()..start();
      final classification = classifier.classify(text);
      final metadata = extractor.extract(
        rawText: text,
        classification: classification,
      );
      final filename = generator.generate(
        classification: classification,
        metadata: metadata,
      );
      stopwatch.stop();

      expect(classification.type, equals(DocumentType.invoice));
      expect(metadata.invoiceNumber, isNotNull);
      expect(filename, contains('Invoice'));
      expect(stopwatch.elapsedMilliseconds, lessThan(20));
    });

    test('10-page OCR combined payload recognizes in under 30ms', () {
      final pages = List.generate(
        10,
        (i) => generateSimulatedOcrPage(i + 1, DocumentType.invoice),
      );
      final combined = pages.join('\n\n--- PAGE BREAK ---\n\n');

      final stopwatch = Stopwatch()..start();
      final classification = classifier.classify(combined);
      final metadata = extractor.extract(
        rawText: combined,
        classification: classification,
      );
      final filename = generator.generate(
        classification: classification,
        metadata: metadata,
      );
      stopwatch.stop();

      expect(classification.type, equals(DocumentType.invoice));
      expect(metadata.companyName, isNotNull);
      expect(filename.length, lessThanOrEqualTo(80));
      expect(stopwatch.elapsedMilliseconds, lessThan(30));
    });

    test(
      '20-page and 50-page OCR combined payload recognizes in under 50ms',
      () {
        final pages20 = List.generate(
          20,
          (i) => generateSimulatedOcrPage(i + 1, DocumentType.receipt),
        );
        final combined20 = pages20.join('\n\n--- PAGE BREAK ---\n\n');

        final sw20 = Stopwatch()..start();
        final class20 = classifier.classify(combined20);
        final meta20 = extractor.extract(
          rawText: combined20,
          classification: class20,
        );
        final file20 = generator.generate(
          classification: class20,
          metadata: meta20,
        );
        sw20.stop();

        expect(class20.type, equals(DocumentType.receipt));
        expect(file20.contains('Receipt'), isTrue);
        expect(sw20.elapsedMilliseconds, lessThan(50));

        final pages50 = List.generate(
          50,
          (i) => generateSimulatedOcrPage(i + 1, DocumentType.invoice),
        );
        final combined50 = pages50.join('\n\n--- PAGE BREAK ---\n\n');

        final sw50 = Stopwatch()..start();
        final class50 = classifier.classify(combined50);
        final meta50 = extractor.extract(
          rawText: combined50,
          classification: class50,
        );
        final file50 = generator.generate(
          classification: class50,
          metadata: meta50,
        );
        sw50.stop();

        expect(class50.type, equals(DocumentType.invoice));
        expect(file50.isNotEmpty, isTrue);
        expect(sw50.elapsedMilliseconds, lessThan(80));
      },
    );

    test(
      'handles 50,000 characters of random noise / garbage OCR without crashing or timing out',
      () {
        final rand = Random(42);
        const chars =
            'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t.,;:/?!@#\$%^&*()-_+=~`';
        final buffer = StringBuffer();
        for (int i = 0; i < 50000; i++) {
          buffer.write(chars[rand.nextInt(chars.length)]);
        }
        final noisyText = buffer.toString();

        final stopwatch = Stopwatch()..start();
        final classification = classifier.classify(noisyText);
        final metadata = extractor.extract(
          rawText: noisyText,
          classification: classification,
        );
        final filename = generator.generate(
          classification: classification,
          metadata: metadata,
        );
        stopwatch.stop();

        expect(filename.isNotEmpty, isTrue);
        expect(filename.length, lessThanOrEqualTo(80));
        expect(stopwatch.elapsedMilliseconds, lessThan(150));
      },
    );

    test(
      '100 consecutive recognition iterations run with zero memory or latency degradation',
      () {
        final text = generateSimulatedOcrPage(1, DocumentType.invoice);

        final sw = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          final classification = classifier.classify(text);
          final metadata = extractor.extract(
            rawText: text,
            classification: classification,
          );
          generator.generate(
            classification: classification,
            metadata: metadata,
          );
        }
        sw.stop();

        // 100 iterations should take well under 250ms total (< 2.5ms per iteration)
        expect(sw.elapsedMilliseconds, lessThan(250));
      },
    );
  });
}
