import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anuscan/core/database/app_database.dart';
import 'package:anuscan/features/document_history/data/datasources/local_document_datasource.dart';
import 'package:anuscan/features/document_history/data/models/document_dto.dart';
import 'package:anuscan/features/document_history/data/models/folder_dto.dart';
import 'package:anuscan/features/document_history/data/models/tag_dto.dart';
import 'package:anuscan/features/document_history/domain/entities/document_query_filter.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDatabase;
  late LocalDocumentDataSourceImpl dataSource;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    appDatabase = AppDatabase(initialDatabase: db);
    dataSource = LocalDocumentDataSourceImpl(appDatabase);
  });

  tearDown(() async {
    await db.close();
  });

  DocumentDto createDocDto({
    required String id,
    required String title,
    int pageCount = 1,
    int fileSizeBytes = 1000,
    required DateTime createdAt,
    DateTime? updatedAt,
    bool isFavorite = false,
    bool isArchived = false,
    bool isDeleted = false,
    DateTime? deletedAt,
    String? folderId,
    DateTime? lastOpenedAt,
  }) {
    return DocumentDto(
      id: id,
      title: title,
      pdfPath: '/docs/$id.pdf',
      thumbnailPath: '/docs/$id.jpg',
      pageCount: pageCount,
      fileSizeBytes: fileSizeBytes,
      createdAt: createdAt.millisecondsSinceEpoch,
      updatedAt: (updatedAt ?? createdAt).millisecondsSinceEpoch,
      isFavorite: isFavorite,
      isArchived: isArchived,
      isDeleted: isDeleted,
      deletedAt: deletedAt?.millisecondsSinceEpoch,
      folderId: folderId,
      lastOpenedAt: lastOpenedAt?.millisecondsSinceEpoch,
    );
  }

  group('LocalDocumentDataSource - Pagination & Tabs', () {
    test('filters documents by tab criteria correctly', () async {
      final baseTime = DateTime(2026, 1, 1, 12, 0);

      // Normal active document
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: 'doc_active',
          title: 'Active Doc',
          createdAt: baseTime,
        ),
        [],
      );

      // Favorite document
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: 'doc_fav',
          title: 'Favorite Doc',
          isFavorite: true,
          createdAt: baseTime.add(const Duration(minutes: 1)),
        ),
        [],
      );

      // Archived document
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: 'doc_archived',
          title: 'Archived Doc',
          isArchived: true,
          createdAt: baseTime.add(const Duration(minutes: 2)),
        ),
        [],
      );

      // Trash document
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: 'doc_trash',
          title: 'Trash Doc',
          isDeleted: true,
          deletedAt: baseTime.add(const Duration(minutes: 3)),
          createdAt: baseTime.add(const Duration(minutes: 3)),
        ),
        [],
      );

      // 1. All active documents (non-archived, non-deleted)
      final allDocs = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(isArchived: false, isDeleted: false),
      );
      expect(allDocs.length, equals(2));
      expect(
        allDocs.map((d) => d.id).toList(),
        containsAll(['doc_active', 'doc_fav']),
      );

      // 2. Favorites (non-archived, non-deleted)
      final favDocs = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(
          isFavorite: true,
          isArchived: false,
          isDeleted: false,
        ),
      );
      expect(favDocs.length, equals(1));
      expect(favDocs.first.id, equals('doc_fav'));

      // 3. Archived (non-deleted)
      final archDocs = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(isArchived: true, isDeleted: false),
      );
      expect(archDocs.length, equals(1));
      expect(archDocs.first.id, equals('doc_archived'));

      // 4. Trash (deleted)
      final trashDocs = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(isDeleted: true),
      );
      expect(trashDocs.length, equals(1));
      expect(trashDocs.first.id, equals('doc_trash'));
    });

    test('paginates results using limit and offset', () async {
      final baseTime = DateTime(2026, 1, 1, 10, 0);
      for (int i = 0; i < 15; i++) {
        await dataSource.insertOrUpdateDocument(
          createDocDto(
            id: 'doc_$i',
            title: 'Document $i',
            createdAt: baseTime.add(Duration(minutes: i)),
          ),
          [],
        );
      }

      // Page 1: limit 5, offset 0
      final page1 = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(
          limit: 5,
          offset: 0,
          sortOption: DocumentSortOption.oldestFirst,
        ),
      );
      expect(page1.length, equals(5));
      expect(page1.first.id, equals('doc_0'));
      expect(page1.last.id, equals('doc_4'));

      // Page 2: limit 5, offset 5
      final page2 = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(
          limit: 5,
          offset: 5,
          sortOption: DocumentSortOption.oldestFirst,
        ),
      );
      expect(page2.length, equals(5));
      expect(page2.first.id, equals('doc_5'));
      expect(page2.last.id, equals('doc_9'));
    });
  });

  group('LocalDocumentDataSource - Sorting Options', () {
    test('sorts by title alphabetically ascending and descending', () async {
      final now = DateTime.now();
      await dataSource.insertOrUpdateDocument(
        createDocDto(id: '1', title: 'Beta', createdAt: now),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(id: '2', title: 'Alpha', createdAt: now),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(id: '3', title: 'Gamma', createdAt: now),
        [],
      );

      final ascDocs = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(sortOption: DocumentSortOption.nameAscending),
      );
      expect(
        ascDocs.map((d) => d.title).toList(),
        equals(['Alpha', 'Beta', 'Gamma']),
      );

      final descDocs = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(
          sortOption: DocumentSortOption.nameDescending,
        ),
      );
      expect(
        descDocs.map((d) => d.title).toList(),
        equals(['Gamma', 'Beta', 'Alpha']),
      );
    });

    test('sorts by file size and page count', () async {
      final now = DateTime.now();
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: '1',
          title: 'Small',
          fileSizeBytes: 50,
          pageCount: 1,
          createdAt: now,
        ),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: '2',
          title: 'Large',
          fileSizeBytes: 5000,
          pageCount: 10,
          createdAt: now,
        ),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: '3',
          title: 'Medium',
          fileSizeBytes: 500,
          pageCount: 4,
          createdAt: now,
        ),
        [],
      );

      final sizeDocs = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(sortOption: DocumentSortOption.largestFile),
      );
      expect(sizeDocs.map((d) => d.id).toList(), equals(['2', '3', '1']));

      final pageDocs = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(sortOption: DocumentSortOption.mostPages),
      );
      expect(pageDocs.map((d) => d.id).toList(), equals(['2', '3', '1']));
    });
  });

  group('LocalDocumentDataSource - Search Integration', () {
    test('searches across title, ocr text, and smart metadata', () async {
      final now = DateTime.now();
      await dataSource.insertOrUpdateDocument(
        createDocDto(id: 'doc_1', title: 'Tax Invoice 2026', createdAt: now),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(id: 'doc_2', title: 'Meeting Notes', createdAt: now),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(id: 'doc_3', title: 'Generic Scan', createdAt: now),
        [],
      );

      // Add OCR for doc_2
      await db.insert('ocr_page_results', {
        'id': 'ocr_2',
        'document_id': 'doc_2',
        'page_id': 'page_2',
        'page_index': 0,
        'extracted_text': 'Quarterly budget financial review details',
        'status': 'completed',
        'image_path': '/img2.jpg',
        'created_at': 1000,
        'updated_at': 1000,
      });

      // Add recognition metadata for doc_3
      await db.insert('document_recognitions', {
        'id': 'rec_3',
        'document_id': 'doc_3',
        'document_type': 'receipt',
        'classification_source': 'automatic',
        'confidence': 0.95,
        'classifier_version': '1.0.0',
        'company_name': 'Acme Corporation',
        'created_at': 1000,
        'updated_at': 1000,
      });

      // Search by title
      final titleSearch = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(searchQuery: 'Tax Invoice'),
      );
      expect(titleSearch.map((d) => d.id).toList(), equals(['doc_1']));

      // Search by OCR text
      final ocrSearch = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(searchQuery: 'budget financial'),
      );
      expect(ocrSearch.map((d) => d.id).toList(), equals(['doc_2']));

      // Search by company metadata
      final metaSearch = await dataSource.getFilteredDocuments(
        const DocumentQueryFilter(searchQuery: 'Acme'),
      );
      expect(metaSearch.map((d) => d.id).toList(), equals(['doc_3']));
    });
  });

  group('LocalDocumentDataSource - Folder CRUD & Document Counts', () {
    test('manages folders and computes document counts', () async {
      final now = DateTime.now();
      final folder1 = FolderDto(
        id: 'f1',
        name: 'Work',
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );
      final folder2 = FolderDto(
        id: 'f2',
        name: 'Personal',
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );

      await dataSource.insertFolder(folder1);
      await dataSource.insertFolder(folder2);

      var folders = await dataSource.getAllFolders();
      expect(folders.length, equals(2));
      expect(folders.map((f) => f.name), containsAll(['Work', 'Personal']));

      // Add documents
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: 'd1',
          title: 'Work Doc',
          folderId: 'f1',
          createdAt: now,
        ),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: 'd2',
          title: 'Fav Doc',
          isFavorite: true,
          createdAt: now,
        ),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: 'd3',
          title: 'Archived Doc',
          isArchived: true,
          createdAt: now,
        ),
        [],
      );
      await dataSource.insertOrUpdateDocument(
        createDocDto(
          id: 'd4',
          title: 'Trash Doc',
          isDeleted: true,
          deletedAt: now,
          createdAt: now,
        ),
        [],
      );

      final counts = await dataSource.getDocumentCounts();
      expect(counts.activeCount, equals(2)); // d1 and d2
      expect(counts.favoriteCount, equals(1)); // d2
      expect(counts.archivedCount, equals(1)); // d3
      expect(counts.trashCount, equals(1)); // d4
      expect(counts.folderCounts['f1'], equals(1)); // d1

      // Rename folder
      await dataSource.updateFolder(
        FolderDto(
          id: folder1.id,
          name: 'Office',
          createdAt: folder1.createdAt,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      );
      folders = await dataSource.getAllFolders();
      expect(folders.firstWhere((f) => f.id == 'f1').name, equals('Office'));

      // Delete folder should NOT delete documents in it
      await dataSource.deleteFolder('f1');
      folders = await dataSource.getAllFolders();
      expect(folders.length, equals(1));

      final d1 = await dataSource.getDocumentById('d1');
      expect(d1, isNotNull);
      expect(d1!.folderId, isNull);
    });
  });

  group('LocalDocumentDataSource - Tag CRUD & Batch Associations', () {
    test(
      'creates tags, associates with documents, and supports batch querying',
      () async {
        final now = DateTime.now();
        final tag1 = TagDto(
          id: 't1',
          name: 'Invoice',
          colorValue: 0xFF00FF00,
          createdAt: now.millisecondsSinceEpoch,
        );
        final tag2 = TagDto(
          id: 't2',
          name: 'Urgent',
          colorValue: 0xFFFF0000,
          createdAt: now.millisecondsSinceEpoch,
        );

        await dataSource.insertTag(tag1);
        await dataSource.insertTag(tag2);

        final tags = await dataSource.getAllTags();
        expect(tags.length, equals(2));

        await dataSource.insertOrUpdateDocument(
          createDocDto(id: 'doc_a', title: 'Doc A', createdAt: now),
          [],
        );
        await dataSource.insertOrUpdateDocument(
          createDocDto(id: 'doc_b', title: 'Doc B', createdAt: now),
          [],
        );

        await dataSource.assignTag('doc_a', 't1');
        await dataSource.assignTag('doc_a', 't2');
        await dataSource.assignTag('doc_b', 't1');

        final tagsA = await dataSource.getTagsForDocument('doc_a');
        expect(tagsA.length, equals(2));
        expect(tagsA.map((t) => t.name), containsAll(['Invoice', 'Urgent']));

        final batchTags = await dataSource.getTagsForDocuments([
          'doc_a',
          'doc_b',
        ]);
        expect(batchTags['doc_a']?.length, equals(2));
        expect(batchTags['doc_b']?.length, equals(1));

        // Filter by tag
        final filteredByT2 = await dataSource.getFilteredDocuments(
          const DocumentQueryFilter(tagId: 't2'),
        );
        expect(filteredByT2.length, equals(1));
        expect(filteredByT2.first.id, equals('doc_a'));

        // Remove tag
        await dataSource.removeTag('doc_a', 't2');
        final updatedTagsA = await dataSource.getTagsForDocument('doc_a');
        expect(updatedTagsA.length, equals(1));
        expect(updatedTagsA.first.id, equals('t1'));
      },
    );
  });

  group('LocalDocumentDataSource - Bulk Operations', () {
    test(
      'executes bulk moves, archive, favorites, tags, and soft delete',
      () async {
        final now = DateTime.now();
        await dataSource.insertOrUpdateDocument(
          createDocDto(id: 'b1', title: 'Bulk 1', createdAt: now),
          [],
        );
        await dataSource.insertOrUpdateDocument(
          createDocDto(id: 'b2', title: 'Bulk 2', createdAt: now),
          [],
        );

        // Bulk Favorite
        await dataSource.bulkFavorite(['b1', 'b2'], true);
        var b1 = await dataSource.getDocumentById('b1');
        var b2 = await dataSource.getDocumentById('b2');
        expect(b1?.isFavorite, isTrue);
        expect(b2?.isFavorite, isTrue);

        // Bulk Move to Folder
        await dataSource.insertFolder(
          FolderDto(
            id: 'f_bulk',
            name: 'Bulk Folder',
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
        await dataSource.bulkMoveToFolder(['b1', 'b2'], 'f_bulk');
        b1 = await dataSource.getDocumentById('b1');
        b2 = await dataSource.getDocumentById('b2');
        expect(b1?.folderId, equals('f_bulk'));
        expect(b2?.folderId, equals('f_bulk'));

        // Bulk Archive
        await dataSource.bulkArchive(['b1', 'b2'], true);
        b1 = await dataSource.getDocumentById('b1');
        b2 = await dataSource.getDocumentById('b2');
        expect(b1?.isArchived, isTrue);
        expect(b2?.isArchived, isTrue);

        // Bulk Soft Delete
        await dataSource.bulkMoveToTrash(['b1', 'b2']);
        b1 = await dataSource.getDocumentById('b1');
        b2 = await dataSource.getDocumentById('b2');
        expect(b1?.isDeleted, isTrue);
        expect(b1?.deletedAt, isNotNull);
        expect(b2?.isDeleted, isTrue);

        // Bulk Restore
        await dataSource.bulkRestoreFromTrash(['b1', 'b2']);
        b1 = await dataSource.getDocumentById('b1');
        b2 = await dataSource.getDocumentById('b2');
        expect(b1?.isDeleted, isFalse);
        expect(b1?.deletedAt, isNull);

        // Bulk Permanent Delete
        await dataSource.bulkPermanentDelete(['b1', 'b2']);
        b1 = await dataSource.getDocumentById('b1');
        b2 = await dataSource.getDocumentById('b2');
        expect(b1, isNull);
        expect(b2, isNull);
      },
    );
  });
}
