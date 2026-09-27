import '../../domain/entities/document_classification.dart';
import '../../domain/entities/document_metadata.dart';

/// Deterministic, rule-based metadata extractor for scanned documents.
class DocumentMetadataExtractor {
  const DocumentMetadataExtractor();

  /// Extracts structured metadata based on document classification type and text.
  DocumentMetadata extract({
    required String rawText,
    required DocumentClassification classification,
  }) {
    if (rawText.trim().isEmpty) {
      return const DocumentMetadata(source: ProvenanceSource.automatic);
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final invoiceNumber = _extractInvoiceNumber(rawText);
    final receiptNumber = _extractReceiptNumber(rawText);
    final documentNumber = _extractDocumentNumber(rawText);
    final date = _extractDate(rawText);
    final dueDate = _extractDueDate(rawText);
    final totalAmount = _extractTotalAmount(rawText);
    final email = _extractEmail(rawText);
    final phone = _extractPhone(rawText);
    final website = _extractWebsite(rawText);
    final companyName = _extractCompanyName(lines, classification);
    final personName = _extractPersonName(lines, classification);

    return DocumentMetadata(
      personName: personName,
      companyName: companyName,
      documentNumber: documentNumber,
      invoiceNumber: invoiceNumber,
      receiptNumber: receiptNumber,
      date: date,
      dueDate: dueDate,
      amount: totalAmount?.amount,
      currency: totalAmount?.currency,
      amountText: totalAmount?.formattedText,
      email: email,
      phone: phone,
      website: website,
      source: ProvenanceSource.automatic,
    );
  }

  // --- Identifier Extractors ---

  String? _extractInvoiceNumber(String text) {
    final match =
        RegExp(
          r'(?:^|\b)(?:invoice|inv|bill)\s*(?:no\.?|number|#|num|id)?\s*[:#]\s*([A-Za-z0-9\-_/]+)',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(text) ??
        RegExp(
          r'(?:^|\b)(?:invoice|inv|bill)\s+(?:no\.?|number|#|num|id)\b\s*[:.-]?\s*([A-Za-z0-9\-_/]+)',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(text);

    if (match != null) {
      final val = match.group(1)?.trim();
      if (val != null && val.isNotEmpty && !_isGenericLabel(val)) {
        return val;
      }
    }
    return null;
  }

  String? _extractReceiptNumber(String text) {
    final match =
        RegExp(
          r'(?:^|\b)(?:receipt|rcpt|order|txn|ticket)\s*(?:no\.?|number|#|num|id)?\s*[:#]\s*([A-Za-z0-9\-_/]+)',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(text) ??
        RegExp(
          r'(?:^|\b)(?:receipt|rcpt|order|txn|ticket)\s+(?:no\.?|number|#|num|id)\b\s*[:.-]?\s*([A-Za-z0-9\-_/]+)',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(text);

    if (match != null) {
      final val = match.group(1)?.trim();
      if (val != null && val.isNotEmpty && !_isGenericLabel(val)) {
        return val;
      }
    }
    return null;
  }

  String? _extractDocumentNumber(String text) {
    final match =
        RegExp(
          r'(?:^|\b)(?:doc|document|ref|reference|certificate|policy)\s*(?:no\.?|number|#|num|id)?\s*[:#]\s*([A-Za-z0-9\-_/]+)',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(text) ??
        RegExp(
          r'(?:^|\b)(?:doc|document|ref|reference|certificate|policy)\s+(?:no\.?|number|#|num|id|ref)\b\s*[:.-]?\s*([A-Za-z0-9\-_/]+)',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(text);

    if (match != null) {
      final val = match.group(1)?.trim();
      if (val != null && val.isNotEmpty && !_isGenericLabel(val)) {
        return val;
      }
    }
    return null;
  }

  // --- Date Extractors ---

  String? _extractDate(String text) {
    // 1. First look near explicit "Date:" label
    final labeledMatch = RegExp(
      r'(?:date|invoice date|dated|issued)\s*[:.-]?\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}|[0-9]{4}[/-][0-9]{1,2}[/-][0-9]{1,2}|[0-9]{1,2}\s+[A-Za-z]{3,9}\s+[0-9]{4}|[A-Za-z]{3,9}\s+[0-9]{1,2},?\s+[0-9]{4})',
      caseSensitive: false,
    ).firstMatch(text);

    if (labeledMatch != null) {
      return labeledMatch.group(1)?.trim();
    }

    // 2. Generic date regex fallback
    final genericMatch = RegExp(
      r'\b([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}|[0-9]{4}[/-][0-9]{1,2}[/-][0-9]{1,2}|[0-9]{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+[0-9]{4})\b',
      caseSensitive: false,
    ).firstMatch(text);

    return genericMatch?.group(1)?.trim();
  }

  String? _extractDueDate(String text) {
    final match = RegExp(
      r'(?:due date|payment due|due by|pay by)\s*[:.-]?\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}|[0-9]{4}[/-][0-9]{1,2}[/-][0-9]{1,2}|[0-9]{1,2}\s+[A-Za-z]{3,9}\s+[0-9]{4})',
      caseSensitive: false,
    ).firstMatch(text);

    return match?.group(1)?.trim();
  }

  // --- Financial Amounts ---

  _AmountInfo? _extractTotalAmount(String text) {
    // 1. High-priority grand total / balance due keywords
    final highPriorityRegex = RegExp(
      r'(?:grand total|total amount|amount due|balance due|total due|net total)\s*[:.-]?\s*([₹$€£]|Rs\.?|INR|USD|EUR|GBP)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]+(?:[.,][0-9]{2})?)',
      caseSensitive: false,
    );
    final highMatch = highPriorityRegex.firstMatch(text);
    if (highMatch != null) {
      final res = _parseMatchedAmount(highMatch, text);
      if (res != null) return res;
    }

    // 2. Regular total keyword (avoiding subtotal)
    final totalRegex = RegExp(
      r'(?:^|[^a-zA-Z])total\s*[:.-]?\s*([₹$€£]|Rs\.?|INR|USD|EUR|GBP)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]+(?:[.,][0-9]{2})?)',
      caseSensitive: false,
    );
    for (final m in totalRegex.allMatches(text)) {
      final res = _parseMatchedAmount(m, text);
      if (res != null) return res;
    }

    return null;
  }

  _AmountInfo? _parseMatchedAmount(Match m, String fullText) {
    final currency = m.group(1)?.trim();
    final numStr = m.group(2)?.trim();

    if (numStr != null && numStr.isNotEmpty) {
      final parsed = _parseAmountNumber(numStr);
      if (parsed != null && parsed > 0.0) {
        final effectiveCurrency =
            currency ?? _detectGlobalCurrency(fullText) ?? '';
        final formatted = effectiveCurrency.isNotEmpty
            ? '$effectiveCurrency$numStr'
            : numStr;

        return _AmountInfo(
          amount: parsed,
          currency: effectiveCurrency.isNotEmpty ? effectiveCurrency : null,
          formattedText: formatted,
        );
      }
    }
    return null;
  }

  double? _parseAmountNumber(String str) {
    try {
      var clean = str.trim();
      // Detect European format: "2.450,00" where dot is thousand separator and comma is decimal
      if (clean.contains(',') && clean.contains('.')) {
        if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
          clean = clean.replaceAll('.', '').replaceAll(',', '.');
        } else {
          clean = clean.replaceAll(',', '');
        }
      } else if (clean.contains(',')) {
        final commaIdx = clean.lastIndexOf(',');
        if (clean.length - commaIdx - 1 == 2) {
          clean = clean.replaceAll(',', '.');
        } else {
          clean = clean.replaceAll(',', '');
        }
      }
      return double.tryParse(clean);
    } catch (_) {
      return null;
    }
  }

  String? _detectGlobalCurrency(String text) {
    if (text.contains('₹') ||
        RegExp(r'\b(inr|rs\.?)\b', caseSensitive: false).hasMatch(text)) {
      return '₹';
    }
    if (text.contains('\$') ||
        RegExp(r'\busd\b', caseSensitive: false).hasMatch(text)) {
      return '\$';
    }
    if (text.contains('€') ||
        RegExp(r'\beur\b', caseSensitive: false).hasMatch(text)) {
      return '€';
    }
    if (text.contains('£') ||
        RegExp(r'\bgbp\b', caseSensitive: false).hasMatch(text)) {
      return '£';
    }
    return null;
  }

  // --- Contact & Entity Info ---

  String? _extractEmail(String text) {
    final match = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
    ).firstMatch(text);
    return match?.group(0)?.trim();
  }

  String? _extractPhone(String text) {
    // 1. Explicit phone label
    final labeledMatch = RegExp(
      r'(?:phone|tel|mobile|cell|call|fax|ph)\s*[:.-]?\s*(\+?[0-9\s().-]{8,22})',
      caseSensitive: false,
    ).firstMatch(text);

    if (labeledMatch != null) {
      final raw = labeledMatch.group(1)?.trim() ?? '';
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 8 && digits.length <= 15) {
        return raw;
      }
    }

    // 2. Formatted phone pattern fallback (+country or (xxx))
    final formattedMatch = RegExp(
      r'(?:\+[0-9]{1,3}[-.\s]|\([0-9]{2,4}\)[-.\s]?)[0-9]{3,4}[-.\s]?[0-9]{3,4}',
    ).firstMatch(text);

    if (formattedMatch != null) {
      final raw = formattedMatch.group(0)?.trim() ?? '';
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 8 && digits.length <= 15) {
        return raw;
      }
    }

    return null;
  }

  String? _extractWebsite(String text) {
    final match = RegExp(
      r'\b(?:https?:\/\/|www\.)[A-Za-z0-9.-]+\.[A-Za-z]{2,}(?:\/[^\s]*)?\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      var url = match.group(0)?.trim();
      return url;
    }
    return null;
  }

  String? _extractCompanyName(
    List<String> lines,
    DocumentClassification classification,
  ) {
    if (lines.isEmpty) return null;

    // Check first 4 lines for company indicators or clean header
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      if (_isGenericHeader(line)) continue;

      if (RegExp(
        r'\b(corp|corporation|inc|incorporated|llc|ltd|limited|technologies|solutions|services|store|market|pharmacy|hospital|clinic|university|bank)\b',
        caseSensitive: false,
      ).hasMatch(line)) {
        return line.replaceAll(RegExp(r'[:|]'), '').trim();
      }
    }

    // For invoices/receipts: first non-generic line is often the store/vendor
    if (classification.type == DocumentType.invoice ||
        classification.type == DocumentType.receipt) {
      for (final line in lines.take(3)) {
        if (!_isGenericHeader(line) &&
            line.length >= 3 &&
            line.length <= 40 &&
            !RegExp(r'^[0-9\W]+$').hasMatch(line)) {
          return line.replaceAll(RegExp(r'[:|]'), '').trim();
        }
      }
    }

    return null;
  }

  String? _extractPersonName(
    List<String> lines,
    DocumentClassification classification,
  ) {
    // 1. Certificate: look after "awarded to" or "certify that"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('awarded to') ||
          line.contains('certify that') ||
          line.contains('presented to')) {
        if (i + 1 < lines.length) {
          final candidate = lines[i + 1].trim();
          if (candidate.isNotEmpty && !_isGenericHeader(candidate)) {
            return candidate;
          }
        }
      }
    }

    // 2. Explicit person labels: "Bill To:", "Attn:", "Patient:", "Customer:"
    for (final line in lines) {
      final labeledMatch = RegExp(
        r'(?:bill to|billed to|invoice to|attn|attention|patient|patient name|recipient|customer name)\s*[:.-]\s*([A-Za-z\s.\-]+)',
        caseSensitive: false,
      ).firstMatch(line);

      if (labeledMatch != null) {
        final candidate = labeledMatch.group(1)?.trim();
        if (candidate != null &&
            candidate.isNotEmpty &&
            !_isGenericHeader(candidate) &&
            candidate.split(' ').length <= 5) {
          return candidate;
        }
      }
    }

    // 3. Business Card: look for personal titles (Dr., Mr., etc.) or first line
    if (classification.type == DocumentType.businessCard && lines.isNotEmpty) {
      for (final line in lines.take(3)) {
        if (RegExp(
          r'^(dr|mr|ms|mrs|prof)\.?\s+',
          caseSensitive: false,
        ).hasMatch(line)) {
          return line.trim();
        }
      }
      // If first line isn't a company, it's often the person name
      final first = lines.first;
      if (!_isGenericHeader(first) &&
          !RegExp(
            r'\b(corp|inc|llc|ltd|solutions|tech)\b',
            caseSensitive: false,
          ).hasMatch(first) &&
          first.split(' ').length <= 4) {
        return first;
      }
    }

    return null;
  }

  bool _isGenericHeader(String text) {
    final lower = text.toLowerCase().trim();
    return lower == 'invoice' ||
        lower == 'tax invoice' ||
        lower == 'receipt' ||
        lower == 'cash receipt' ||
        lower == 'bill' ||
        lower == 'statement' ||
        lower == 'document' ||
        lower == 'page 1' ||
        lower == 'welcome' ||
        lower.startsWith('page ');
  }

  bool _isGenericLabel(String text) {
    final lower = text.toLowerCase().trim();
    return lower == 'no' ||
        lower == 'number' ||
        lower == 'date' ||
        lower == 'total' ||
        lower == 'invoice' ||
        lower == 'receipt' ||
        lower == 'of' ||
        lower == 'to' ||
        lower == 'for' ||
        lower == 'the' ||
        lower == 'a' ||
        lower == 'an';
  }
}

class _AmountInfo {
  const _AmountInfo({
    required this.amount,
    this.currency,
    required this.formattedText,
  });

  final double amount;
  final String? currency;
  final String formattedText;
}
