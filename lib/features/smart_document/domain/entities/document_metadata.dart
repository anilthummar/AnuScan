import 'package:equatable/equatable.dart';
import 'document_classification.dart';

/// Structured metadata extracted from document text with high confidence.
class DocumentMetadata extends Equatable {
  const DocumentMetadata({
    this.personName,
    this.companyName,
    this.documentNumber,
    this.invoiceNumber,
    this.receiptNumber,
    this.date,
    this.dueDate,
    this.amount,
    this.currency,
    this.amountText,
    this.email,
    this.phone,
    this.website,
    this.address,
    this.title,
    this.category,
    this.source = ProvenanceSource.automatic,
    this.customFields = const {},
  });

  final String? personName;
  final String? companyName;
  final String? documentNumber;
  final String? invoiceNumber;
  final String? receiptNumber;
  final String? date;
  final String? dueDate;
  final double? amount;
  final String? currency;
  final String? amountText;
  final String? email;
  final String? phone;
  final String? website;
  final String? address;
  final String? title;
  final String? category;
  final ProvenanceSource source;
  final Map<String, String> customFields;

  bool get isEmpty =>
      personName == null &&
      companyName == null &&
      documentNumber == null &&
      invoiceNumber == null &&
      receiptNumber == null &&
      date == null &&
      dueDate == null &&
      amount == null &&
      currency == null &&
      amountText == null &&
      email == null &&
      phone == null &&
      website == null &&
      address == null &&
      title == null &&
      category == null &&
      customFields.isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// Returns the most specific identifier available.
  String? get primaryIdentifier =>
      invoiceNumber ?? receiptNumber ?? documentNumber;

  /// Returns the primary entity name (company or person).
  String? get primaryEntity => companyName ?? personName;

  DocumentMetadata copyWith({
    String? personName,
    String? companyName,
    String? documentNumber,
    String? invoiceNumber,
    String? receiptNumber,
    String? date,
    String? dueDate,
    double? amount,
    String? currency,
    String? amountText,
    String? email,
    String? phone,
    String? website,
    String? address,
    String? title,
    String? category,
    ProvenanceSource? source,
    Map<String, String>? customFields,
  }) {
    return DocumentMetadata(
      personName: personName ?? this.personName,
      companyName: companyName ?? this.companyName,
      documentNumber: documentNumber ?? this.documentNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      amountText: amountText ?? this.amountText,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      address: address ?? this.address,
      title: title ?? this.title,
      category: category ?? this.category,
      source: source ?? this.source,
      customFields: customFields ?? this.customFields,
    );
  }

  @override
  List<Object?> get props => [
    personName,
    companyName,
    documentNumber,
    invoiceNumber,
    receiptNumber,
    date,
    dueDate,
    amount,
    currency,
    amountText,
    email,
    phone,
    website,
    address,
    title,
    category,
    source,
    customFields,
  ];
}
