import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/local_document_datasource.dart';
import '../models/document_dto.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  const DocumentRepositoryImpl({
    required this.localDataSource,
    required this.fileStorageService,
  });

  final LocalDocumentDataSource localDataSource;
  final FileStorageService fileStorageService;

  @override
  Future<List<DocumentEntity>> getAllDocuments() async {
    final dtos = await localDataSource.getAllDocuments();
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<DocumentEntity?> getDocumentById(String id) async {
    final dto = await localDataSource.getDocumentById(id);
    if (dto == null) return null;

    final pageDtos = await localDataSource.getPagesForDocument(id);
    final pages = pageDtos.map((p) => p.toEntity()).toList();

    return dto.toEntity(pages: pages);
  }

  @override
  Future<void> saveDocument(DocumentEntity document) async {
    final docDto = DocumentDto.fromEntity(document);
    final pageDtos = document.pages.map((p) => DocumentPageDto.fromEntity(p)).toList();

    await localDataSource.insertOrUpdateDocument(docDto, pageDtos);
  }

  @override
  Future<void> deleteDocument(String id) async {
    await localDataSource.deleteDocument(id);
    await fileStorageService.deleteDocumentDirectory(id);
  }

  @override
  Future<void> renameDocument(String id, String newTitle) async {
    final existing = await localDataSource.getDocumentById(id);
    if (existing == null) return;

    var newPdfPath = existing.pdfPath;
    final oldPdfFile = File(existing.pdfPath);

    if (await oldPdfFile.exists()) {
      final sanitized = FileUtils.sanitizeFileName(newTitle);
      final dir = oldPdfFile.parent.path;
      final targetPath = p.join(dir, '$sanitized.pdf');

      if (targetPath != existing.pdfPath) {
        await oldPdfFile.rename(targetPath);
        newPdfPath = targetPath;
      }
    }

    await localDataSource.updateDocumentTitle(id, newTitle, newPdfPath);
  }

  @override
  Future<List<DocumentEntity>> searchDocuments(String query) async {
    final dtos = await localDataSource.searchDocuments(query);
    return dtos.map((d) => d.toEntity()).toList();
  }
}
