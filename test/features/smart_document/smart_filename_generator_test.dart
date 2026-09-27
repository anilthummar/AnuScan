import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/features/smart_document/data/services/smart_filename_generator.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_classification.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_metadata.dart';

void main() {
  const generator = SmartFilenameGenerator();

  group('SmartFilenameGenerator Tests', () {
    test('generates standard invoice filename: Company - Type - Number', () {
      const classification = DocumentClassification(
        type: DocumentType.invoice,
        confidence: 0.95,
      );
      const metadata = DocumentMetadata(
        companyName: 'ACME Corporation',
        invoiceNumber: 'INV-2026-1042',
        date: '2026-09-22',
      );

      final name = generator.generate(
        classification: classification,
        metadata: metadata,
      );

      expect(name, equals('ACME Corporation - Invoice - INV-2026-1042'));
    });

    test('generates receipt filename with store name and date', () {
      const classification = DocumentClassification(
        type: DocumentType.receipt,
        confidence: 0.9,
      );
      const metadata = DocumentMetadata(
        companyName: 'Starbucks Coffee',
        date: '22/09/2026',
      );

      final name = generator.generate(
        classification: classification,
        metadata: metadata,
      );

      expect(name, equals('Starbucks Coffee - Receipt - 22-09-2026'));
    });

    test('generates certificate filename: Certificate - Recipient', () {
      const classification = DocumentClassification(
        type: DocumentType.certificate,
        confidence: 0.95,
      );
      const metadata = DocumentMetadata(personName: 'Jane Doe');

      final name = generator.generate(
        classification: classification,
        metadata: metadata,
      );

      expect(name, equals('Certificate - Jane Doe'));
    });

    test('generates business card filename: Person - Company', () {
      const classification = DocumentClassification(
        type: DocumentType.businessCard,
        confidence: 0.9,
      );
      const metadata = DocumentMetadata(
        personName: 'Alex Rivera',
        companyName: 'Apex Solutions',
      );

      final name = generator.generate(
        classification: classification,
        metadata: metadata,
      );

      expect(name, equals('Alex Rivera - Apex Solutions'));
    });

    test(
      'sanitizes illegal filesystem characters (slashes, colons, stars, quotes, pipes)',
      () {
        const classification = DocumentClassification(
          type: DocumentType.invoice,
          confidence: 0.8,
        );
        const metadata = DocumentMetadata(
          companyName: 'ACME/Corp: Global | Division',
          invoiceNumber: 'INV*2026?#1',
        );

        final name = generator.generate(
          classification: classification,
          metadata: metadata,
        );

        expect(name.contains('/'), isFalse);
        expect(name.contains(':'), isFalse);
        expect(name.contains('*'), isFalse);
        expect(name.contains('?'), isFalse);
        expect(name.contains('|'), isFalse);
        expect(name.contains('<'), isFalse);
        expect(name.contains('>'), isFalse);
      },
    );

    test(
      'strictly enforces maximum 80 character limit and removes trailing delimiters',
      () {
        const classification = DocumentClassification(
          type: DocumentType.report,
          confidence: 0.7,
        );
        const metadata = DocumentMetadata(
          companyName:
              'Super International Conglomerate With An Extremely Long Corporate Entity Name Incorporated Limited',
          documentNumber:
              'VERY-LONG-REFERENCE-DOCUMENT-NUMBER-EXTENDED-SERIES-2026-SPECIAL-EDITION',
        );

        final name = generator.generate(
          classification: classification,
          metadata: metadata,
        );

        expect(
          name.length,
          lessThanOrEqualTo(SmartFilenameGenerator.maxFilenameLength),
        );
        expect(name.endsWith('-'), isFalse);
        expect(name.endsWith('_'), isFalse);
        expect(name.endsWith(' '), isFalse);
      },
    );

    test('uses fallback name or date when metadata is empty', () {
      const classification = DocumentClassification(
        type: DocumentType.other,
        confidence: 0.0,
      );
      const metadata = DocumentMetadata();

      final nameWithFallback = generator.generate(
        classification: classification,
        metadata: metadata,
        fallbackName: 'Scan_2026-09-22',
      );
      expect(nameWithFallback, equals('Scan_2026-09-22'));

      final nameWithoutFallback = generator.generate(
        classification: classification,
        metadata: metadata,
      );
      expect(nameWithoutFallback, startsWith('Document - '));
    });
  });
}
