import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/features/document_history/domain/entities/document_counts.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_history/domain/entities/document_query_filter.dart';
import 'package:anuscan/features/document_history/domain/entities/folder_entity.dart';
import 'package:anuscan/features/document_history/domain/entities/tag_entity.dart';
import 'package:anuscan/features/document_history/domain/repositories/document_repository.dart';
import 'package:anuscan/features/document_history/domain/usecases/management_usecases.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late MockDocumentRepository repository;

  setUp(() {
    repository = MockDocumentRepository();
  });

  group('Document Management Use Cases', () {
    test(
      'GetFilteredDocumentsUseCase calls repository.getFilteredDocuments',
      () async {
        final useCase = GetFilteredDocumentsUseCase(repository);
        const filter = DocumentQueryFilter(searchQuery: 'test');
        final expectedDocs = [
          DocumentEntity(
            id: '1',
            title: 'Test',
            pdfPath: '/p.pdf',
            pageCount: 1,
            fileSizeBytes: 100,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(
          () => repository.getFilteredDocuments(filter),
        ).thenAnswer((_) async => expectedDocs);

        final result = await useCase(filter);

        expect(result, equals(expectedDocs));
        verify(() => repository.getFilteredDocuments(filter)).called(1);
      },
    );

    test(
      'GetDocumentCountsUseCase calls repository.getDocumentCounts',
      () async {
        final useCase = GetDocumentCountsUseCase(repository);
        const expectedCounts = DocumentCounts(
          activeCount: 10,
          favoriteCount: 2,
        );

        when(
          () => repository.getDocumentCounts(),
        ).thenAnswer((_) async => expectedCounts);

        final result = await useCase();

        expect(result, equals(expectedCounts));
        verify(() => repository.getDocumentCounts()).called(1);
      },
    );

    test('ToggleFavoriteUseCase calls repository.toggleFavorite', () async {
      final useCase = ToggleFavoriteUseCase(repository);

      when(
        () => repository.toggleFavorite('doc_1', true),
      ).thenAnswer((_) async {});

      await useCase('doc_1', true);

      verify(() => repository.toggleFavorite('doc_1', true)).called(1);
    });

    test('ArchiveDocumentUseCase calls repository.setArchived', () async {
      final useCase = ArchiveDocumentUseCase(repository);

      when(
        () => repository.setArchived('doc_1', true),
      ).thenAnswer((_) async {});

      await useCase('doc_1', true);

      verify(() => repository.setArchived('doc_1', true)).called(1);
    });

    test('TrashDocumentUseCase calls repository.moveToTrash', () async {
      final useCase = TrashDocumentUseCase(repository);

      when(() => repository.moveToTrash('doc_1')).thenAnswer((_) async {});

      await useCase('doc_1');

      verify(() => repository.moveToTrash('doc_1')).called(1);
    });

    test('RestoreFromTrashUseCase calls repository.restoreFromTrash', () async {
      final useCase = RestoreFromTrashUseCase(repository);

      when(() => repository.restoreFromTrash('doc_1')).thenAnswer((_) async {});

      await useCase('doc_1');

      verify(() => repository.restoreFromTrash('doc_1')).called(1);
    });

    test(
      'PermanentDeleteDocumentUseCase calls repository.permanentDeleteDocument',
      () async {
        final useCase = PermanentDeleteDocumentUseCase(repository);

        when(
          () => repository.permanentDeleteDocument('doc_1'),
        ).thenAnswer((_) async {});

        await useCase('doc_1');

        verify(() => repository.permanentDeleteDocument('doc_1')).called(1);
      },
    );

    test(
      'RecordDocumentOpenedUseCase calls repository.recordDocumentOpened',
      () async {
        final useCase = RecordDocumentOpenedUseCase(repository);

        when(
          () => repository.recordDocumentOpened('doc_1'),
        ).thenAnswer((_) async {});

        await useCase('doc_1');

        verify(() => repository.recordDocumentOpened('doc_1')).called(1);
      },
    );
  });

  group('Folder Use Cases', () {
    test('GetFoldersUseCase calls repository.getFolders', () async {
      final useCase = GetFoldersUseCase(repository);
      final folders = [
        FolderEntity(
          id: 'f1',
          name: 'Work',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(() => repository.getFolders()).thenAnswer((_) async => folders);

      final result = await useCase();

      expect(result, equals(folders));
      verify(() => repository.getFolders()).called(1);
    });

    test('CreateFolderUseCase calls repository.createFolder', () async {
      final useCase = CreateFolderUseCase(repository);
      final folder = FolderEntity(
        id: 'f1',
        name: 'Work',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => repository.createFolder(folder)).thenAnswer((_) async {});

      await useCase(folder);

      verify(() => repository.createFolder(folder)).called(1);
    });

    test('RenameFolderUseCase calls repository.updateFolder', () async {
      final useCase = RenameFolderUseCase(repository);
      final folder = FolderEntity(
        id: 'f1',
        name: 'Work Renamed',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => repository.updateFolder(folder)).thenAnswer((_) async {});

      await useCase(folder);

      verify(() => repository.updateFolder(folder)).called(1);
    });

    test('DeleteFolderUseCase calls repository.deleteFolder', () async {
      final useCase = DeleteFolderUseCase(repository);

      when(() => repository.deleteFolder('f1')).thenAnswer((_) async {});

      await useCase('f1');

      verify(() => repository.deleteFolder('f1')).called(1);
    });

    test(
      'MoveDocumentToFolderUseCase calls repository.moveDocumentToFolder',
      () async {
        final useCase = MoveDocumentToFolderUseCase(repository);

        when(
          () => repository.moveDocumentToFolder('doc_1', 'f1'),
        ).thenAnswer((_) async {});

        await useCase('doc_1', 'f1');

        verify(() => repository.moveDocumentToFolder('doc_1', 'f1')).called(1);
      },
    );
  });

  group('Tag Use Cases', () {
    test('GetTagsUseCase calls repository.getTags', () async {
      final useCase = GetTagsUseCase(repository);
      final tags = [
        TagEntity(
          id: 't1',
          name: 'Tax',
          colorValue: 0xFFFF0000,
          createdAt: DateTime.now(),
        ),
      ];

      when(() => repository.getTags()).thenAnswer((_) async => tags);

      final result = await useCase();

      expect(result, equals(tags));
      verify(() => repository.getTags()).called(1);
    });

    test('CreateTagUseCase calls repository.createTag', () async {
      final useCase = CreateTagUseCase(repository);
      final tag = TagEntity(
        id: 't1',
        name: 'Tax',
        colorValue: 0xFFFF0000,
        createdAt: DateTime.now(),
      );

      when(() => repository.createTag(tag)).thenAnswer((_) async {});

      await useCase(tag);

      verify(() => repository.createTag(tag)).called(1);
    });

    test('RenameTagUseCase calls repository.updateTag', () async {
      final useCase = RenameTagUseCase(repository);
      final tag = TagEntity(
        id: 't1',
        name: 'Taxes',
        colorValue: 0xFFFF0000,
        createdAt: DateTime.now(),
      );

      when(() => repository.updateTag(tag)).thenAnswer((_) async {});

      await useCase(tag);

      verify(() => repository.updateTag(tag)).called(1);
    });

    test('DeleteTagUseCase calls repository.deleteTag', () async {
      final useCase = DeleteTagUseCase(repository);

      when(() => repository.deleteTag('t1')).thenAnswer((_) async {});

      await useCase('t1');

      verify(() => repository.deleteTag('t1')).called(1);
    });

    test('AssignTagUseCase calls repository.assignTag', () async {
      final useCase = AssignTagUseCase(repository);

      when(() => repository.assignTag('doc_1', 't1')).thenAnswer((_) async {});

      await useCase('doc_1', 't1');

      verify(() => repository.assignTag('doc_1', 't1')).called(1);
    });

    test('RemoveTagUseCase calls repository.removeTag', () async {
      final useCase = RemoveTagUseCase(repository);

      when(() => repository.removeTag('doc_1', 't1')).thenAnswer((_) async {});

      await useCase('doc_1', 't1');

      verify(() => repository.removeTag('doc_1', 't1')).called(1);
    });
  });

  group('Bulk Actions Use Case', () {
    test(
      'BulkDocumentActionUseCase delegates all actions to repository',
      () async {
        final useCase = BulkDocumentActionUseCase(repository);
        final ids = ['1', '2'];

        when(() => repository.bulkArchive(ids, true)).thenAnswer((_) async {});
        when(() => repository.bulkFavorite(ids, true)).thenAnswer((_) async {});
        when(() => repository.bulkMoveToTrash(ids)).thenAnswer((_) async {});
        when(
          () => repository.bulkRestoreFromTrash(ids),
        ).thenAnswer((_) async {});
        when(
          () => repository.bulkMoveToFolder(ids, 'f1'),
        ).thenAnswer((_) async {});
        when(
          () => repository.bulkAssignTag(ids, 't1'),
        ).thenAnswer((_) async {});
        when(
          () => repository.bulkRemoveTag(ids, 't1'),
        ).thenAnswer((_) async {});
        when(
          () => repository.bulkPermanentDelete(ids),
        ).thenAnswer((_) async {});

        await useCase.archive(ids, true);
        await useCase.favorite(ids, true);
        await useCase.moveToTrash(ids);
        await useCase.restoreFromTrash(ids);
        await useCase.moveToFolder(ids, 'f1');
        await useCase.assignTag(ids, 't1');
        await useCase.removeTag(ids, 't1');
        await useCase.permanentDelete(ids);

        verify(() => repository.bulkArchive(ids, true)).called(1);
        verify(() => repository.bulkFavorite(ids, true)).called(1);
        verify(() => repository.bulkMoveToTrash(ids)).called(1);
        verify(() => repository.bulkRestoreFromTrash(ids)).called(1);
        verify(() => repository.bulkMoveToFolder(ids, 'f1')).called(1);
        verify(() => repository.bulkAssignTag(ids, 't1')).called(1);
        verify(() => repository.bulkRemoveTag(ids, 't1')).called(1);
        verify(() => repository.bulkPermanentDelete(ids)).called(1);
      },
    );
  });
}
