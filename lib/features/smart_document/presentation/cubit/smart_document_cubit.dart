import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../domain/entities/document_classification.dart';
import '../../domain/entities/document_metadata.dart';
import '../../domain/usecases/smart_document_usecases.dart';
import 'smart_document_state.dart';

class SmartDocumentCubit extends Cubit<SmartDocumentState> {
  SmartDocumentCubit({
    required this.recognizeDocumentUseCase,
    required this.getDocumentRecognitionUseCase,
    required this.overrideDocumentTypeUseCase,
    required this.updateDocumentMetadataUseCase,
    required this.suggestDocumentNameUseCase,
  }) : super(const SmartDocumentInitial());

  final RecognizeDocumentUseCase recognizeDocumentUseCase;
  final GetDocumentRecognitionUseCase getDocumentRecognitionUseCase;
  final OverrideDocumentTypeUseCase overrideDocumentTypeUseCase;
  final UpdateDocumentMetadataUseCase updateDocumentMetadataUseCase;
  final SuggestDocumentNameUseCase suggestDocumentNameUseCase;

  Future<void> loadOrRecognize({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) async {
    emit(const SmartDocumentLoading());

    final result = await recognizeDocumentUseCase(
      documentId: documentId,
      pages: pages,
      force: force,
    );

    result.fold(
      onFailure: (failure) {
        emit(SmartDocumentFailure(message: failure.message));
      },
      onSuccess: (data) {
        emit(SmartDocumentSuccess(result: data));
      },
    );
  }

  Future<void> overrideDocumentType(DocumentType manualType) async {
    final current = state;
    if (current is! SmartDocumentSuccess) return;

    final documentId = current.result.documentId;
    final result = await overrideDocumentTypeUseCase(
      documentId: documentId,
      manualType: manualType,
    );

    if (result.isSuccess) {
      final refreshed = await getDocumentRecognitionUseCase(documentId);
      final updated = refreshed.dataOrNull;
      if (updated != null && !isClosed) {
        emit(current.copyWith(result: updated));
      }
    }
  }

  Future<void> updateMetadata(DocumentMetadata updated) async {
    final current = state;
    if (current is! SmartDocumentSuccess) return;

    final documentId = current.result.documentId;
    final result = await updateDocumentMetadataUseCase(
      documentId: documentId,
      updatedMetadata: updated,
    );

    if (result.isSuccess) {
      final refreshed = await getDocumentRecognitionUseCase(documentId);
      final updatedResult = refreshed.dataOrNull;
      if (updatedResult != null && !isClosed) {
        emit(current.copyWith(result: updatedResult));
      }
    }
  }

  void markNameApplied() {
    final current = state;
    if (current is SmartDocumentSuccess) {
      emit(current.copyWith(isNameApplied: true));
    }
  }

  Future<void> reanalyze({
    required String documentId,
    required List<ScannedPage> pages,
  }) async {
    await loadOrRecognize(documentId: documentId, pages: pages, force: true);
  }
}
