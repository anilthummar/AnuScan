import 'dart:io';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/utils/result.dart';

/// Use case for invoking native OS share sheet or opening PDF with external apps.
class SharePdfUseCase {
  const SharePdfUseCase(this._shareService, [this._fileStorageService]);

  final ShareService _shareService;
  final FileStorageService? _fileStorageService;

  /// Shares a PDF document using the platform share sheet.
  ///
  /// Verifies the file exists, invokes the native share sheet, and cleans
  /// temporary files afterwards.
  Future<Result<void>> call(String pdfPath, {String? title}) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        return const Result.failure(
          StorageFailure(
            'PDF file not found. It may have been moved or deleted.',
          ),
        );
      }

      await _shareService.shareFile(
        pdfPath,
        subject: title ?? 'Scanned Document',
        text: title != null
            ? 'Shared from AnuScan: $title'
            : 'Shared from AnuScan',
      );

      // Clean temporary cache files after sharing operation
      await _fileStorageService?.clearTempFiles();

      return const Result.success(null);
    } on AppException catch (e) {
      if (e is PermissionException) {
        return Result.failure(PermissionFailure(e.message, e.cause));
      } else if (e is StorageException) {
        return Result.failure(StorageFailure(e.message, e.cause));
      } else {
        return Result.failure(ShareFailure(e.message, e.cause));
      }
    } catch (e) {
      return Result.failure(ShareFailure('Failed to share PDF: $e', e));
    }
  }

  /// Opens the PDF with an external application on the device.
  Future<Result<void>> openExternal(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        return const Result.failure(
          StorageFailure(
            'PDF file not found. It may have been moved or deleted.',
          ),
        );
      }

      await _shareService.openFile(pdfPath);
      return const Result.success(null);
    } on AppException catch (e) {
      if (e is PermissionException) {
        return Result.failure(PermissionFailure(e.message, e.cause));
      } else if (e is StorageException) {
        return Result.failure(StorageFailure(e.message, e.cause));
      } else {
        return Result.failure(ShareFailure(e.message, e.cause));
      }
    } catch (e) {
      return Result.failure(
        ShareFailure('Failed to open PDF in external app: $e', e),
      );
    }
  }
}
