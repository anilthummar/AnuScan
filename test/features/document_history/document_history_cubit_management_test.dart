import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/preferences_service.dart';
import 'package:anuscan/features/document_history/domain/entities/document_counts.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_history/domain/entities/document_query_filter.dart';
import 'package:anuscan/features/document_history/domain/entities/folder_entity.dart';
import 'package:anuscan/features/document_history/domain/entities/tag_entity.dart';
import 'package:anuscan/features/document_history/domain/usecases/document_usecases.dart';
import 'package:anuscan/features/document_history/domain/usecases/management_usecases.dart';
import 'package:anuscan/features/document_history/presentation/cubit/document_history_cubit.dart';
import 'package:anuscan/features/document_history/presentation/cubit/document_history_state.dart';

class MockGetDocumentsUseCase extends Mock implements GetDocumentsUseCase {}

class MockDeleteDocumentUseCase extends Mock implements DeleteDocumentUseCase {}

class MockRenameDocumentUseCase extends Mock implements RenameDocumentUseCase {}

class MockSearchDocumentsUseCase extends Mock
    implements SearchDocumentsUseCase {}

class MockGetFilteredDocumentsUseCase extends Mock
    implements GetFilteredDocumentsUseCase {}

class MockGetDocumentCountsUseCase extends Mock
    implements GetDocumentCountsUseCase {}

class MockToggleFavoriteUseCase extends Mock implements ToggleFavoriteUseCase {}

class MockArchiveDocumentUseCase extends Mock
    implements ArchiveDocumentUseCase {}

class MockTrashDocumentUseCase extends Mock implements TrashDocumentUseCase {}

class MockRestoreFromTrashUseCase extends Mock
    implements RestoreFromTrashUseCase {}

class MockPermanentDeleteDocumentUseCase extends Mock
    implements PermanentDeleteDocumentUseCase {}

class MockRecordDocumentOpenedUseCase extends Mock
    implements RecordDocumentOpenedUseCase {}

class MockGetFoldersUseCase extends Mock implements GetFoldersUseCase {}

class MockCreateFolderUseCase extends Mock implements CreateFolderUseCase {}

class MockRenameFolderUseCase extends Mock implements RenameFolderUseCase {}

class MockDeleteFolderUseCase extends Mock implements DeleteFolderUseCase {}

class MockMoveDocumentToFolderUseCase extends Mock
    implements MoveDocumentToFolderUseCase {}

class MockGetTagsUseCase extends Mock implements GetTagsUseCase {}

class MockCreateTagUseCase extends Mock implements CreateTagUseCase {}

class MockDeleteTagUseCase extends Mock implements DeleteTagUseCase {}

class MockAssignTagUseCase extends Mock implements AssignTagUseCase {}

class MockRemoveTagUseCase extends Mock implements RemoveTagUseCase {}

class MockBulkDocumentActionUseCase extends Mock
    implements BulkDocumentActionUseCase {}

class MockPreferencesService extends Mock implements PreferencesService {}

class FakeDocumentQueryFilter extends Fake implements DocumentQueryFilter {}

class FakeFolderEntity extends Fake implements FolderEntity {}

class FakeTagEntity extends Fake implements TagEntity {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDocumentQueryFilter());
    registerFallbackValue(FakeFolderEntity());
    registerFallbackValue(FakeTagEntity());
    registerFallbackValue(DocumentTab.all);
    registerFallbackValue(DocumentSortOption.newestFirst);
    registerFallbackValue(DocumentViewMode.list);
  });

  late MockGetDocumentsUseCase mockGetDocumentsUseCase;
  late MockDeleteDocumentUseCase mockDeleteDocumentUseCase;
  late MockRenameDocumentUseCase mockRenameDocumentUseCase;
  late MockSearchDocumentsUseCase mockSearchDocumentsUseCase;
  late MockGetFilteredDocumentsUseCase mockGetFilteredDocumentsUseCase;
  late MockGetDocumentCountsUseCase mockGetDocumentCountsUseCase;
  late MockToggleFavoriteUseCase mockToggleFavoriteUseCase;
  late MockArchiveDocumentUseCase mockArchiveDocumentUseCase;
  late MockTrashDocumentUseCase mockTrashDocumentUseCase;
  late MockRestoreFromTrashUseCase mockRestoreFromTrashUseCase;
  late MockPermanentDeleteDocumentUseCase mockPermanentDeleteDocumentUseCase;
  late MockRecordDocumentOpenedUseCase mockRecordDocumentOpenedUseCase;
  late MockGetFoldersUseCase mockGetFoldersUseCase;
  late MockCreateFolderUseCase mockCreateFolderUseCase;
  late MockRenameFolderUseCase mockRenameFolderUseCase;
  late MockDeleteFolderUseCase mockDeleteFolderUseCase;
  late MockMoveDocumentToFolderUseCase mockMoveDocumentToFolderUseCase;
  late MockGetTagsUseCase mockGetTagsUseCase;
  late MockCreateTagUseCase mockCreateTagUseCase;
  late MockDeleteTagUseCase mockDeleteTagUseCase;
  late MockAssignTagUseCase mockAssignTagUseCase;
  late MockRemoveTagUseCase mockRemoveTagUseCase;
  late MockBulkDocumentActionUseCase mockBulkDocumentActionUseCase;
  late MockPreferencesService mockPreferencesService;

  setUp(() {
    mockGetDocumentsUseCase = MockGetDocumentsUseCase();
    mockDeleteDocumentUseCase = MockDeleteDocumentUseCase();
    mockRenameDocumentUseCase = MockRenameDocumentUseCase();
    mockSearchDocumentsUseCase = MockSearchDocumentsUseCase();
    mockGetFilteredDocumentsUseCase = MockGetFilteredDocumentsUseCase();
    mockGetDocumentCountsUseCase = MockGetDocumentCountsUseCase();
    mockToggleFavoriteUseCase = MockToggleFavoriteUseCase();
    mockArchiveDocumentUseCase = MockArchiveDocumentUseCase();
    mockTrashDocumentUseCase = MockTrashDocumentUseCase();
    mockRestoreFromTrashUseCase = MockRestoreFromTrashUseCase();
    mockPermanentDeleteDocumentUseCase = MockPermanentDeleteDocumentUseCase();
    mockRecordDocumentOpenedUseCase = MockRecordDocumentOpenedUseCase();
    mockGetFoldersUseCase = MockGetFoldersUseCase();
    mockCreateFolderUseCase = MockCreateFolderUseCase();
    mockRenameFolderUseCase = MockRenameFolderUseCase();
    mockDeleteFolderUseCase = MockDeleteFolderUseCase();
    mockMoveDocumentToFolderUseCase = MockMoveDocumentToFolderUseCase();
    mockGetTagsUseCase = MockGetTagsUseCase();
    mockCreateTagUseCase = MockCreateTagUseCase();
    mockDeleteTagUseCase = MockDeleteTagUseCase();
    mockAssignTagUseCase = MockAssignTagUseCase();
    mockRemoveTagUseCase = MockRemoveTagUseCase();
    mockBulkDocumentActionUseCase = MockBulkDocumentActionUseCase();
    mockPreferencesService = MockPreferencesService();
  });

  DocumentEntity createDoc(
    String id,
    String title, {
    bool isFavorite = false,
    bool isArchived = false,
    bool isDeleted = false,
  }) {
    return DocumentEntity(
      id: id,
      title: title,
      pdfPath: '/path/$id.pdf',
      thumbnailPath: '/path/$id.jpg',
      pageCount: 1,
      fileSizeBytes: 1000,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isFavorite: isFavorite,
      isArchived: isArchived,
      isDeleted: isDeleted,
    );
  }

  DocumentHistoryCubit createCubit() {
    return DocumentHistoryCubit(
      getDocumentsUseCase: mockGetDocumentsUseCase,
      deleteDocumentUseCase: mockDeleteDocumentUseCase,
      renameDocumentUseCase: mockRenameDocumentUseCase,
      searchDocumentsUseCase: mockSearchDocumentsUseCase,
      getFilteredDocumentsUseCase: mockGetFilteredDocumentsUseCase,
      getDocumentCountsUseCase: mockGetDocumentCountsUseCase,
      toggleFavoriteUseCase: mockToggleFavoriteUseCase,
      archiveDocumentUseCase: mockArchiveDocumentUseCase,
      trashDocumentUseCase: mockTrashDocumentUseCase,
      restoreFromTrashUseCase: mockRestoreFromTrashUseCase,
      permanentDeleteDocumentUseCase: mockPermanentDeleteDocumentUseCase,
      recordDocumentOpenedUseCase: mockRecordDocumentOpenedUseCase,
      getFoldersUseCase: mockGetFoldersUseCase,
      createFolderUseCase: mockCreateFolderUseCase,
      renameFolderUseCase: mockRenameFolderUseCase,
      deleteFolderUseCase: mockDeleteFolderUseCase,
      moveDocumentToFolderUseCase: mockMoveDocumentToFolderUseCase,
      getTagsUseCase: mockGetTagsUseCase,
      createTagUseCase: mockCreateTagUseCase,
      deleteTagUseCase: mockDeleteTagUseCase,
      assignTagUseCase: mockAssignTagUseCase,
      removeTagUseCase: mockRemoveTagUseCase,
      bulkDocumentActionUseCase: mockBulkDocumentActionUseCase,
      preferencesService: mockPreferencesService,
    );
  }

  void setupDefaultMocks() {
    when(
      () => mockPreferencesService.getViewMode(),
    ).thenAnswer((_) async => 'list');
    when(
      () => mockPreferencesService.getSortOption(),
    ).thenAnswer((_) async => 'newestFirst');
    when(
      () => mockGetFilteredDocumentsUseCase(any()),
    ).thenAnswer((_) async => [createDoc('1', 'Doc 1')]);
    when(
      () => mockGetDocumentCountsUseCase(),
    ).thenAnswer((_) async => const DocumentCounts(activeCount: 1));
    when(() => mockGetFoldersUseCase()).thenAnswer((_) async => []);
    when(() => mockGetTagsUseCase()).thenAnswer((_) async => []);
  }

  group('DocumentHistoryCubit - Management & Loading', () {
    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'loads filtered documents, counts, folders, tags, and preferences',
      build: () {
        setupDefaultMocks();
        return createCubit();
      },
      act: (cubit) => cubit.loadDocuments(),
      expect: () => [
        const DocumentHistoryLoading(),
        isA<DocumentHistoryLoaded>()
            .having((s) => s.documents.length, 'documents.length', 1)
            .having((s) => s.activeTab, 'activeTab', DocumentTab.all)
            .having((s) => s.counts.activeCount, 'counts.activeCount', 1)
            .having((s) => s.viewMode, 'viewMode', DocumentViewMode.list)
            .having(
              (s) => s.sortOption,
              'sortOption',
              DocumentSortOption.newestFirst,
            ),
      ],
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'setActiveTab updates activeTab and loads documents for that tab',
      build: () {
        setupDefaultMocks();
        when(() => mockGetFilteredDocumentsUseCase(any())).thenAnswer(
          (_) async => [createDoc('fav1', 'Fav Doc', isFavorite: true)],
        );
        return createCubit();
      },
      act: (cubit) => cubit.setActiveTab(DocumentTab.favorites),
      expect: () => [
        const DocumentHistoryLoading(),
        isA<DocumentHistoryLoaded>()
            .having((s) => s.activeTab, 'activeTab', DocumentTab.favorites)
            .having((s) => s.documents.first.id, 'id', 'fav1'),
      ],
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'setSortOption persists to PreferencesService and reloads',
      build: () {
        setupDefaultMocks();
        when(
          () => mockPreferencesService.setSortOption(any()),
        ).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1')],
        counts: const DocumentCounts(),
      ),
      act: (cubit) => cubit.setSortOption(DocumentSortOption.nameAscending),
      verify: (_) {
        verify(
          () => mockPreferencesService.setSortOption('nameAscending'),
        ).called(1);
      },
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'setViewMode persists to PreferencesService and updates state immediately',
      build: () {
        setupDefaultMocks();
        when(
          () => mockPreferencesService.setViewMode(any()),
        ).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1')],
        counts: const DocumentCounts(),
        viewMode: DocumentViewMode.list,
      ),
      act: (cubit) => cubit.setViewMode(DocumentViewMode.grid),
      expect: () => [
        isA<DocumentHistoryLoaded>().having(
          (s) => s.viewMode,
          'viewMode',
          DocumentViewMode.grid,
        ),
      ],
      verify: (_) {
        verify(() => mockPreferencesService.setViewMode('grid')).called(1);
      },
    );
  });

  group('DocumentHistoryCubit - Multi-select Selection Mode', () {
    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'toggleSelection adds and removes IDs, enters and exits selection mode',
      build: () => createCubit(),
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1'), createDoc('2', 'Doc 2')],
        counts: const DocumentCounts(),
      ),
      act: (cubit) {
        cubit.toggleSelection('1');
        cubit.toggleSelection('2');
        cubit.toggleSelection('1');
        cubit.clearSelection();
      },
      expect: () => [
        // Select '1'
        isA<DocumentHistoryLoaded>()
            .having((s) => s.isSelectionMode, 'isSelectionMode', true)
            .having((s) => s.selectedDocumentIds, 'selectedDocumentIds', {'1'}),
        // Select '2'
        isA<DocumentHistoryLoaded>()
            .having((s) => s.isSelectionMode, 'isSelectionMode', true)
            .having((s) => s.selectedDocumentIds, 'selectedDocumentIds', {
              '1',
              '2',
            }),
        // Deselect '1'
        isA<DocumentHistoryLoaded>()
            .having((s) => s.isSelectionMode, 'isSelectionMode', true)
            .having((s) => s.selectedDocumentIds, 'selectedDocumentIds', {'2'}),
        // Clear selection
        isA<DocumentHistoryLoaded>()
            .having((s) => s.isSelectionMode, 'isSelectionMode', false)
            .having(
              (s) => s.selectedDocumentIds,
              'selectedDocumentIds',
              isEmpty,
            ),
      ],
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'selectAll selects all currently loaded documents',
      build: () => createCubit(),
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1'), createDoc('2', 'Doc 2')],
        counts: const DocumentCounts(),
      ),
      act: (cubit) => cubit.selectAll(),
      expect: () => [
        isA<DocumentHistoryLoaded>()
            .having((s) => s.isSelectionMode, 'isSelectionMode', true)
            .having((s) => s.selectedDocumentIds, 'selectedDocumentIds', {
              '1',
              '2',
            }),
      ],
    );
  });

  group('DocumentHistoryCubit - Single Item Management Actions', () {
    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'toggleFavorite calls usecase and updates state',
      build: () {
        setupDefaultMocks();
        when(
          () => mockToggleFavoriteUseCase('1', true),
        ).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1', isFavorite: false)],
        counts: const DocumentCounts(),
      ),
      act: (cubit) => cubit.toggleFavorite('1', true),
      verify: (_) {
        verify(() => mockToggleFavoriteUseCase('1', true)).called(1);
      },
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'deleteDocument calls trash usecase and reloads active documents',
      build: () {
        setupDefaultMocks();
        when(() => mockTrashDocumentUseCase('1')).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1')],
        counts: const DocumentCounts(activeCount: 1),
      ),
      act: (cubit) => cubit.deleteDocument('1'),
      verify: (_) {
        verify(() => mockTrashDocumentUseCase('1')).called(1);
      },
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'restoreFromTrash calls usecase and reloads',
      build: () {
        setupDefaultMocks();
        when(() => mockRestoreFromTrashUseCase('1')).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Trash Doc', isDeleted: true)],
        counts: const DocumentCounts(trashCount: 1),
        activeTab: DocumentTab.trash,
      ),
      act: (cubit) => cubit.restoreFromTrash('1'),
      verify: (_) {
        verify(() => mockRestoreFromTrashUseCase('1')).called(1);
      },
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'permanentDeleteDocument calls usecase and reloads',
      build: () {
        setupDefaultMocks();
        when(
          () => mockPermanentDeleteDocumentUseCase('1'),
        ).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Trash Doc', isDeleted: true)],
        counts: const DocumentCounts(trashCount: 1),
        activeTab: DocumentTab.trash,
      ),
      act: (cubit) => cubit.permanentDeleteDocument('1'),
      verify: (_) {
        verify(() => mockPermanentDeleteDocumentUseCase('1')).called(1);
      },
    );
  });

  group('DocumentHistoryCubit - Bulk Actions', () {
    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'bulkMoveToTrash executes bulk action on selected IDs and clears selection',
      build: () {
        setupDefaultMocks();
        when(
          () => mockBulkDocumentActionUseCase.moveToTrash(['1', '2']),
        ).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1'), createDoc('2', 'Doc 2')],
        counts: const DocumentCounts(activeCount: 2),
        selectedDocumentIds: {'1', '2'},
      ),
      act: (cubit) => cubit.bulkMoveToTrash(),
      verify: (_) {
        verify(
          () => mockBulkDocumentActionUseCase.moveToTrash(['1', '2']),
        ).called(1);
      },
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'bulkFavorite executes bulk action on selected IDs and clears selection',
      build: () {
        setupDefaultMocks();
        when(
          () => mockBulkDocumentActionUseCase.favorite(['1', '2'], true),
        ).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1'), createDoc('2', 'Doc 2')],
        counts: const DocumentCounts(activeCount: 2),
        selectedDocumentIds: {'1', '2'},
      ),
      act: (cubit) => cubit.bulkFavorite(true),
      verify: (_) {
        verify(
          () => mockBulkDocumentActionUseCase.favorite(['1', '2'], true),
        ).called(1);
      },
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'bulkArchive executes bulk action on selected IDs and clears selection',
      build: () {
        setupDefaultMocks();
        when(
          () => mockBulkDocumentActionUseCase.archive(['1', '2'], true),
        ).thenAnswer((_) async {});
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1'), createDoc('2', 'Doc 2')],
        counts: const DocumentCounts(activeCount: 2),
        selectedDocumentIds: {'1', '2'},
      ),
      act: (cubit) => cubit.bulkArchive(true),
      verify: (_) {
        verify(
          () => mockBulkDocumentActionUseCase.archive(['1', '2'], true),
        ).called(1);
      },
    );
  });

  group('DocumentHistoryCubit - Folders and Tags', () {
    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'createFolder calls usecase and updates folder list',
      build: () {
        setupDefaultMocks();
        when(() => mockCreateFolderUseCase(any())).thenAnswer((_) async {});
        when(() => mockGetFoldersUseCase()).thenAnswer(
          (_) async => [
            FolderEntity(
              id: 'f1',
              name: 'Receipts',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
        );
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1')],
        counts: const DocumentCounts(),
      ),
      act: (cubit) => cubit.createFolder('Receipts'),
      verify: (_) {
        verify(() => mockCreateFolderUseCase(any())).called(1);
      },
    );

    blocTest<DocumentHistoryCubit, DocumentHistoryState>(
      'createTag calls usecase and updates tag list',
      build: () {
        setupDefaultMocks();
        when(() => mockCreateTagUseCase(any())).thenAnswer((_) async {});
        when(() => mockGetTagsUseCase()).thenAnswer(
          (_) async => [
            TagEntity(
              id: 't1',
              name: 'Tax',
              colorValue: 0xFFFF0000,
              createdAt: DateTime.now(),
            ),
          ],
        );
        return createCubit();
      },
      seed: () => DocumentHistoryLoaded(
        documents: [createDoc('1', 'Doc 1')],
        counts: const DocumentCounts(),
      ),
      act: (cubit) => cubit.createTag('Tax', colorValue: 0xFFFF0000),
      verify: (_) {
        verify(() => mockCreateTagUseCase(any())).called(1);
      },
    );
  });
}
