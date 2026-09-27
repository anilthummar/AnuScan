import 'dart:io';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/utils/result.dart';
import '../../../document_history/domain/repositories/document_repository.dart';

/// Use case for permanently deleting a document session and PDF from disk and SQLite.
class DeletePdfUseCase {
  const DeletePdfUseCase({
    required this.fileStorageService,
    this.documentRepository,
  });

  final FileStorageService fileStorageService;
  final DocumentRepository? documentRepository;

  /// Deletes the document directory, purges database records, and clears temporary cache files.
  Future<Result<void>> call({
    required String documentId,
    String? pdfPath,
  }) async {
    try {
      // 1. Delete specific PDF file if provided and still exists
      if (pdfPath != null) {
        final pdfFile = File(pdfPath);
        if (await pdfFile.exists()) {
          try {
            await pdfFile.delete();
          } catch (_) {
            // Ignored if handled by directory deletion below
          }
        }
      }

      // 2. Delete the entire document directory containing images and assets
      await fileStorageService.deleteDocumentDirectory(documentId);

      // 3. Delete the document record from the local SQLite database
      final docRepo = documentRepository;
      if (docRepo != null) {
        try {
          await docRepo.deleteDocument(documentId);
        } catch (_) {
          // May not have been saved to database yet
        }
      }

      // 4. Clean temporary cache files
      await fileStorageService.clearTempFiles();

      return const Result.success(null);
    } on AppException catch (e) {
      if (e is StorageException) {
        return Result.failure(StorageFailure(e.message, e.cause));
      } else if (e is AppDatabaseException) {
        return Result.failure(AppDatabaseFailure(e.message, e.cause));
      } else {
        return Result.failure(StorageFailure(e.message, e.cause));
      }
    } catch (e) {
      return Result.failure(StorageFailure('Failed to delete document: $e', e));
    }
  }
}
