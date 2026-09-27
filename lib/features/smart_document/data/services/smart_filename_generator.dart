import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/document_classification.dart';
import '../../domain/entities/document_metadata.dart';

/// Generates safe, clean, meaningful document filenames based on extracted metadata and type.
class SmartFilenameGenerator {
  const SmartFilenameGenerator();

  static const int maxFilenameLength = 80;

  /// Suggests a smart filename. Does not append extension (.pdf is added during export).
  String generate({
    required DocumentClassification classification,
    required DocumentMetadata metadata,
    String? fallbackName,
  }) {
    final parts = <String>[];

    final primaryEntity = metadata.primaryEntity?.trim();
    final primaryIdentifier = metadata.primaryIdentifier?.trim();
    final date = metadata.date?.trim();

    final typeName = classification.type != DocumentType.other
        ? classification.type.displayName
        : null;

    // Pattern 1: Certificate / Awards
    if (classification.type == DocumentType.certificate) {
      if (metadata.title != null && metadata.title!.isNotEmpty) {
        parts.add(metadata.title!);
      } else {
        parts.add('Certificate');
      }
      if (primaryEntity != null && primaryEntity.isNotEmpty) {
        parts.add(primaryEntity);
      }
    }
    // Pattern 2: Business Card
    else if (classification.type == DocumentType.businessCard) {
      if (metadata.personName != null && metadata.personName!.isNotEmpty) {
        parts.add(metadata.personName!);
      }
      if (metadata.companyName != null && metadata.companyName!.isNotEmpty) {
        parts.add(metadata.companyName!);
      }
    }
    // Pattern 3: Invoice / Receipt / Financial / Standard
    else {
      if (primaryEntity != null && primaryEntity.isNotEmpty) {
        parts.add(primaryEntity);
      }

      if (typeName != null) {
        parts.add(typeName);
      }

      if (primaryIdentifier != null && primaryIdentifier.isNotEmpty) {
        parts.add(primaryIdentifier);
      }

      if (date != null && date.isNotEmpty && parts.length < 3) {
        parts.add(_sanitizeDateForFilename(date));
      }
    }

    // Fallback if no parts could be assembled
    if (parts.isEmpty) {
      if (fallbackName != null && fallbackName.trim().isNotEmpty) {
        return sanitize(fallbackName);
      }
      final todayStr = _formatTodayDate();
      if (typeName != null) {
        return sanitize('$typeName - $todayStr');
      }
      return sanitize('Document - $todayStr');
    }

    final rawName = parts.join(' - ');
    return sanitize(rawName);
  }

  /// Cleans and bounds filename length, ensuring filesystem safety.
  String sanitize(String name) {
    // 1. Remove dangerous OS path chars
    var sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    // 2. Collapse whitespace and duplicate separators
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    sanitized = sanitized.replaceAll(RegExp(r'\s*-\s*-\s*'), ' - ');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    sanitized = sanitized.trim();

    // 3. Remove leading/trailing periods, hyphens, underscores
    sanitized = sanitized.replaceAll(RegExp(r'^[\s.\-_]+|[\s.\-_]+$'), '');

    // 4. Fallback if empty
    if (sanitized.isEmpty) {
      sanitized = 'Document';
    }

    // 5. Length bounding (max 80 chars)
    if (sanitized.length > maxFilenameLength) {
      sanitized = sanitized.substring(0, maxFilenameLength).trim();
      sanitized = sanitized.replaceAll(RegExp(r'[\s.\-_]+$'), '');
    }

    // 6. Leverage existing FileUtils.sanitizeFileName for parity
    return FileUtils.sanitizeFileName(sanitized);
  }

  String _sanitizeDateForFilename(String date) {
    // Replace slashes with hyphens
    return date.replaceAll('/', '-').replaceAll(' ', '-').replaceAll(',', '');
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
