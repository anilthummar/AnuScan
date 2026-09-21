import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_history/domain/usecases/document_usecases.dart';
import 'package:anuscan/features/document_history/presentation/cubit/document_history_cubit.dart';
import 'package:anuscan/features/document_history/presentation/cubit/document_history_state.dart';

class MockGetDocumentsUseCase extends Mock implements GetDocumentsUseCase {}
class MockDeleteDocumentUseCase extends Mock implements DeleteDocumentUseCase {}
class MockRenameDocumentUseCase extends Mock implements RenameDocumentUseCase {}
class MockSearchDocumentsUseCase extends Mock implements SearchDocumentsUseCase {}

void main() {
  late MockGetDocumentsUseCase mockGetDocumentsUseCase;
  late MockDeleteDocumentUseCase mockDeleteDocumentUseCase;
  late MockRenameDocumentUseCase mockRenameDocumentUseCase;
  late MockSearchDocumentsUseCase mockSearchDocumentsUseCase;

  setUp(() {
    mockGetDocumentsUseCase = MockGetDocumentsUseCase();
    mockDeleteDocumentUseCase = MockDeleteDocumentUseCase();
    mockRenameDocumentUseCase = MockRenameDocumentUseCase();
    mockSearchDocumentsUseCase = MockSearchDocumentsUseCase();
  });

  DocumentEntity createDoc(String id, String title) {
    return DocumentEntity(
      id: id,
      title: title,
      pdfPath: '/path/$id.pdf',
      pageCount: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  blocTest<DocumentHistoryCubit, DocumentHistoryState>(
    'emits [DocumentHistoryLoading, DocumentHistoryLoaded] when loadDocuments is successful',
    build: () {
      when(() => mockGetDocumentsUseCase()).thenAnswer((_) async => [
            createDoc('d1', 'Doc 1'),
          ]);
      return DocumentHistoryCubit(
        getDocumentsUseCase: mockGetDocumentsUseCase,
        deleteDocumentUseCase: mockDeleteDocumentUseCase,
        renameDocumentUseCase: mockRenameDocumentUseCase,
        searchDocumentsUseCase: mockSearchDocumentsUseCase,
      );
    },
    act: (cubit) => cubit.loadDocuments(),
    expect: () => [
      const DocumentHistoryLoading(),
      isA<DocumentHistoryLoaded>().having((s) => s.documents.length, 'length', 1),
    ],
  );

  blocTest<DocumentHistoryCubit, DocumentHistoryState>(
    'emits [DocumentHistoryLoading, DocumentHistoryLoaded] when searchDocuments matches query',
    build: () {
      when(() => mockSearchDocumentsUseCase('Report')).thenAnswer((_) async => [
            createDoc('d1', 'Financial Report'),
          ]);
      return DocumentHistoryCubit(
        getDocumentsUseCase: mockGetDocumentsUseCase,
        deleteDocumentUseCase: mockDeleteDocumentUseCase,
        renameDocumentUseCase: mockRenameDocumentUseCase,
        searchDocumentsUseCase: mockSearchDocumentsUseCase,
      );
    },
    act: (cubit) => cubit.searchDocuments('Report'),
    expect: () => [
      const DocumentHistoryLoading(),
      isA<DocumentHistoryLoaded>()
          .having((s) => s.documents.length, 'length', 1)
          .having((s) => s.searchQuery, 'searchQuery', 'Report'),
    ],
  );
}
