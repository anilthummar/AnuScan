/// Global application-wide constants for AnuScan.
abstract class AppConstants {
  // Application Info
  static const String appName = 'AnuScan';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Fast, Private & Offline Document Scanner';

  // Scanning & Document Limits
  static const int maxPagesPerDocument = 100;
  static const String defaultPdfPrefix = 'AnuScan_';
  static const int defaultImageQuality = 92;
  static const int thumbnailWidth = 300;

  // File System & Storage Directories
  static const String tempDirectoryName = 'anuscan_temp';
  static const String documentsDirectoryName = 'documents';
  static const String tempDir = tempDirectoryName;
  static const String documentsDir = documentsDirectoryName;
  static const List<String> supportedImageExtensions = ['jpg', 'jpeg', 'png'];

  // Database
  static const String databaseName = 'anuscan.db';
  static const int databaseVersion = 1;

  // Animation & UI Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 250);
  static const Duration snackbarDuration = Duration(seconds: 3);
}
