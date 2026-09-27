import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/result.dart';
import '../../../document_history/domain/repositories/document_repository.dart';

/// Use case for renaming a generated PDF document both on disk and in database.
class RenamePdfUseCase {
  const RenamePdfUseCase({this.documentRepository});

  final DocumentRepository? documentRepository;

  /// Renames the PDF file on disk and updates the title in SQLite.
  ///
  /// Returns [Result.success] with the new file path on success,
  /// or [Result.failure] on validation or storage failures.
  Future<Result<String>> call({
    required String documentId,
    required String currentPdfPath,
    required String newTitle,
  }) async {
    final sanitizedTitle = newTitle.trim();
    if (sanitizedTitle.isEmpty) {
      return const Result.failure(
        ValidationFailure('PDF title cannot be empty'),
      );
    }

    try {
      final currentFile = File(currentPdfPath);
      if (!await currentFile.exists()) {
        return const Result.failure(
          StorageFailure(
            'Source PDF file not found. It may have been moved or deleted.',
          ),
        );
      }

      final safeName = FileUtils.sanitizeFileName(sanitizedTitle);
      final parentDir = p.dirname(currentPdfPath);
      final newFilePath = p.join(parentDir, '$safeName.pdf');

      String finalPath = currentPdfPath;
      if (newFilePath != currentPdfPath) {
        final renamedFile = await currentFile.rename(newFilePath);
        finalPath = renamedFile.path;
      }

      // Sync updated title and path to the local database if repository is available
      final docRepo = documentRepository;
      if (docRepo != null) {
        try {
          await docRepo.renameDocument(documentId, sanitizedTitle);
        } catch (_) {
          // Document may not be persisted to DB yet (e.g. previewing before saving)
        }
      }

      return Result.success(finalPath);
    } on AppException catch (e) {
      if (e is StorageException) {
        return Result.failure(StorageFailure(e.message, e.cause));
      } else if (e is AppDatabaseException) {
        return Result.failure(AppDatabaseFailure(e.message, e.cause));
      } else {
        return Result.failure(StorageFailure(e.message, e.cause));
      }
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to rename PDF document: $e', e),
      );
    }
  }
}
