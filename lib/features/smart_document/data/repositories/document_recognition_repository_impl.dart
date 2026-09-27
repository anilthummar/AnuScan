import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../ocr/domain/usecases/ocr_usecases.dart';
import '../../domain/entities/document_classification.dart';
import '../../domain/entities/document_metadata.dart';
import '../../domain/entities/document_recognition_result.dart';
import '../../domain/repositories/document_recognition_repository.dart';
import '../datasources/local_recognition_datasource.dart';
import '../models/recognition_dto.dart';
import '../services/document_recognition_service.dart';
import '../services/smart_filename_generator.dart';

class DocumentRecognitionRepositoryImpl
    implements DocumentRecognitionRepository {
  DocumentRecognitionRepositoryImpl({
    required this.recognitionService,
    required this.localDataSource,
    required this.getDocumentOcrUseCase,
    this.filenameGenerator = const SmartFilenameGenerator(),
  });

  final DocumentRecognitionService recognitionService;
  final LocalRecognitionDataSource localDataSource;
  final GetDocumentOcrUseCase getDocumentOcrUseCase;
  final SmartFilenameGenerator filenameGenerator;

  @override
  Future<Result<DocumentRecognitionResult>> recognizeDocument({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) async {
    try {
      // 1. Check existing cached recognition
      final cachedDto = await localDataSource.getRecognition(documentId);
      if (cachedDto != null && !force) {
        return Result.success(_mapDtoToEntity(cachedDto));
      }

      // 2. Fetch OCR text for the document
      final ocrResult = await getDocumentOcrUseCase(documentId);
      final combinedText = ocrResult.fold(
        onFailure: (_) => '',
        onSuccess: (data) => data.combinedText,
      );

      // 3. Execute recognition
      var recognition = await recognitionService.recognize(
        documentId: documentId,
        combinedText: combinedText,
      );

      // 4. Preserve manual overrides if previously set and not explicitly reset
      if (cachedDto != null && cachedDto.classificationSource == 'manual') {
        final manualType = DocumentType.values.firstWhere(
          (t) => t.name == cachedDto.documentType,
          orElse: () => DocumentType.other,
        );

        final preservedClassification = recognition.classification.copyWith(
          type: manualType,
          source: ProvenanceSource.manual,
        );

        final preservedMetadata = recognition.metadata.copyWith(
          personName: cachedDto.personName ?? recognition.metadata.personName,
          companyName:
              cachedDto.companyName ?? recognition.metadata.companyName,
          documentNumber:
              cachedDto.documentNumber ?? recognition.metadata.documentNumber,
          source: ProvenanceSource.manual,
        );

        final suggestedName = filenameGenerator.generate(
          classification: preservedClassification,
          metadata: preservedMetadata,
        );

        recognition = recognition.copyWith(
          classification: preservedClassification,
          metadata: preservedMetadata,
          suggestedFilename: suggestedName,
        );
      }

      // 5. Persist locally
      await localDataSource.saveRecognition(_mapEntityToDto(recognition));

      return Result.success(recognition);
    } catch (e) {
      return Result.failure(StorageFailure('Document recognition failed: $e'));
    }
  }

  @override
  Future<Result<DocumentRecognitionResult?>> getRecognition(
    String documentId,
  ) async {
    try {
      final dto = await localDataSource.getRecognition(documentId);
      if (dto == null) return const Result.success(null);
      return Result.success(_mapDtoToEntity(dto));
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to load document recognition: $e'),
      );
    }
  }

  @override
  Future<Result<void>> saveRecognition(DocumentRecognitionResult result) async {
    try {
      await localDataSource.saveRecognition(_mapEntityToDto(result));
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to save document recognition: $e'),
      );
    }
  }

  @override
  Future<Result<void>> updateManualClassification({
    required String documentId,
    required DocumentType manualType,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await localDataSource.updateManualClassification(
        documentId: documentId,
        documentType: manualType.name,
        updatedAt: now,
      );

      // Recompute suggested filename with updated manual type
      final existing = await localDataSource.getRecognition(documentId);
      if (existing != null) {
        final entity = _mapDtoToEntity(existing);
        final updatedClassification = entity.classification.copyWith(
          type: manualType,
          source: ProvenanceSource.manual,
        );
        final newFilename = filenameGenerator.generate(
          classification: updatedClassification,
          metadata: entity.metadata,
        );
        final updatedDto = _mapEntityToDto(
          entity.copyWith(
            classification: updatedClassification,
            suggestedFilename: newFilename,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
          ),
        );
        await localDataSource.saveRecognition(updatedDto);
      }

      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to update manual classification: $e'),
      );
    }
  }

  @override
  Future<Result<void>> updateManualMetadata({
    required String documentId,
    required DocumentMetadata updatedMetadata,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final existing = await localDataSource.getRecognition(documentId);
      if (existing != null) {
        final entity = _mapDtoToEntity(existing);
        final newFilename = filenameGenerator.generate(
          classification: entity.classification,
          metadata: updatedMetadata,
        );

        final updatedDto = _mapEntityToDto(
          entity.copyWith(
            metadata: updatedMetadata.copyWith(source: ProvenanceSource.manual),
            suggestedFilename: newFilename,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
          ),
        );
        await localDataSource.saveRecognition(updatedDto);
      }

      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to update manual metadata: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteRecognition(String documentId) async {
    try {
      await localDataSource.deleteRecognition(documentId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(StorageFailure('Failed to delete recognition: $e'));
    }
  }

  @override
  Future<Result<String>> suggestFilename({
    required DocumentClassification classification,
    required DocumentMetadata metadata,
    String? fallbackName,
  }) async {
    try {
      final suggestion = filenameGenerator.generate(
        classification: classification,
        metadata: metadata,
        fallbackName: fallbackName,
      );
      return Result.success(suggestion);
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to generate suggested filename: $e'),
      );
    }
  }

  // --- DTO Mappings ---

  DocumentRecognitionResult _mapDtoToEntity(DocumentRecognitionDto dto) {
    final docType = DocumentType.values.firstWhere(
      (t) => t.name == dto.documentType,
      orElse: () => DocumentType.other,
    );

    final classification = DocumentClassification(
      type: docType,
      confidence: dto.confidence,
      matchedSignals: dto.matchedSignals.isNotEmpty
          ? dto.matchedSignals.split(',').map((s) => s.trim()).toList()
          : const [],
      classifierVersion: dto.classifierVersion,
      source: dto.classificationSource == 'manual'
          ? ProvenanceSource.manual
          : ProvenanceSource.automatic,
      explanation: 'Detected ${docType.displayName} signals',
    );

    Map<String, String> customFields = const {};
    if (dto.metadataJson != null && dto.metadataJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(dto.metadataJson!) as Map<String, dynamic>;
        customFields = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    final metadata = DocumentMetadata(
      personName: dto.personName,
      companyName: dto.companyName,
      documentNumber: dto.documentNumber,
      invoiceNumber: docType == DocumentType.invoice
          ? dto.documentNumber
          : null,
      receiptNumber: docType == DocumentType.receipt
          ? dto.documentNumber
          : null,
      date: dto.dateText,
      dueDate: dto.dueDateText,
      amount: dto.amount,
      currency: dto.currency,
      amountText: dto.amountText,
      email: dto.email,
      phone: dto.phone,
      website: dto.website,
      source: dto.classificationSource == 'manual'
          ? ProvenanceSource.manual
          : ProvenanceSource.automatic,
      customFields: customFields,
    );

    return DocumentRecognitionResult(
      documentId: dto.documentId,
      classification: classification,
      metadata: metadata,
      suggestedFilename: dto.suggestedFilename ?? 'Document',
      recognitionVersion: dto.classifierVersion,
      createdAt: DateTime.fromMillisecondsSinceEpoch(dto.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(dto.updatedAt),
    );
  }

  DocumentRecognitionDto _mapEntityToDto(DocumentRecognitionResult entity) {
    String? metadataJson;
    if (entity.metadata.customFields.isNotEmpty) {
      metadataJson = jsonEncode(entity.metadata.customFields);
    }

    return DocumentRecognitionDto(
      id: const Uuid().v4(),
      documentId: entity.documentId,
      documentType: entity.classification.type.name,
      classificationSource: entity.classification.source.name,
      confidence: entity.classification.confidence,
      matchedSignals: entity.classification.matchedSignals.join(','),
      classifierVersion: entity.recognitionVersion,
      suggestedFilename: entity.suggestedFilename,
      personName: entity.metadata.personName,
      companyName: entity.metadata.companyName,
      documentNumber: entity.metadata.primaryIdentifier,
      dateText: entity.metadata.date,
      dueDateText: entity.metadata.dueDate,
      amountText: entity.metadata.amountText,
      amount: entity.metadata.amount,
      currency: entity.metadata.currency,
      email: entity.metadata.email,
      phone: entity.metadata.phone,
      website: entity.metadata.website,
      metadataJson: metadataJson,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}
