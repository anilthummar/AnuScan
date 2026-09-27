import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/features/smart_document/data/services/document_classifier.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_classification.dart';

void main() {
  const classifier = DocumentClassifier();

  group('DocumentClassifier Tests', () {
    test(
      'classifies invoice accurately from invoice keywords and structure',
      () {
        const ocr = '''
        ACME CORPORATION
        Tax Invoice
        Invoice No: INV-2026-1042
        Date: 21/09/2026
        Bill To: John Doe
        Subtotal: \$10,000.00
        Tax: \$2,500.00
        Amount Due: \$12,500.00
      ''';

        final result = classifier.classify(ocr);
        expect(result.type, DocumentType.invoice);
        expect(result.confidence, greaterThanOrEqualTo(0.5));
        expect(result.matchedSignals, contains('tax invoice'));
        expect(result.matchedSignals, contains('invoice number'));
        expect(result.matchedSignals, contains('amount due'));
      },
    );

    test(
      'classifies retail receipt with cashier, change, and tender details',
      () {
        const ocr = '''
        STARBUCKS COFFEE #1240
        Store #4021 - Register 2
        Cashier: Sarah
        Order # 412
        1x Latte - 4.50
        1x Croissant - 3.75
        Subtotal: 8.25
        Tax: 0.75
        Total: 9.00
        Cash Tender: 10.00
        Change Due: 1.00
        Thank you for shopping! Visit again.
      ''';

        final result = classifier.classify(ocr);
        expect(result.type, DocumentType.receipt);
        expect(result.confidence, greaterThanOrEqualTo(0.5));
        expect(result.matchedSignals, contains('tender details'));
        expect(result.matchedSignals, contains('cashier/register'));
        expect(result.matchedSignals, contains('change due'));
      },
    );

    test(
      'classifies business card from title, email, phone, and compact layout',
      () {
        const ocr = '''
        Alex Rivera
        Chief Technology Officer
        Apex Solutions Inc.
        alex@apexsolutions.com
        +1 555-234-5678
        www.apexsolutions.com
      ''';

        final result = classifier.classify(ocr);
        expect(result.type, DocumentType.businessCard);
        expect(result.confidence, greaterThanOrEqualTo(0.5));
        expect(result.matchedSignals, contains('email'));
        expect(result.matchedSignals, contains('phone'));
        expect(result.matchedSignals, contains('job title'));
        expect(result.matchedSignals, contains('website'));
      },
    );

    test('classifies certificate from completion and award terminology', () {
      const ocr = '''
        Certificate of Achievement
        This is to certify that
        Jane Doe
        is awarded toJane Doe in recognition of successful
        completion of Advanced Cloud Architect Course.
      ''';

      final result = classifier.classify(ocr);
      expect(result.type, DocumentType.certificate);
      expect(result.confidence, greaterThanOrEqualTo(0.5));
      expect(result.matchedSignals, contains('certificate'));
      expect(result.matchedSignals, contains('certifies that'));
    });

    test('classifies formal letter from salutation, closing, and subject', () {
      const ocr = '''
        Apex Corp
        Date: September 21, 2026
        
        Dear Mr. Smith,
        
        Subject: Offer of Employment
        
        We are pleased to offer you the position of Senior Architect.
        
        Sincerely,
        Human Resources Department
      ''';

      final result = classifier.classify(ocr);
      expect(result.type, DocumentType.letter);
      expect(result.confidence, greaterThanOrEqualTo(0.5));
      expect(result.matchedSignals, contains('salutation'));
      expect(result.matchedSignals, contains('closing signoff'));
    });

    test('classifies legal contract from agreement and formal clauses', () {
      const ocr = '''
        NON-DISCLOSURE AGREEMENT
        This Agreement is entered into by and between
        Party A and Party B.
        Terms and Conditions:
        In witness whereof, the parties hereto have executed this Agreement.
        Governing law shall be the laws of the State of California.
      ''';

      final result = classifier.classify(ocr);
      expect(result.type, DocumentType.contract);
      expect(result.confidence, greaterThanOrEqualTo(0.5));
      expect(result.matchedSignals, contains('agreement/contract'));
      expect(result.matchedSignals, contains('parties clause'));
    });

    test('classifies bank statement from balances and transactions', () {
      const ocr = '''
        NATIONAL BANK
        ACCOUNT STATEMENT
        Account Number: 9876543210
        Statement Period: 01/09/2026 to 20/09/2026
        Opening Balance: \$4,200.50
        Deposits: \$1,500.00
        Withdrawals: \$800.00
        Closing Balance: \$4,900.50
      ''';

      final result = classifier.classify(ocr);
      expect(result.type, DocumentType.bankStatement);
      expect(result.confidence, greaterThanOrEqualTo(0.5));
      expect(result.matchedSignals, contains('account statement'));
      expect(result.matchedSignals, contains('balance summary'));
    });

    test('classifies tax document from return and authority signals', () {
      const ocr = '''
        INTERNAL REVENUE SERVICE
        U.S. Individual Income Tax Return
        Form 1040
        Taxable Income: \$85,000
        Total Tax Payable: \$12,000
      ''';

      final result = classifier.classify(ocr);
      expect(result.type, DocumentType.taxDocument);
      expect(result.confidence, greaterThanOrEqualTo(0.5));
      expect(result.matchedSignals, contains('tax form code'));
      expect(result.matchedSignals, contains('tax authority'));
    });

    test('classifies medical document from patient and clinical terms', () {
      const ocr = '''
        CITY HEALTH HOSPITAL & CLINIC
        Patient Name: Michael Brown
        Physician: Dr. Robert Vance, M.D.
        Diagnosis: Acute Bronchitis
        Prescription Rx: Amoxicillin 500mg
        Dosage: 1 tablet 3 times daily
      ''';

      final result = classifier.classify(ocr);
      expect(result.type, DocumentType.medicalDocument);
      expect(result.confidence, greaterThanOrEqualTo(0.5));
      expect(result.matchedSignals, contains('patient'));
      expect(result.matchedSignals, contains('diagnosis'));
      expect(result.matchedSignals, contains('prescription'));
    });

    test(
      'classifies identity document from passport or driver license terms',
      () {
        const ocr = '''
        PASSPORT
        Republic of Utopia
        Date of Birth: 15/04/1990
        Nationality: Utopian
        Sex: M
        Place of Issue: Capital City
      ''';

        final result = classifier.classify(ocr);
        expect(result.type, DocumentType.identityDocument);
        expect(result.confidence, greaterThanOrEqualTo(0.5));
        expect(result.matchedSignals, contains('passport'));
        expect(result.matchedSignals, contains('date of birth'));
      },
    );

    test(
      'handles empty or short random OCR by returning other with 0 confidence',
      () {
        final emptyResult = classifier.classify('');
        expect(emptyResult.type, DocumentType.other);
        expect(emptyResult.confidence, 0.0);

        final randomResult = classifier.classify(
          'the quick brown fox jumps over the lazy dog',
        );
        expect(randomResult.type, DocumentType.other);
        expect(randomResult.confidence, lessThan(0.35));
      },
    );

    test(
      'resolves overlapping signals between invoice and receipt favoring dominant score',
      () {
        // Invoice that mentions receipt of payment
        const ocr = '''
        Acme Corp Tax Invoice
        Invoice No: INV-441
        Bill To: Global Tech
        Amount Due: \$500.00
        Subtotal: \$450.00
        GST: \$50.00
        Note: Receipt of initial deposit acknowledged.
      ''';

        final result = classifier.classify(ocr);
        expect(result.type, DocumentType.invoice);
      },
    );

    test('tolerates common OCR character substitutions for keywords', () {
      const ocr = '''
        ACME CORP
        TAX 1nv0ice
        INV01CE Number: INV-990
        Amount Due: \$100.00
      ''';

      final result = classifier.classify(ocr);
      expect(result.type, DocumentType.invoice);
    });
  });
}
