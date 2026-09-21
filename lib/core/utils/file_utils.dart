import 'dart:io';

/// File and I/O utility helpers.
abstract class FileUtils {
  /// Converts byte count to human-readable string (e.g., "1.4 MB", "340 KB").
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Gets the file size of a given path in human-readable format.
  static Future<String> getFileSizeString(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final length = await file.length();
        return formatBytes(length);
      }
    } catch (_) {}
    return '0 B';
  }

  /// Cleans and sanitizes a file name, removing unsafe OS characters.
  static String sanitizeFileName(String name) {
    var sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      sanitized = 'Untitled_Document';
    }
    return sanitized;
  }
}
