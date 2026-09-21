import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../errors/exceptions.dart';

/// Abstract service interface for sharing documents using the platform share sheet.
abstract class ShareService {
  /// Shares a single file (such as a generated PDF) via native OS share sheet.
  Future<void> shareFile(String filePath, {String? subject, String? text});

  /// Shares multiple files via native OS share sheet.
  Future<void> shareFiles(List<String> filePaths, {String? subject, String? text});
}

/// Implementation of [ShareService] using `share_plus`.
class ShareServiceImpl implements ShareService {
  const ShareServiceImpl();

  @override
  Future<void> shareFile(String filePath, {String? subject, String? text}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ShareException('File not found to share at $filePath');
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: subject,
          text: text,
        ),
      );
    } catch (e) {
      throw ShareException('Failed to share file: $e', e);
    }
  }

  @override
  Future<void> shareFiles(List<String> filePaths, {String? subject, String? text}) async {
    try {
      final xFiles = <XFile>[];
      for (final p in filePaths) {
        if (await File(p).exists()) {
          xFiles.add(XFile(p));
        }
      }

      if (xFiles.isEmpty) {
        throw const ShareException('No valid files found to share');
      }

      await SharePlus.instance.share(
        ShareParams(
          files: xFiles,
          subject: subject,
          text: text,
        ),
      );
    } catch (e) {
      throw ShareException('Failed to share files: $e', e);
    }
  }
}
