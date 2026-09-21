import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/document_usecases.dart';
import 'document_history_state.dart';

class DocumentHistoryCubit extends Cubit<DocumentHistoryState> {
  DocumentHistoryCubit({
    required this.getDocumentsUseCase,
    required this.deleteDocumentUseCase,
    required this.renameDocumentUseCase,
    required this.searchDocumentsUseCase,
  }) : super(const DocumentHistoryInitial());

  final GetDocumentsUseCase getDocumentsUseCase;
  final DeleteDocumentUseCase deleteDocumentUseCase;
  final RenameDocumentUseCase renameDocumentUseCase;
  final SearchDocumentsUseCase searchDocumentsUseCase;

  Future<void> loadDocuments() async {
    emit(const DocumentHistoryLoading());
    try {
      final documents = await getDocumentsUseCase();
      emit(DocumentHistoryLoaded(documents: documents));
    } catch (e) {
      emit(DocumentHistoryError('Failed to load documents: $e'));
    }
  }

  Future<void> searchDocuments(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await loadDocuments();
      return;
    }

    emit(const DocumentHistoryLoading());
    try {
      final results = await searchDocumentsUseCase(trimmed);
      emit(DocumentHistoryLoaded(documents: results, searchQuery: trimmed));
    } catch (e) {
      emit(DocumentHistoryError('Failed to search documents: $e'));
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await deleteDocumentUseCase(id);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to delete document: $e'));
    }
  }

  Future<void> renameDocument(String id, String newTitle) async {
    try {
      await renameDocumentUseCase(id, newTitle);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to rename document: $e'));
    }
  }
}
