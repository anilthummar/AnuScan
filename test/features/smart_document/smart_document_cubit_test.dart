import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_classification.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_metadata.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_recognition_result.dart';
import 'package:anuscan/features/smart_document/domain/repositories/document_recognition_repository.dart';
import 'package:anuscan/features/smart_document/domain/usecases/smart_document_usecases.dart';
import 'package:anuscan/features/smart_document/presentation/cubit/smart_document_cubit.dart';
import 'package:anuscan/features/smart_document/presentation/cubit/smart_document_state.dart';

class FakeDocumentRecognitionRepository
    implements DocumentRecognitionRepository {
  DocumentRecognitionResult? storedResult;
  bool shouldFail = false;

  @override
  Future<Result<DocumentRecognitionResult>> recognizeDocument({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) async {
    if (shouldFail) {
      return Result.failure(const StorageFailure('Recognition failed'));
    }
    final res =
        storedResult ??
        DocumentRecognitionResult(
          documentId: documentId,
          classification: const DocumentClassification(
            type: DocumentType.invoice,
            confidence: 0.9,
            matchedSignals: ['tax invoice'],
          ),
          metadata: const DocumentMetadata(
            companyName: 'Acme Corp',
            invoiceNumber: 'INV-100',
          ),
          suggestedFilename: 'Acme Corp - Invoice - INV-100',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    storedResult = res;
    return Result.success(res);
  }

  @override
  Future<Result<DocumentRecognitionResult?>> getRecognition(
    String documentId,
  ) async {
    if (shouldFail) {
      return Result.failure(const StorageFailure('Failed to get'));
    }
    return Result.success(storedResult);
  }

  @override
  Future<Result<void>> saveRecognition(DocumentRecognitionResult result) async {
    storedResult = result;
    return Result.success(null);
  }

  @override
  Future<Result<void>> updateManualClassification({
    required String documentId,
    required DocumentType manualType,
  }) async {
    if (storedResult != null) {
      storedResult = storedResult!.copyWith(
        classification: DocumentClassification(
          type: manualType,
          confidence: 1.0,
          source: ProvenanceSource.manual,
        ),
      );
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> updateManualMetadata({
    required String documentId,
    required DocumentMetadata updatedMetadata,
  }) async {
    if (storedResult != null) {
      storedResult = storedResult!.copyWith(
        metadata: updatedMetadata.copyWith(source: ProvenanceSource.manual),
      );
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> deleteRecognition(String documentId) async {
    storedResult = null;
    return Result.success(null);
  }

  @override
  Future<Result<String>> suggestFilename({
    required DocumentClassification classification,
    required DocumentMetadata metadata,
    String? fallbackName,
  }) async {
    return Result.success('SuggestedName');
  }
}

void main() {
  late FakeDocumentRecognitionRepository repository;
  late SmartDocumentCubit cubit;

  setUp(() {
    repository = FakeDocumentRecognitionRepository();
    cubit = SmartDocumentCubit(
      recognizeDocumentUseCase: RecognizeDocumentUseCase(repository),
      getDocumentRecognitionUseCase: GetDocumentRecognitionUseCase(repository),
      overrideDocumentTypeUseCase: OverrideDocumentTypeUseCase(repository),
      updateDocumentMetadataUseCase: UpdateDocumentMetadataUseCase(repository),
      suggestDocumentNameUseCase: SuggestDocumentNameUseCase(repository),
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('SmartDocumentCubit Tests', () {
    test('initial state is SmartDocumentInitial', () {
      expect(cubit.state, isA<SmartDocumentInitial>());
    });

    test(
      'loadOrRecognize emits Loading then Success on valid recognition',
      () async {
        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<SmartDocumentLoading>(),
            isA<SmartDocumentSuccess>().having(
              (s) => s.result.classification.type,
              'type',
              DocumentType.invoice,
            ),
          ]),
        );

        await cubit.loadOrRecognize(documentId: 'doc_1', pages: const []);
      },
    );

    test(
      'loadOrRecognize emits Loading then Failure when repository fails',
      () async {
        repository.shouldFail = true;

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<SmartDocumentLoading>(),
            isA<SmartDocumentFailure>().having(
              (s) => s.message,
              'message',
              'Recognition failed',
            ),
          ]),
        );

        await cubit.loadOrRecognize(documentId: 'doc_1', pages: const []);
      },
    );

    test(
      'overrideDocumentType updates classification and emits updated Success',
      () async {
        await cubit.loadOrRecognize(documentId: 'doc_1', pages: const []);

        expect(cubit.state, isA<SmartDocumentSuccess>());
        expect(
          (cubit.state as SmartDocumentSuccess).result.classification.type,
          DocumentType.invoice,
        );

        await cubit.overrideDocumentType(DocumentType.receipt);

        final state = cubit.state as SmartDocumentSuccess;
        expect(state.result.classification.type, equals(DocumentType.receipt));
        expect(
          state.result.classification.source,
          equals(ProvenanceSource.manual),
        );
        expect(state.result.classification.isManual, isTrue);
      },
    );

    test(
      'updateMetadata modifies metadata and marks source as manual',
      () async {
        await cubit.loadOrRecognize(documentId: 'doc_1', pages: const []);

        const updatedMeta = DocumentMetadata(
          companyName: 'New Corporation Ltd',
          personName: 'Alice Springs',
        );

        await cubit.updateMetadata(updatedMeta);

        final state = cubit.state as SmartDocumentSuccess;
        expect(
          state.result.metadata.companyName,
          equals('New Corporation Ltd'),
        );
        expect(state.result.metadata.personName, equals('Alice Springs'));
        expect(state.result.metadata.source, equals(ProvenanceSource.manual));
      },
    );

    test(
      'markNameApplied updates isNameApplied flag in Success state',
      () async {
        await cubit.loadOrRecognize(documentId: 'doc_1', pages: const []);

        expect((cubit.state as SmartDocumentSuccess).isNameApplied, isFalse);

        cubit.markNameApplied();

        expect((cubit.state as SmartDocumentSuccess).isNameApplied, isTrue);
      },
    );

    test(
      'reanalyze triggers force reload with Loading and Success states',
      () async {
        await cubit.loadOrRecognize(documentId: 'doc_1', pages: const []);

        expectLater(
          cubit.stream,
          emitsInOrder([
            isA<SmartDocumentLoading>(),
            isA<SmartDocumentSuccess>(),
          ]),
        );

        await cubit.reanalyze(documentId: 'doc_1', pages: const []);
      },
    );
  });
}
