import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../errors/exceptions.dart';

/// Abstract service interface for managing file system storage and caching.
abstract class FileStorageService {
  /// Directory for permanent document storage.
  Future<Directory> getAppDocumentsDirectory();

  /// Directory for temporary processing cache.
  Future<Directory> getTemporaryDirectory();

  /// Creates and returns a dedicated folder for a document by its ID.
  Future<Directory> getOrCreateDocumentDirectory(String documentId);

  /// Saves raw image bytes into the document's directory.
  Future<String> saveImageBytes(
    String documentId,
    Uint8List bytes, {
    String? filename,
  });

  /// Copies an image file into the document's directory.
  Future<String> copyImageFile(
    String documentId,
    String sourcePath, {
    String? filename,
  });

  /// Deletes the folder and all files associated with a document ID.
  Future<void> deleteDocumentDirectory(String documentId);

  /// Generates a unique temporary file path.
  Future<String> createTempFilePath({String extension = 'jpg'});

  /// Clears temporary cache files.
  Future<void> clearTempFiles();
}

/// Implementation of [FileStorageService] using `path_provider`.
class FileStorageServiceImpl implements FileStorageService {
  const FileStorageServiceImpl({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  Future<Directory> getAppDocumentsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      throw StorageException('Failed to get app documents directory: $e', e);
    }
  }

  @override
  Future<Directory> getTemporaryDirectory() async {
    try {
      final dir = await getTemporaryDirectory();
      return dir;
    } catch (e) {
      throw StorageException('Failed to get temporary directory: $e', e);
    }
  }

  @override
  Future<Directory> getOrCreateDocumentDirectory(String documentId) async {
    try {
      final appDocs = await getApplicationDocumentsDirectory();
      final docDir = Directory(p.join(appDocs.path, 'documents', documentId));
      if (!await docDir.exists()) {
        await docDir.create(recursive: true);
      }
      return docDir;
    } catch (e) {
      throw StorageException('Failed to create document directory: $e', e);
    }
  }

  @override
  Future<String> saveImageBytes(
    String documentId,
    Uint8List bytes, {
    String? filename,
  }) async {
    try {
      final docDir = await getOrCreateDocumentDirectory(documentId);
      final name = filename ?? '${_uuid.v4()}.jpg';
      final file = File(p.join(docDir.path, name));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      throw StorageException('Failed to save image bytes: $e', e);
    }
  }

  @override
  Future<String> copyImageFile(
    String documentId,
    String sourcePath, {
    String? filename,
  }) async {
    try {
      final docDir = await getOrCreateDocumentDirectory(documentId);
      final ext = p.extension(sourcePath).isEmpty
          ? '.jpg'
          : p.extension(sourcePath);
      final name = filename ?? '${_uuid.v4()}$ext';
      final destination = File(p.join(docDir.path, name));
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw StorageException('Source image does not exist: $sourcePath');
      }
      await sourceFile.copy(destination.path);
      return destination.path;
    } catch (e) {
      throw StorageException('Failed to copy image file: $e', e);
    }
  }

  @override
  Future<void> deleteDocumentDirectory(String documentId) async {
    try {
      final appDocs = await getApplicationDocumentsDirectory();
      final docDir = Directory(p.join(appDocs.path, 'documents', documentId));
      if (await docDir.exists()) {
        await docDir.delete(recursive: true);
      }
    } catch (e) {
      throw StorageException('Failed to delete document directory: $e', e);
    }
  }

  @override
  Future<String> createTempFilePath({String extension = 'jpg'}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final ext = extension.startsWith('.') ? extension : '.$extension';
      final tempFolder = Directory(p.join(tempDir.path, 'anuscan_temp'));
      if (!await tempFolder.exists()) {
        await tempFolder.create(recursive: true);
      }
      return p.join(tempFolder.path, '${_uuid.v4()}$ext');
    } catch (e) {
      throw StorageException('Failed to create temp file path: $e', e);
    }
  }

  @override
  Future<void> clearTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFolder = Directory(p.join(tempDir.path, 'anuscan_temp'));
      if (await tempFolder.exists()) {
        await tempFolder.delete(recursive: true);
      }
    } catch (e) {
      // Non-critical, ignore silent failure
    }
  }
}
