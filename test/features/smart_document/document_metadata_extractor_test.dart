import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/features/smart_document/data/services/document_metadata_extractor.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_classification.dart';

void main() {
  const extractor = DocumentMetadataExtractor();

  group('DocumentMetadataExtractor Tests', () {
    test(
      'extracts invoice metadata with numbers, dates, amounts, and company',
      () {
        const text = '''
ACME CORPORATION
Tax Invoice
Invoice No: INV-2026-9941
Date: 21/09/2026
Due Date: 05/10/2026
Bill To: John Smith
Subtotal: \$10,000.00
Tax: \$1,800.00
Total Amount: \$11,800.00
Email: billing@acmecorp.com
Phone: +1 800-555-0199
Website: https://acmecorp.com
''';

        const classification = DocumentClassification(
          type: DocumentType.invoice,
          confidence: 0.95,
          matchedSignals: ['tax invoice'],
        );

        final metadata = extractor.extract(
          rawText: text,
          classification: classification,
        );

        expect(metadata.invoiceNumber, equals('INV-2026-9941'));
        expect(metadata.date, equals('21/09/2026'));
        expect(metadata.dueDate, equals('05/10/2026'));
        expect(metadata.amount, equals(11800.0));
        expect(metadata.currency, equals('\$'));
        expect(metadata.companyName, equals('ACME CORPORATION'));
        expect(metadata.personName, equals('John Smith'));
        expect(metadata.email, equals('billing@acmecorp.com'));
        expect(metadata.phone, equals('+1 800-555-0199'));
        expect(metadata.website, equals('https://acmecorp.com'));
      },
    );

    test(
      'extracts receipt metadata with store, order id, date, and total with rupee currency',
      () {
        const text = '''
RELIANCE RETAIL LTD
Store #104 - Cashier: Priya
Receipt No: RCP-88321
Date: 2026-08-15
Items: 4
Subtotal: ₹1,200.00
GST: ₹216.00
Grand Total: ₹1,416.00
Paid Cash: ₹1,500.00
Change Due: ₹84.00
Thank you for shopping!
''';

        const classification = DocumentClassification(
          type: DocumentType.receipt,
          confidence: 0.9,
          matchedSignals: ['receipt'],
        );

        final metadata = extractor.extract(
          rawText: text,
          classification: classification,
        );

        expect(metadata.receiptNumber, equals('RCP-88321'));
        expect(metadata.date, equals('2026-08-15'));
        expect(metadata.amount, equals(1416.0));
        expect(metadata.currency, equals('₹'));
        expect(metadata.companyName, equals('RELIANCE RETAIL LTD'));
      },
    );

    test('extracts business card contacts, names, and web addresses', () {
      const text = '''
Dr. Angela Martin
Chief Medical Officer
Healthcare Solutions Inc.
angela.martin@healthcaresolutions.org
+1 (555) 432-8765
www.healthcaresolutions.org
''';

      const classification = DocumentClassification(
        type: DocumentType.businessCard,
        confidence: 0.85,
        matchedSignals: ['email', 'phone', 'website'],
      );

      final metadata = extractor.extract(
        rawText: text,
        classification: classification,
      );

      expect(metadata.personName, equals('Dr. Angela Martin'));
      expect(metadata.companyName, equals('Healthcare Solutions Inc.'));
      expect(metadata.email, equals('angela.martin@healthcaresolutions.org'));
      expect(metadata.phone, contains('432-8765'));
      expect(metadata.website, equals('www.healthcaresolutions.org'));
    });

    test(
      'extracts certificate recipient name following certify that pattern',
      () {
        const text = '''
Certificate of Excellence
This is to certify that
Marcus Aurelius
has successfully completed the training.
Date: 12 October 2026
Certificate No: CERT-9021
''';

        const classification = DocumentClassification(
          type: DocumentType.certificate,
          confidence: 0.9,
          matchedSignals: ['certificate'],
        );

        final metadata = extractor.extract(
          rawText: text,
          classification: classification,
        );

        expect(metadata.personName, equals('Marcus Aurelius'));
        expect(metadata.documentNumber, equals('CERT-9021'));
        expect(metadata.date, equals('12 October 2026'));
      },
    );

    test(
      'handles empty or blank text without throwing and returns empty metadata',
      () {
        const classification = DocumentClassification(
          type: DocumentType.other,
          confidence: 0.0,
        );

        final metadata = extractor.extract(
          rawText: '   \n  \t ',
          classification: classification,
        );

        expect(metadata.isEmpty, isTrue);
        expect(metadata.personName, isNull);
        expect(metadata.amount, isNull);
        expect(metadata.date, isNull);
        expect(metadata.primaryIdentifier, isNull);
      },
    );

    test(
      'extracts alphanumeric document reference and European euro currency amounts',
      () {
        const text = '''
BERLIN LOGISTICS GMBH
Document Ref: DOC/EU/2026/089
Date: 01.07.2026
Attn: Hans Gruber
Total Due: €2.450,00
''';

        const classification = DocumentClassification(
          type: DocumentType.report,
          confidence: 0.7,
        );

        final metadata = extractor.extract(
          rawText: text,
          classification: classification,
        );

        expect(metadata.documentNumber, equals('DOC/EU/2026/089'));
        expect(metadata.currency, equals('€'));
        expect(metadata.personName, equals('Hans Gruber'));
      },
    );
  });
}
