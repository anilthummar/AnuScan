import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:anuscan/core/errors/exceptions.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/features/document_history/domain/repositories/document_repository.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/delete_pdf_usecase.dart';

class MockFileStorageService extends Mock implements FileStorageService {}

class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late MockFileStorageService mockStorage;
  late MockDocumentRepository mockDocRepo;
  late DeletePdfUseCase useCase;
  late Directory testDir;

  setUp(() async {
    mockStorage = MockFileStorageService();
    mockDocRepo = MockDocumentRepository();
    useCase = DeletePdfUseCase(
      fileStorageService: mockStorage,
      documentRepository: mockDocRepo,
    );
    testDir = await Directory.systemTemp.createTemp('delete_test_');
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('DeletePdfUseCase', () {
    test(
      'successfully deletes directory, pdf file, DB record, and clears temp cache',
      () async {
        final samplePdf = File(p.join(testDir.path, 'doc.pdf'));
        await samplePdf.writeAsString('sample');

        when(
          () => mockStorage.deleteDocumentDirectory('doc-101'),
        ).thenAnswer((_) async {});
        when(
          () => mockDocRepo.deleteDocument('doc-101'),
        ).thenAnswer((_) async {});
        when(() => mockStorage.clearTempFiles()).thenAnswer((_) async {});

        final result = await useCase(
          documentId: 'doc-101',
          pdfPath: samplePdf.path,
        );

        expect(result.isSuccess, isTrue);
        expect(await samplePdf.exists(), isFalse);

        verify(() => mockStorage.deleteDocumentDirectory('doc-101')).called(1);
        verify(() => mockDocRepo.deleteDocument('doc-101')).called(1);
        verify(() => mockStorage.clearTempFiles()).called(1);
      },
    );

    test('tolerates null pdfPath and non-existent files gracefully', () async {
      when(
        () => mockStorage.deleteDocumentDirectory('doc-202'),
      ).thenAnswer((_) async {});
      when(
        () => mockDocRepo.deleteDocument('doc-202'),
      ).thenAnswer((_) async {});
      when(() => mockStorage.clearTempFiles()).thenAnswer((_) async {});

      final result = await useCase(documentId: 'doc-202');

      expect(result.isSuccess, isTrue);
      verify(() => mockStorage.deleteDocumentDirectory('doc-202')).called(1);
      verify(() => mockDocRepo.deleteDocument('doc-202')).called(1);
      verify(() => mockStorage.clearTempFiles()).called(1);
    });

    test(
      'returns StorageFailure when storage service throws StorageException',
      () async {
        when(
          () => mockStorage.deleteDocumentDirectory('doc-err'),
        ).thenThrow(const StorageException('Disk I/O failed'));

        final result = await useCase(documentId: 'doc-err');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<StorageFailure>());
      },
    );
  });
}
