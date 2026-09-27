import 'package:equatable/equatable.dart';
import '../../domain/entities/document_classification.dart';
import '../../domain/entities/document_recognition_result.dart';

abstract class SmartDocumentState extends Equatable {
  const SmartDocumentState();

  @override
  List<Object?> get props => [];
}

class SmartDocumentInitial extends SmartDocumentState {
  const SmartDocumentInitial();
}

class SmartDocumentLoading extends SmartDocumentState {
  const SmartDocumentLoading({this.message = 'Analyzing document...'});
  final String message;

  @override
  List<Object?> get props => [message];
}

class SmartDocumentSuccess extends SmartDocumentState {
  const SmartDocumentSuccess({
    required this.result,
    this.isNameApplied = false,
    this.isEditingMetadata = false,
  });

  final DocumentRecognitionResult result;
  final bool isNameApplied;
  final bool isEditingMetadata;

  DocumentClassification get classification => result.classification;
  DocumentType get documentType => classification.type;
  String get suggestedFilename => result.suggestedFilename;

  SmartDocumentSuccess copyWith({
    DocumentRecognitionResult? result,
    bool? isNameApplied,
    bool? isEditingMetadata,
  }) {
    return SmartDocumentSuccess(
      result: result ?? this.result,
      isNameApplied: isNameApplied ?? this.isNameApplied,
      isEditingMetadata: isEditingMetadata ?? this.isEditingMetadata,
    );
  }

  @override
  List<Object?> get props => [result, isNameApplied, isEditingMetadata];
}

class SmartDocumentFailure extends SmartDocumentState {
  const SmartDocumentFailure({required this.message, this.fallbackName});

  final String message;
  final String? fallbackName;

  @override
  List<Object?> get props => [message, fallbackName];
}
