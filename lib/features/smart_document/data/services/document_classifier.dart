import '../../domain/entities/document_classification.dart';

/// Deterministic, rule-based on-device document classification engine.
class DocumentClassifier {
  const DocumentClassifier();

  static const String currentVersion = '1.0';
  static const double minimumConfidenceThreshold = 0.35;

  /// Classifies document from combined OCR text.
  DocumentClassification classify(String rawText) {
    if (rawText.trim().isEmpty) {
      return const DocumentClassification(
        type: DocumentType.other,
        confidence: 0.0,
        matchedSignals: [],
        classifierVersion: currentVersion,
        source: ProvenanceSource.automatic,
        explanation: 'No text available for classification',
      );
    }

    final normalized = _normalizeText(rawText);
    final scores = <DocumentType, _ScoreResult>{};

    scores[DocumentType.invoice] = _scoreInvoice(normalized);
    scores[DocumentType.receipt] = _scoreReceipt(normalized);
    scores[DocumentType.businessCard] = _scoreBusinessCard(normalized, rawText);
    scores[DocumentType.identityDocument] = _scoreIdentityDocument(normalized);
    scores[DocumentType.certificate] = _scoreCertificate(normalized);
    scores[DocumentType.letter] = _scoreLetter(normalized);
    scores[DocumentType.contract] = _scoreContract(normalized);
    scores[DocumentType.bankStatement] = _scoreBankStatement(normalized);
    scores[DocumentType.medicalDocument] = _scoreMedicalDocument(normalized);
    scores[DocumentType.taxDocument] = _scoreTaxDocument(normalized);
    scores[DocumentType.form] = _scoreForm(normalized);
    scores[DocumentType.report] = _scoreReport(normalized);
    scores[DocumentType.notes] = _scoreNotes(normalized);

    // Find highest scoring type
    DocumentType bestType = DocumentType.other;
    _ScoreResult bestScore = const _ScoreResult(0, []);

    for (final entry in scores.entries) {
      if (entry.value.score > bestScore.score) {
        bestType = entry.key;
        bestScore = entry.value;
      }
    }

    final normalizedConfidence = (bestScore.score / 100.0).clamp(0.0, 1.0);

    if (normalizedConfidence < minimumConfidenceThreshold ||
        bestScore.matchedSignals.isEmpty) {
      return DocumentClassification(
        type: DocumentType.other,
        confidence: normalizedConfidence,
        matchedSignals: bestScore.matchedSignals,
        classifierVersion: currentVersion,
        source: ProvenanceSource.automatic,
        explanation: 'Insufficient confidence for automated classification',
      );
    }

    return DocumentClassification(
      type: bestType,
      confidence: double.parse(normalizedConfidence.toStringAsFixed(2)),
      matchedSignals: bestScore.matchedSignals,
      classifierVersion: currentVersion,
      source: ProvenanceSource.automatic,
      explanation:
          'Detected ${bestType.displayName.toLowerCase()} signals: ${bestScore.matchedSignals.join(', ')}',
    );
  }

  // --- Normalization ---

  String _normalizeText(String input) {
    var text = input.toLowerCase();
    // Common OCR character substitution fixes for keywords
    text = text.replaceAll(RegExp(r'\b1nv0[i1]ce\b'), 'invoice');
    text = text.replaceAll(RegExp(r'\blnv[o0][i1]ce\b'), 'invoice');
    text = text.replaceAll(RegExp(r'\brece[i1]pt\b'), 'receipt');
    // Normalize multiple spaces and linebreaks
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    return text;
  }

  // --- Type Scorers ---

  _ScoreResult _scoreInvoice(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('tax invoice')) {
      score += 45;
      signals.add('tax invoice');
    } else if (text.contains('invoice')) {
      score += 35;
      signals.add('invoice');
    }

    if (RegExp(r'invoice\s*(no|number|#|num)\b').hasMatch(text)) {
      score += 30;
      signals.add('invoice number');
    } else if (RegExp(r'bill\s*(no|number|#)\b').hasMatch(text)) {
      score += 20;
      signals.add('bill number');
    }

    if (text.contains('bill to') ||
        text.contains('billed to') ||
        text.contains('invoice to')) {
      score += 20;
      signals.add('bill to');
    }

    if (text.contains('amount due') || text.contains('balance due')) {
      score += 20;
      signals.add('amount due');
    }

    if (text.contains('subtotal') || text.contains('sub-total')) {
      score += 10;
      signals.add('subtotal');
    }

    if (RegExp(r'\b(gstin|gst|vat|hsn|sac)\b').hasMatch(text)) {
      score += 15;
      signals.add('tax identifier');
    }

    if (text.contains('due date') || text.contains('payment terms')) {
      score += 15;
      signals.add('due date');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreReceipt(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('receipt') &&
        !text.contains('receipt of payment against invoice')) {
      score += 45;
      signals.add('receipt');
    }

    if (text.contains('cashier') ||
        text.contains('counter') ||
        text.contains('reg #') ||
        text.contains('pos #')) {
      score += 25;
      signals.add('cashier/register');
    }

    if (RegExp(r'\bchange\s*(due|given)?\b').hasMatch(text)) {
      score += 25;
      signals.add('change due');
    }

    if (text.contains('cash tender') ||
        text.contains('card tender') ||
        text.contains('card ending in')) {
      score += 20;
      signals.add('tender details');
    }

    if (text.contains('thank you for shopping') ||
        text.contains('visit again') ||
        text.contains('have a nice day')) {
      score += 20;
      signals.add('receipt closing');
    }

    if (text.contains('subtotal') || text.contains('sub-total')) {
      score += 10;
      signals.add('subtotal');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreBusinessCard(String text, String raw) {
    int score = 0;
    final signals = <String>[];

    final hasEmail = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    ).hasMatch(raw);
    if (hasEmail) {
      score += 25;
      signals.add('email');
    }

    final hasPhone = RegExp(
      r'(\+?\d{1,4}[-.\s]?)?(\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}',
    ).hasMatch(raw);
    if (hasPhone) {
      score += 25;
      signals.add('phone');
    }

    if (RegExp(
          r'\b(ceo|cto|cfo|coo|director|manager|engineer|consultant|founder|president|architect|specialist|officer|partner|developer|lead|designer)\b',
        ).hasMatch(text) ||
        RegExp(
          r'\b(chief [a-z]+ officer|vice president|managing director)\b',
        ).hasMatch(text)) {
      score += 25;
      signals.add('job title');
    }

    if (RegExp(
      r'\b(www\.[a-z0-9.-]+\.[a-z]{2,}|https?:\/\/[a-z0-9.-]+)\b',
    ).hasMatch(text)) {
      score += 15;
      signals.add('website');
    }

    // Business cards typically have fewer lines than standard full-page letters/invoices
    final lineCount = raw.split('\n').where((l) => l.trim().isNotEmpty).length;
    if (lineCount > 0 && lineCount <= 12 && (hasEmail || hasPhone)) {
      score += 20;
      signals.add('compact layout');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreIdentityDocument(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('passport') ||
        text.contains('republic of') ||
        text.contains('passaporto')) {
      score += 50;
      signals.add('passport');
    }

    if (text.contains('driver license') ||
        text.contains('driving licence') ||
        text.contains('driver\'s license')) {
      score += 50;
      signals.add('driving license');
    }

    if (text.contains('identity card') ||
        text.contains('national id') ||
        text.contains('aadhaar') ||
        text.contains('pan card')) {
      score += 45;
      signals.add('id card');
    }

    if (text.contains('date of birth') ||
        text.contains('dob:') ||
        text.contains('d.o.b')) {
      score += 25;
      signals.add('date of birth');
    }

    if (RegExp(r'\b(nationality|sex|gender|place of issue)\b').hasMatch(text)) {
      score += 20;
      signals.add('identity attributes');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreCertificate(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('certificate of') || text.contains('certificate')) {
      score += 45;
      signals.add('certificate');
    }

    if (text.contains('certify that') || text.contains('certifies that')) {
      score += 35;
      signals.add('certifies that');
    }

    if (text.contains('awarded to') ||
        text.contains('presented to') ||
        text.contains('this is to certify')) {
      score += 35;
      signals.add('awarded to');
    }

    if (text.contains('in recognition of') ||
        text.contains('completion of') ||
        text.contains('achievement')) {
      score += 20;
      signals.add('achievement');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreLetter(String text) {
    int score = 0;
    final signals = <String>[];

    if (RegExp(r'\bdear (mr|ms|mrs|dr|sir|madam|[a-z]+)\b').hasMatch(text)) {
      score += 35;
      signals.add('salutation');
    }

    if (text.contains('to whom it may concern')) {
      score += 40;
      signals.add('formal salutation');
    }

    if (RegExp(
      r'\b(sincerely|yours truly|warm regards|best regards|regards|faithfully)\b',
    ).hasMatch(text)) {
      score += 35;
      signals.add('closing signoff');
    }

    if (RegExp(r'\bsubject\s*:').hasMatch(text)) {
      score += 20;
      signals.add('subject line');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreContract(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('agreement') || text.contains('contract')) {
      score += 35;
      signals.add('agreement/contract');
    }

    if (text.contains('by and between') ||
        text.contains('entered into by') ||
        text.contains('parties hereto')) {
      score += 35;
      signals.add('parties clause');
    }

    if (text.contains('in witness whereof') ||
        text.contains('whereas') ||
        text.contains('now therefore')) {
      score += 35;
      signals.add('formal contract language');
    }

    if (text.contains('terms and conditions') ||
        text.contains('terms of service')) {
      score += 25;
      signals.add('terms and conditions');
    }

    if (text.contains('governing law') ||
        text.contains('jurisdiction') ||
        text.contains('severability')) {
      score += 25;
      signals.add('legal boilerplate');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreBankStatement(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('bank statement') || text.contains('account statement')) {
      score += 50;
      signals.add('account statement');
    }

    if (text.contains('opening balance') || text.contains('closing balance')) {
      score += 35;
      signals.add('balance summary');
    }

    if (text.contains('deposits') ||
        text.contains('withdrawals') ||
        text.contains('credits') ||
        text.contains('debits')) {
      score += 25;
      signals.add('statement transactions');
    }

    if (text.contains('statement period') || text.contains('statement date')) {
      score += 25;
      signals.add('statement period');
    }

    if (RegExp(r'account\s*(number|no|#)\b').hasMatch(text)) {
      score += 20;
      signals.add('account number');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreMedicalDocument(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('patient') || text.contains('patient name')) {
      score += 35;
      signals.add('patient');
    }

    if (RegExp(
      r'\b(doctor|physician|dr\.|nurse|practitioner)\b',
    ).hasMatch(text)) {
      score += 25;
      signals.add('physician');
    }

    if (text.contains('diagnosis') ||
        text.contains('symptoms') ||
        text.contains('medical history')) {
      score += 35;
      signals.add('diagnosis');
    }

    if (text.contains('prescription') ||
        text.contains('rx') ||
        text.contains('dosage') ||
        text.contains('medication')) {
      score += 35;
      signals.add('prescription');
    }

    if (text.contains('hospital') ||
        text.contains('clinic') ||
        text.contains('medical center')) {
      score += 25;
      signals.add('hospital/clinic');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreTaxDocument(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('tax return') ||
        text.contains('income tax return') ||
        text.contains('itr-')) {
      score += 50;
      signals.add('tax return');
    }

    if (RegExp(
      r'\b(form 1040|w-2|1099-misc|1099|schedule c|form 16)\b',
    ).hasMatch(text)) {
      score += 50;
      signals.add('tax form code');
    }

    if (text.contains('internal revenue service') ||
        text.contains('irs') ||
        text.contains('income tax department')) {
      score += 40;
      signals.add('tax authority');
    }

    if (text.contains('taxable income') ||
        text.contains('assessment year') ||
        text.contains('total tax payable')) {
      score += 30;
      signals.add('tax computations');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreForm(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('application form') ||
        text.contains('registration form') ||
        text.contains('enrollment form')) {
      score += 45;
      signals.add('form title');
    }

    if (text.contains('please print') ||
        text.contains('fill in') ||
        text.contains('check appropriate box')) {
      score += 25;
      signals.add('form instructions');
    }

    if (text.contains('signature of applicant') ||
        text.contains('applicant signature') ||
        text.contains('signature:')) {
      score += 25;
      signals.add('applicant signature');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreReport(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('executive summary') ||
        text.contains('annual report') ||
        text.contains('financial report')) {
      score += 45;
      signals.add('report title');
    }

    if (text.contains('table of contents') ||
        text.contains('findings') ||
        text.contains('recommendations')) {
      score += 25;
      signals.add('report structure');
    }

    return _ScoreResult(score, signals);
  }

  _ScoreResult _scoreNotes(String text) {
    int score = 0;
    final signals = <String>[];

    if (text.contains('meeting notes') ||
        text.contains('meeting minutes') ||
        text.contains('action items')) {
      score += 45;
      signals.add('meeting notes');
    }

    if (text.contains('agenda') ||
        text.contains('todo list') ||
        text.contains('attendees:')) {
      score += 30;
      signals.add('notes agenda');
    }

    return _ScoreResult(score, signals);
  }
}

class _ScoreResult {
  const _ScoreResult(this.score, this.matchedSignals);
  final int score;
  final List<String> matchedSignals;
}
