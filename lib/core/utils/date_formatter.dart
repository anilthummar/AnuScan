import 'package:intl/intl.dart';

/// Formatting helpers for dates and timestamps across the application.
abstract class DateFormatter {
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy • h:mm a');
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _fileTimestampFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Formats date for display in lists and details: "Sep 22, 2026 • 10:30 AM"
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Formats date only: "Sep 22, 2026"
  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime);
  }

  /// Formats timestamp for safe file naming: "20260922_103000"
  static String formatFileTimestamp(DateTime dateTime) {
    return _fileTimestampFormat.format(dateTime);
  }

  /// Generates default document title: "AnuScan_20260922_103000"
  static String defaultDocumentTitle([DateTime? time]) {
    final t = time ?? DateTime.now();
    return 'AnuScan_${formatFileTimestamp(t)}';
  }
}
