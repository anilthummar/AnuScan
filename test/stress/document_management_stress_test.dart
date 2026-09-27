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

  group(
    'Document Management Scale & Performance Benchmarks (1,000 Documents)',
    () {
      test(
        'populates 1,000 documents and benchmarks queries and operations',
        () async {
          final baseTime = DateTime(2026, 1, 1).millisecondsSinceEpoch;

          // 1. Create 5 Folders
          final folders = List.generate(
            5,
            (i) => FolderDto(
              id: 'folder_$i',
              name: 'Category $i',
              createdAt: baseTime,
              updatedAt: baseTime,
            ),
          );
          for (final f in folders) {
            await dataSource.insertFolder(f);
          }

          // 2. Create 8 Tags
          final tags = List.generate(
            8,
            (i) => TagDto(
              id: 'tag_$i',
              name: 'Tag_$i',
              colorValue: 0xFF000000 | (i * 0x1F1F1F),
              createdAt: baseTime,
            ),
          );
          for (final t in tags) {
            await dataSource.insertTag(t);
          }

          // 3. Populate 1,000 Documents with Batch SQLite Transaction
          final stopwatch = Stopwatch()..start();

          await db.transaction((txn) async {
            final batch = txn.batch();
            for (int i = 0; i < 1000; i++) {
              final isFav = (i % 7 == 0);
              final isArch = (i % 11 == 0);
              final isDel = (i % 23 == 0);
              final folderId = (i % 3 == 0) ? 'folder_${i % 5}' : null;

              final doc = DocumentDto(
                id: 'doc_$i',
                title: 'Invoice Document $i - Corp ${(i % 20)}',
                pdfPath: '/docs/doc_$i.pdf',
                thumbnailPath: '/docs/doc_$i.jpg',
                pageCount: 1 + (i % 10),
                fileSizeBytes: 10240 + (i * 512),
                createdAt: baseTime + (i * 60000),
                updatedAt: baseTime + (i * 60000),
                isFavorite: isFav,
                isArchived: isArch,
                isDeleted: isDel,
                deletedAt: isDel ? baseTime + (i * 60000) : null,
                folderId: folderId,
                lastOpenedAt: (i % 5 == 0) ? baseTime + (i * 60000) : null,
              );

              batch.insert('documents', doc.toMap());

              // Document Tag association (each doc gets 1 or 2 tags)
              final tagId1 = 'tag_${i % 8}';
              batch.insert('document_tags', {
                'document_id': 'doc_$i',
                'tag_id': tagId1,
              });
              if (i % 2 == 0) {
                final tagId2 = 'tag_${(i + 1) % 8}';
                batch.insert('document_tags', {
                  'document_id': 'doc_$i',
                  'tag_id': tagId2,
                });
              }

              // Insert OCR page results for every 5th doc
              if (i % 5 == 0) {
                batch.insert('ocr_page_results', {
                  'id': 'ocr_$i',
                  'document_id': 'doc_$i',
                  'page_id': 'page_$i',
                  'page_index': 0,
                  'extracted_text':
                      'Confidential contract terms and payment conditions for order ref $i',
                  'status': 'completed',
                  'image_path': '/img_$i.jpg',
                  'created_at': baseTime,
                  'updated_at': baseTime,
                });
              }

              // Insert Recognitions for every 4th doc
              if (i % 4 == 0) {
                batch.insert('document_recognitions', {
                  'id': 'rec_$i',
                  'document_id': 'doc_$i',
                  'document_type': (i % 2 == 0) ? 'invoice' : 'receipt',
                  'classification_source': 'automatic',
                  'confidence': 0.92,
                  'classifier_version': '1.0.0',
                  'company_name': 'Alpha Enterprise ${(i % 10)}',
                  'created_at': baseTime,
                  'updated_at': baseTime,
                });
              }
            }
            await batch.commit(noResult: true);
          });

          stopwatch.stop();
          // Insertion of 1,000 documents should be rapid
          expect(stopwatch.elapsedMilliseconds, lessThan(3000));

          // 4. Benchmark: Paginated Document Fetch (50 items)
          // Requirement: Under 50ms
          stopwatch.reset();
          stopwatch.start();
          final page1 = await dataSource.getFilteredDocuments(
            const DocumentQueryFilter(
              limit: 50,
              offset: 0,
              sortOption: DocumentSortOption.newestFirst,
            ),
          );
          stopwatch.stop();
          final pagedQueryMs = stopwatch.elapsedMilliseconds;
          expect(page1.length, equals(50));
          expect(
            pagedQueryMs,
            lessThan(50),
            reason: 'Paginated query must be < 50ms (was ${pagedQueryMs}ms)',
          );

          // 5. Benchmark: Grouped Counts Query (O(1) query)
          // Requirement: Under 20ms
          stopwatch.reset();
          stopwatch.start();
          final counts = await dataSource.getDocumentCounts();
          stopwatch.stop();
          final countsQueryMs = stopwatch.elapsedMilliseconds;
          expect(counts.activeCount, greaterThan(0));
          expect(counts.favoriteCount, greaterThan(0));
          expect(counts.archivedCount, greaterThan(0));
          expect(counts.trashCount, greaterThan(0));
          expect(counts.folderCounts.isNotEmpty, isTrue);
          expect(
            countsQueryMs,
            lessThan(20),
            reason:
                'Grouped counts query must be < 20ms (was ${countsQueryMs}ms)',
          );

          // 6. Benchmark: Batch Tag Query for 50 Documents
          // Requirement: Under 15ms
          final docIds = page1.map((d) => d.id).toList();
          stopwatch.reset();
          stopwatch.start();
          final batchTags = await dataSource.getTagsForDocuments(docIds);
          stopwatch.stop();
          final batchTagsMs = stopwatch.elapsedMilliseconds;
          expect(batchTags.length, equals(50));
          expect(
            batchTagsMs,
            lessThan(15),
            reason: 'Batch tag query must be < 15ms (was ${batchTagsMs}ms)',
          );

          // 7. Benchmark: Search Query across 1,000 Documents
          // Requirement: Under 100ms
          stopwatch.reset();
          stopwatch.start();
          final searchResults = await dataSource.getFilteredDocuments(
            const DocumentQueryFilter(
              searchQuery: 'payment conditions',
              limit: 50,
            ),
          );
          stopwatch.stop();
          final searchMs = stopwatch.elapsedMilliseconds;
          expect(searchResults.isNotEmpty, isTrue);
          expect(
            searchMs,
            lessThan(100),
            reason: 'Search query must be < 100ms (was ${searchMs}ms)',
          );

          // 8. Benchmark: Bulk Action (Move 50 Documents)
          // Requirement: Under 100ms
          stopwatch.reset();
          stopwatch.start();
          await dataSource.bulkMoveToFolder(docIds, 'folder_1');
          stopwatch.stop();
          final bulkActionMs = stopwatch.elapsedMilliseconds;
          expect(
            bulkActionMs,
            lessThan(100),
            reason: 'Bulk action must be < 100ms (was ${bulkActionMs}ms)',
          );

          // Verify the move succeeded
          final movedDoc = await dataSource.getDocumentById(docIds.first);
          expect(movedDoc?.folderId, equals('folder_1'));
        },
      );
    },
  );
}
