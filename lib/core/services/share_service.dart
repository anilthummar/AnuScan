import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../errors/exceptions.dart';
import 'security_service.dart';

/// Abstract service interface for sharing documents and opening them with external applications.
abstract class ShareService {
  /// Shares a single file (such as a generated PDF) via native OS share sheet.
  Future<void> shareFile(String filePath, {String? subject, String? text});

  /// Shares multiple files via native OS share sheet.
  Future<void> shareFiles(
    List<String> filePaths, {
    String? subject,
    String? text,
  });

  /// Shares plain text (such as extracted OCR text) via native OS share sheet.
  Future<void> shareText(String text, {String? subject});

  /// Opens a file in an external application (e.g. system default PDF viewer).
  Future<void> openFile(String filePath);
}

/// Implementation of [ShareService] using `share_plus` and `open_filex`.
class ShareServiceImpl implements ShareService {
  const ShareServiceImpl({this.securityService});

  final SecurityService? securityService;

  @override
  Future<void> shareFile(
    String filePath, {
    String? subject,
    String? text,
  }) async {
    securityService?.setTransientActivityActive(true);
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw StorageException('File not found to share at $filePath');
      }

      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath)], subject: subject, text: text),
      );

      if (result.status == ShareResultStatus.unavailable) {
        throw const ShareException('No share targets available on this device');
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw ShareException('Failed to share file: $e', e);
    } finally {
      securityService?.setTransientActivityActive(false);
    }
  }

  @override
  Future<void> shareFiles(
    List<String> filePaths, {
    String? subject,
    String? text,
  }) async {
    securityService?.setTransientActivityActive(true);
    try {
      final xFiles = <XFile>[];
      for (final p in filePaths) {
        if (await File(p).exists()) {
          xFiles.add(XFile(p));
        }
      }

      if (xFiles.isEmpty) {
        throw const StorageException('No valid files found to share');
      }

      final result = await SharePlus.instance.share(
        ShareParams(files: xFiles, subject: subject, text: text),
      );

      if (result.status == ShareResultStatus.unavailable) {
        throw const ShareException('No share targets available on this device');
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw ShareException('Failed to share files: $e', e);
    } finally {
      securityService?.setTransientActivityActive(false);
    }
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    securityService?.setTransientActivityActive(true);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );

      if (result.status == ShareResultStatus.unavailable) {
        throw const ShareException('No share targets available on this device');
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw ShareException('Failed to share text: $e', e);
    } finally {
      securityService?.setTransientActivityActive(false);
    }
  }

  @override
  Future<void> openFile(String filePath) async {
    securityService?.setTransientActivityActive(true);
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw StorageException('File not found to open at $filePath');
      }

      final result = await OpenFilex.open(filePath);
      switch (result.type) {
        case ResultType.done:
          break;
        case ResultType.fileNotFound:
          throw StorageException('File not found: ${result.message}');
        case ResultType.noAppToOpen:
          throw const ShareException(
            'No external application found on this device to open PDF files',
          );
        case ResultType.permissionDenied:
          throw const PermissionException(
            'Permission denied to open this file with an external application',
          );
        case ResultType.error:
          throw ShareException('Failed to open file: ${result.message}');
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw ShareException(
        'Failed to open file in external application: $e',
        e,
      );
    } finally {
      securityService?.setTransientActivityActive(false);
    }
  }
}
