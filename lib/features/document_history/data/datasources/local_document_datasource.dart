import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/document_counts.dart';
import '../../domain/entities/document_query_filter.dart';
import '../models/document_dto.dart';
import '../models/folder_dto.dart';
import '../models/tag_dto.dart';

abstract class LocalDocumentDataSource {
  Future<List<DocumentDto>> getAllDocuments();
  Future<DocumentDto?> getDocumentById(String id);
  Future<List<DocumentPageDto>> getPagesForDocument(String documentId);
  Future<void> insertOrUpdateDocument(
    DocumentDto document,
    List<DocumentPageDto> pages,
  );
  Future<void> deleteDocument(String id);
  Future<void> updateDocumentTitle(
    String id,
    String newTitle,
    String newPdfPath,
  );
  Future<List<DocumentDto>> searchDocuments(String query);

  // Phase 13 Extensions
  Future<List<DocumentDto>> getFilteredDocuments(DocumentQueryFilter filter);
  Future<DocumentCounts> getDocumentCounts();
  Future<void> toggleFavorite(String id, bool isFavorite);
  Future<void> togglePrivate(String id, bool isPrivate);
  Future<void> setArchived(String id, bool isArchived);
  Future<void> moveToTrash(String id);
  Future<void> restoreFromTrash(String id);
  Future<void> permanentDeleteDocument(String id);
  Future<void> recordDocumentOpened(String id);

  // Folders
  Future<List<FolderDto>> getAllFolders();
  Future<FolderDto?> getFolderById(String id);
  Future<void> insertFolder(FolderDto folder);
  Future<void> updateFolder(FolderDto folder);
  Future<void> deleteFolder(String id);
  Future<void> moveDocumentToFolder(String documentId, String? folderId);

  // Tags
  Future<List<TagDto>> getAllTags();
  Future<TagDto?> getTagById(String id);
  Future<void> insertTag(TagDto tag);
  Future<void> updateTag(TagDto tag);
  Future<void> deleteTag(String id);
  Future<void> assignTag(String documentId, String tagId);
  Future<void> removeTag(String documentId, String tagId);
  Future<List<TagDto>> getTagsForDocument(String documentId);
  Future<Map<String, List<TagDto>>> getTagsForDocuments(
    List<String> documentIds,
  );

  // Bulk Operations
  Future<void> bulkArchive(List<String> ids, bool isArchived);
  Future<void> bulkFavorite(List<String> ids, bool isFavorite);
  Future<void> bulkSetPrivate(List<String> ids, bool isPrivate);
  Future<void> bulkMoveToTrash(List<String> ids);
  Future<void> bulkRestoreFromTrash(List<String> ids);
  Future<void> bulkMoveToFolder(List<String> ids, String? folderId);
  Future<void> bulkAssignTag(List<String> ids, String tagId);
  Future<void> bulkRemoveTag(List<String> ids, String tagId);
  Future<void> bulkPermanentDelete(List<String> ids);
}

class LocalDocumentDataSourceImpl implements LocalDocumentDataSource {
  const LocalDocumentDataSourceImpl(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<DocumentDto>> getAllDocuments() async {
    return getFilteredDocuments(const DocumentQueryFilter(limit: 500));
  }

  @override
  Future<DocumentDto?> getDocumentById(String id) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.rawQuery(
        '''
        SELECT d.*, f.name AS folder_name
        FROM documents d
        LEFT JOIN folders f ON d.folder_id = f.id
        WHERE d.id = ?
        LIMIT 1
      ''',
        [id],
      );
      if (results.isEmpty) return null;

      final tags = await getTagsForDocument(id);
      return DocumentDto.fromMap(results.first, tags: tags);
    } catch (e) {
      throw AppDatabaseException('Failed to query document by id: $e', e);
    }
  }

  @override
  Future<List<DocumentPageDto>> getPagesForDocument(String documentId) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.query(
        'document_pages',
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'page_index ASC',
      );
      return results.map((m) => DocumentPageDto.fromMap(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to query document pages: $e', e);
    }
  }

  @override
  Future<void> insertOrUpdateDocument(
    DocumentDto document,
    List<DocumentPageDto> pages,
  ) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        await txn.insert(
          'documents',
          document.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Delete old pages and re-insert updated page ordering
        await txn.delete(
          'document_pages',
          where: 'document_id = ?',
          whereArgs: [document.id],
        );

        for (final page in pages) {
          await txn.insert(
            'document_pages',
            page.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw AppDatabaseException('Failed to save document: $e', e);
    }
  }

  @override
  Future<void> deleteDocument(String id) async {
    // Legacy soft-delete/remove contract: delegating to moveToTrash for safety
    await moveToTrash(id);
  }

  @override
  Future<void> permanentDeleteDocument(String id) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        await txn.delete(
          'document_pages',
          where: 'document_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'document_tags',
          where: 'document_id = ?',
          whereArgs: [id],
        );
        await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw AppDatabaseException(
        'Failed to permanently delete document: $e',
        e,
      );
    }
  }

  @override
  Future<void> updateDocumentTitle(
    String id,
    String newTitle,
    String newPdfPath,
  ) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {
          'title': newTitle,
          'pdf_path': newPdfPath,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to rename document: $e', e);
    }
  }

  @override
  Future<List<DocumentDto>> searchDocuments(String query) async {
    return getFilteredDocuments(
      DocumentQueryFilter(searchQuery: query, limit: 100),
    );
  }

  @override
  Future<List<DocumentDto>> getFilteredDocuments(
    DocumentQueryFilter filter,
  ) async {
    try {
      final db = await _appDatabase.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      // Status filters
      if (filter.isDeleted) {
        whereClauses.add('d.is_deleted = 1');
      } else if (filter.isArchived) {
        whereClauses.add('d.is_archived = 1 AND d.is_deleted = 0');
      } else {
        whereClauses.add('d.is_archived = 0 AND d.is_deleted = 0');
      }

      if (filter.isFavorite == true) {
        whereClauses.add('d.is_favorite = 1');
      }

      if (filter.isPrivate != null) {
        whereClauses.add('d.is_private = ?');
        whereArgs.add(filter.isPrivate! ? 1 : 0);
      }

      // Folder filter
      if (filter.folderId != null) {
        if (filter.folderId == 'none') {
          whereClauses.add('d.folder_id IS NULL');
        } else {
          whereClauses.add('d.folder_id = ?');
          whereArgs.add(filter.folderId);
        }
      }

      // Tag filter
      if (filter.tagId != null) {
        whereClauses.add(
          'EXISTS (SELECT 1 FROM document_tags dt_sub WHERE dt_sub.document_id = d.id AND dt_sub.tag_id = ?)',
        );
        whereArgs.add(filter.tagId);
      }

      // Document type filter (from Phase 12 recognitions)
      if (filter.documentType != null &&
          filter.documentType != 'All' &&
          filter.documentType!.isNotEmpty) {
        whereClauses.add('r.document_type = ?');
        whereArgs.add(filter.documentType);
      }

      // Search query across title, OCR text, document type, company name, person name, doc number, and tag name
      if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
        final q = '%${filter.searchQuery!.trim()}%';
        whereClauses.add('''
          (d.title LIKE ?
           OR o.extracted_text LIKE ?
           OR r.document_type LIKE ?
           OR r.company_name LIKE ?
           OR r.person_name LIKE ?
           OR r.document_number LIKE ?
           OR EXISTS (
                SELECT 1 FROM document_tags dt_search
                JOIN tags t_search ON dt_search.tag_id = t_search.id
                WHERE dt_search.document_id = d.id AND t_search.name LIKE ?
              )
          )
        ''');
        whereArgs.addAll([q, q, q, q, q, q, q]);
      }

      final whereSql = whereClauses.isNotEmpty
          ? 'WHERE ${whereClauses.join(' AND ')}'
          : '';

      // Sorting
      String orderBySql;
      switch (filter.sortOption) {
        case DocumentSortOption.newestFirst:
          orderBySql = 'd.created_at DESC';
          break;
        case DocumentSortOption.oldestFirst:
          orderBySql = 'd.created_at ASC';
          break;
        case DocumentSortOption.recentlyUpdated:
          orderBySql = 'd.updated_at DESC';
          break;
        case DocumentSortOption.nameAscending:
          orderBySql = 'd.title COLLATE NOCASE ASC';
          break;
        case DocumentSortOption.nameDescending:
          orderBySql = 'd.title COLLATE NOCASE DESC';
          break;
        case DocumentSortOption.largestFile:
          orderBySql = 'd.file_size_bytes DESC';
          break;
        case DocumentSortOption.smallestFile:
          orderBySql = 'd.file_size_bytes ASC';
          break;
        case DocumentSortOption.mostPages:
          orderBySql = 'd.page_count DESC';
          break;
        case DocumentSortOption.leastPages:
          orderBySql = 'd.page_count ASC';
          break;
        case DocumentSortOption.lastOpened:
          orderBySql = 'COALESCE(d.last_opened_at, 0) DESC, d.updated_at DESC';
          break;
      }

      final querySql =
          '''
        SELECT DISTINCT d.*, f.name AS folder_name
        FROM documents d
        LEFT JOIN folders f ON d.folder_id = f.id
        LEFT JOIN ocr_page_results o ON d.id = o.document_id
        LEFT JOIN document_recognitions r ON d.id = r.document_id
        $whereSql
        ORDER BY $orderBySql
        LIMIT ? OFFSET ?
      ''';

      whereArgs.add(filter.limit);
      whereArgs.add(filter.offset);

      final results = await db.rawQuery(querySql, whereArgs);
      if (results.isEmpty) return [];

      final documentIds = results.map((m) => m['id'] as String).toList();
      final tagMap = await getTagsForDocuments(documentIds);

      return results.map((m) {
        final docId = m['id'] as String;
        return DocumentDto.fromMap(m, tags: tagMap[docId] ?? const []);
      }).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to query filtered documents: $e', e);
    }
  }

  @override
  Future<DocumentCounts> getDocumentCounts() async {
    try {
      final db = await _appDatabase.database;

      final futures = await Future.wait([
        // 0: Active count
        db.rawQuery(
          'SELECT COUNT(*) as cnt FROM documents WHERE is_archived = 0 AND is_deleted = 0',
        ),
        // 1: Favorite count
        db.rawQuery(
          'SELECT COUNT(*) as cnt FROM documents WHERE is_favorite = 1 AND is_archived = 0 AND is_deleted = 0',
        ),
        // 2: Archived count
        db.rawQuery(
          'SELECT COUNT(*) as cnt FROM documents WHERE is_archived = 1 AND is_deleted = 0',
        ),
        // 3: Trash count
        db.rawQuery(
          'SELECT COUNT(*) as cnt FROM documents WHERE is_deleted = 1',
        ),
        // 4: Grouped folder counts
        db.rawQuery('''
          SELECT folder_id, COUNT(*) as cnt
          FROM documents
          WHERE is_archived = 0 AND is_deleted = 0 AND folder_id IS NOT NULL
          GROUP BY folder_id
        '''),
        // 5: Grouped tag counts
        db.rawQuery('''
          SELECT dt.tag_id, COUNT(DISTINCT d.id) as cnt
          FROM document_tags dt
          JOIN documents d ON dt.document_id = d.id
          WHERE d.is_archived = 0 AND d.is_deleted = 0
          GROUP BY dt.tag_id
        '''),
        // 6: Grouped type counts
        db.rawQuery('''
          SELECT r.document_type, COUNT(DISTINCT d.id) as cnt
          FROM document_recognitions r
          JOIN documents d ON r.document_id = d.id
          WHERE d.is_archived = 0 AND d.is_deleted = 0
          GROUP BY r.document_type
        '''),
        // 7: Private count
        db.rawQuery(
          'SELECT COUNT(*) as cnt FROM documents WHERE is_private = 1 AND is_archived = 0 AND is_deleted = 0',
        ),
      ]);

      final activeCnt = (futures[0].first['cnt'] as num?)?.toInt() ?? 0;
      final favCnt = (futures[1].first['cnt'] as num?)?.toInt() ?? 0;
      final archCnt = (futures[2].first['cnt'] as num?)?.toInt() ?? 0;
      final trashCnt = (futures[3].first['cnt'] as num?)?.toInt() ?? 0;
      final privateCnt = (futures[7].first['cnt'] as num?)?.toInt() ?? 0;

      final folderCounts = <String, int>{};
      for (final row in futures[4]) {
        final fid = row['folder_id'] as String?;
        final c = (row['cnt'] as num?)?.toInt() ?? 0;
        if (fid != null) folderCounts[fid] = c;
      }

      final tagCounts = <String, int>{};
      for (final row in futures[5]) {
        final tid = row['tag_id'] as String?;
        final c = (row['cnt'] as num?)?.toInt() ?? 0;
        if (tid != null) tagCounts[tid] = c;
      }

      final typeCounts = <String, int>{};
      for (final row in futures[6]) {
        final dtype = row['document_type'] as String?;
        final c = (row['cnt'] as num?)?.toInt() ?? 0;
        if (dtype != null) typeCounts[dtype] = c;
      }

      return DocumentCounts(
        activeCount: activeCnt,
        favoriteCount: favCnt,
        archivedCount: archCnt,
        trashCount: trashCnt,
        privateCount: privateCnt,
        folderCounts: folderCounts,
        tagCounts: tagCounts,
        typeCounts: typeCounts,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to calculate document counts: $e', e);
    }
  }

  @override
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to toggle favorite: $e', e);
    }
  }

  @override
  Future<void> togglePrivate(String id, bool isPrivate) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {
          'is_private': isPrivate ? 1 : 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to toggle private: $e', e);
    }
  }

  @override
  Future<void> setArchived(String id, bool isArchived) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {
          'is_archived': isArchived ? 1 : 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to update archive status: $e', e);
    }
  }

  @override
  Future<void> moveToTrash(String id) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {'is_deleted': 1, 'deleted_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to move document to trash: $e', e);
    }
  }

  @override
  Future<void> restoreFromTrash(String id) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {
          'is_deleted': 0,
          'deleted_at': null,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException(
        'Failed to restore document from trash: $e',
        e,
      );
    }
  }

  @override
  Future<void> recordDocumentOpened(String id) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {'last_opened_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  // Folders Implementation
  @override
  Future<List<FolderDto>> getAllFolders() async {
    try {
      final db = await _appDatabase.database;
      final results = await db.rawQuery('''
        SELECT f.*, COUNT(d.id) AS document_count
        FROM folders f
        LEFT JOIN documents d ON f.id = d.folder_id AND d.is_archived = 0 AND d.is_deleted = 0
        GROUP BY f.id
        ORDER BY f.name COLLATE NOCASE ASC
      ''');
      return results.map((m) {
        final count = (m['document_count'] as num?)?.toInt() ?? 0;
        return FolderDto.fromMap(m, documentCount: count);
      }).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to fetch folders: $e', e);
    }
  }

  @override
  Future<FolderDto?> getFolderById(String id) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.rawQuery(
        '''
        SELECT f.*, COUNT(d.id) AS document_count
        FROM folders f
        LEFT JOIN documents d ON f.id = d.folder_id AND d.is_archived = 0 AND d.is_deleted = 0
        WHERE f.id = ?
        GROUP BY f.id
        LIMIT 1
      ''',
        [id],
      );
      if (results.isEmpty) return null;
      final count = (results.first['document_count'] as num?)?.toInt() ?? 0;
      return FolderDto.fromMap(results.first, documentCount: count);
    } catch (e) {
      throw AppDatabaseException('Failed to query folder by id: $e', e);
    }
  }

  @override
  Future<void> insertFolder(FolderDto folder) async {
    try {
      final db = await _appDatabase.database;
      await db.insert(
        'folders',
        folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to create folder: $e', e);
    }
  }

  @override
  Future<void> updateFolder(FolderDto folder) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'folders',
        folder.toMap(),
        where: 'id = ?',
        whereArgs: [folder.id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to update folder: $e', e);
    }
  }

  @override
  Future<void> deleteFolder(String id) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        // Safe folder deletion: set documents.folder_id = NULL
        await txn.update(
          'documents',
          {'folder_id': null},
          where: 'folder_id = ?',
          whereArgs: [id],
        );
        await txn.delete('folders', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw AppDatabaseException('Failed to delete folder: $e', e);
    }
  }

  @override
  Future<void> moveDocumentToFolder(String documentId, String? folderId) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {
          'folder_id': folderId,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [documentId],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to move document to folder: $e', e);
    }
  }

  // Tags Implementation
  @override
  Future<List<TagDto>> getAllTags() async {
    try {
      final db = await _appDatabase.database;
      final results = await db.rawQuery('''
        SELECT t.*, COUNT(DISTINCT d.id) AS document_count
        FROM tags t
        LEFT JOIN document_tags dt ON t.id = dt.tag_id
        LEFT JOIN documents d ON dt.document_id = d.id AND d.is_archived = 0 AND d.is_deleted = 0
        GROUP BY t.id
        ORDER BY t.name COLLATE NOCASE ASC
      ''');
      return results.map((m) {
        final count = (m['document_count'] as num?)?.toInt() ?? 0;
        return TagDto.fromMap(m, documentCount: count);
      }).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to query tags: $e', e);
    }
  }

  @override
  Future<TagDto?> getTagById(String id) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.rawQuery(
        '''
        SELECT t.*, COUNT(DISTINCT d.id) AS document_count
        FROM tags t
        LEFT JOIN document_tags dt ON t.id = dt.tag_id
        LEFT JOIN documents d ON dt.document_id = d.id AND d.is_archived = 0 AND d.is_deleted = 0
        WHERE t.id = ?
        GROUP BY t.id
        LIMIT 1
      ''',
        [id],
      );
      if (results.isEmpty) return null;
      final count = (results.first['document_count'] as num?)?.toInt() ?? 0;
      return TagDto.fromMap(results.first, documentCount: count);
    } catch (e) {
      throw AppDatabaseException('Failed to query tag by id: $e', e);
    }
  }

  @override
  Future<void> insertTag(TagDto tag) async {
    try {
      final db = await _appDatabase.database;
      await db.insert(
        'tags',
        tag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to create tag: $e', e);
    }
  }

  @override
  Future<void> updateTag(TagDto tag) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'tags',
        tag.toMap(),
        where: 'id = ?',
        whereArgs: [tag.id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to update tag: $e', e);
    }
  }

  @override
  Future<void> deleteTag(String id) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        // Safe tag deletion: remove links, documents remain intact
        await txn.delete('document_tags', where: 'tag_id = ?', whereArgs: [id]);
        await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw AppDatabaseException('Failed to delete tag: $e', e);
    }
  }

  @override
  Future<void> assignTag(String documentId, String tagId) async {
    try {
      final db = await _appDatabase.database;
      await db.insert('document_tags', {
        'document_id': documentId,
        'tag_id': tagId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      throw AppDatabaseException('Failed to assign tag: $e', e);
    }
  }

  @override
  Future<void> removeTag(String documentId, String tagId) async {
    try {
      final db = await _appDatabase.database;
      await db.delete(
        'document_tags',
        where: 'document_id = ? AND tag_id = ?',
        whereArgs: [documentId, tagId],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to remove tag: $e', e);
    }
  }

  @override
  Future<List<TagDto>> getTagsForDocument(String documentId) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.rawQuery(
        '''
        SELECT t.*
        FROM tags t
        JOIN document_tags dt ON t.id = dt.tag_id
        WHERE dt.document_id = ?
        ORDER BY t.name COLLATE NOCASE ASC
      ''',
        [documentId],
      );
      return results.map((m) => TagDto.fromMap(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to get tags for document: $e', e);
    }
  }

  @override
  Future<Map<String, List<TagDto>>> getTagsForDocuments(
    List<String> documentIds,
  ) async {
    if (documentIds.isEmpty) return {};
    try {
      final db = await _appDatabase.database;
      final placeholders = List.filled(documentIds.length, '?').join(',');
      final results = await db.rawQuery('''
        SELECT dt.document_id, t.*
        FROM document_tags dt
        JOIN tags t ON dt.tag_id = t.id
        WHERE dt.document_id IN ($placeholders)
        ORDER BY t.name COLLATE NOCASE ASC
      ''', documentIds);

      final map = <String, List<TagDto>>{};
      for (final docId in documentIds) {
        map[docId] = [];
      }
      for (final row in results) {
        final docId = row['document_id'] as String;
        map[docId]?.add(TagDto.fromMap(row));
      }
      return map;
    } catch (e) {
      throw AppDatabaseException(
        'Failed to batch query tags for documents: $e',
        e,
      );
    }
  }

  // Bulk Operations Implementation in Transactions
  @override
  Future<void> bulkArchive(List<String> ids, bool isArchived) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final id in ids) {
          batch.update(
            'documents',
            {
              'is_archived': isArchived ? 1 : 0,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException('Failed to bulk archive documents: $e', e);
    }
  }

  @override
  Future<void> bulkFavorite(List<String> ids, bool isFavorite) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final id in ids) {
          batch.update(
            'documents',
            {'is_favorite': isFavorite ? 1 : 0},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException('Failed to bulk favorite documents: $e', e);
    }
  }

  @override
  Future<void> bulkSetPrivate(List<String> ids, bool isPrivate) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final id in ids) {
          batch.update(
            'documents',
            {'is_private': isPrivate ? 1 : 0, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException('Failed to bulk set private: $e', e);
    }
  }

  @override
  Future<void> bulkMoveToTrash(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final id in ids) {
          batch.update(
            'documents',
            {'is_deleted': 1, 'deleted_at': now},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException(
        'Failed to bulk move documents to trash: $e',
        e,
      );
    }
  }

  @override
  Future<void> bulkRestoreFromTrash(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final id in ids) {
          batch.update(
            'documents',
            {'is_deleted': 0, 'deleted_at': null, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException(
        'Failed to bulk restore documents from trash: $e',
        e,
      );
    }
  }

  @override
  Future<void> bulkMoveToFolder(List<String> ids, String? folderId) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final id in ids) {
          batch.update(
            'documents',
            {'folder_id': folderId, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException(
        'Failed to bulk move documents to folder: $e',
        e,
      );
    }
  }

  @override
  Future<void> bulkAssignTag(List<String> ids, String tagId) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final id in ids) {
          batch.insert('document_tags', {
            'document_id': id,
            'tag_id': tagId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException(
        'Failed to bulk assign tag to documents: $e',
        e,
      );
    }
  }

  @override
  Future<void> bulkRemoveTag(List<String> ids, String tagId) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final id in ids) {
          batch.delete(
            'document_tags',
            where: 'document_id = ? AND tag_id = ?',
            whereArgs: [id, tagId],
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException(
        'Failed to bulk remove tag from documents: $e',
        e,
      );
    }
  }

  @override
  Future<void> bulkPermanentDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final id in ids) {
          batch.delete(
            'document_pages',
            where: 'document_id = ?',
            whereArgs: [id],
          );
          batch.delete(
            'document_tags',
            where: 'document_id = ?',
            whereArgs: [id],
          );
          batch.delete('documents', where: 'id = ?', whereArgs: [id]);
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw AppDatabaseException(
        'Failed to bulk permanently delete documents: $e',
        e,
      );
    }
  }
}
