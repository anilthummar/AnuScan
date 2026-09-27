import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:anuscan/core/constants/app_constants.dart';
import 'package:anuscan/core/services/file_storage_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  FakePathProviderPlatform({required this.tempPath, required this.docsPath});

  final String tempPath;
  final String docsPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory systemTempDir;
  late Directory mockTempDir;
  late Directory mockDocsDir;
  late FileStorageServiceImpl service;

  setUp(() async {
    systemTempDir = await Directory.systemTemp.createTemp('file_storage_test_');
    mockTempDir = Directory(p.join(systemTempDir.path, 'temp_base'))
      ..createSync();
    mockDocsDir = Directory(p.join(systemTempDir.path, 'docs_base'))
      ..createSync();

    PathProviderPlatform.instance = FakePathProviderPlatform(
      tempPath: mockTempDir.path,
      docsPath: mockDocsDir.path,
    );

    service = const FileStorageServiceImpl();
  });

  tearDown(() async {
    if (await systemTempDir.exists()) {
      await systemTempDir.delete(recursive: true);
    }
  });

  test('resolves temporary directory correctly', () async {
    final tempDir = await service.getTemporaryDirectory();
    expect(tempDir.path, equals(mockTempDir.path));
  });

  test('resolves app documents directory correctly', () async {
    final docsDir = await service.getAppDocumentsDirectory();
    expect(docsDir.path, equals(mockDocsDir.path));
  });

  test('creates document directory under app documents', () async {
    final docDir = await service.getOrCreateDocumentDirectory('doc_123');
    expect(docDir.existsSync(), isTrue);
    expect(docDir.path, contains(AppConstants.documentsDir));
    expect(docDir.path, endsWith('doc_123'));
  });

  test('creates temp file path inside temp directory', () async {
    final tempPath = await service.createTempFilePath(extension: 'jpg');
    expect(tempPath, startsWith(mockTempDir.path));
    expect(tempPath, contains(AppConstants.tempDir));
    expect(tempPath.endsWith('.jpg'), isTrue);

    // Parent directory must have been created
    final parentDir = File(tempPath).parent;
    expect(parentDir.existsSync(), isTrue);
  });

  test('saves image bytes to document directory and deletes file', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final filePath = await service.saveImageBytes(
      'doc_456',
      bytes,
      filename: 'test_img.jpg',
    );

    final savedFile = File(filePath);
    expect(savedFile.existsSync(), isTrue);
    expect(await savedFile.readAsBytes(), equals(bytes));

    // Test deleteFile
    await service.deleteFile(filePath);
    expect(savedFile.existsSync(), isFalse);
  });

  test('copies image file to document directory', () async {
    final sourceFile = File(p.join(mockTempDir.path, 'source.jpg'));
    await sourceFile.writeAsBytes([10, 20, 30]);

    final copiedPath = await service.copyImageFile(
      'doc_789',
      sourceFile.path,
      filename: 'copied.jpg',
    );

    final copiedFile = File(copiedPath);
    expect(copiedFile.existsSync(), isTrue);
    expect(await copiedFile.readAsBytes(), equals([10, 20, 30]));
  });

  test('clears temporary files cache folder', () async {
    final tempPath = await service.createTempFilePath(extension: 'tmp.jpg');
    final tempFile = File(tempPath);
    await tempFile.writeAsString('temp content');
    expect(tempFile.existsSync(), isTrue);

    await service.clearTempFiles();

    final tempFolder = Directory(
      p.join(mockTempDir.path, AppConstants.tempDir),
    );
    expect(tempFolder.existsSync(), isFalse);
  });

  test('deletes document directory and contents', () async {
    final bytes = Uint8List.fromList([1, 2]);
    await service.saveImageBytes('doc_to_delete', bytes, filename: 'p1.jpg');

    final docDir = await service.getOrCreateDocumentDirectory('doc_to_delete');
    expect(docDir.existsSync(), isTrue);

    await service.deleteDocumentDirectory('doc_to_delete');
    expect(docDir.existsSync(), isFalse);
  });
}
