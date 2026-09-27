import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/features/document_history/domain/repositories/document_repository.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/rename_pdf_usecase.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late MockDocumentRepository mockDocRepo;
  late RenamePdfUseCase useCase;
  late Directory testDir;

  setUp(() async {
    mockDocRepo = MockDocumentRepository();
    useCase = RenamePdfUseCase(documentRepository: mockDocRepo);
    testDir = await Directory.systemTemp.createTemp('rename_test_');
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('RenamePdfUseCase', () {
    test('returns ValidationFailure when title is empty or blank', () async {
      final result = await useCase(
        documentId: 'doc-1',
        currentPdfPath: '/any/path.pdf',
        newTitle: '   ',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('returns StorageFailure when source file does not exist', () async {
      final nonExistentPath = p.join(testDir.path, 'missing.pdf');
      final result = await useCase(
        documentId: 'doc-1',
        currentPdfPath: nonExistentPath,
        newTitle: 'Valid Title',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<StorageFailure>());
    });

    test(
      'renames existing file on disk and updates repository with sanitized title',
      () async {
        final initialFile = File(p.join(testDir.path, 'original.pdf'));
        await initialFile.writeAsString('test pdf content');

        when(
          () => mockDocRepo.renameDocument(any(), any()),
        ).thenAnswer((_) async {});

        final result = await useCase(
          documentId: 'doc-123',
          currentPdfPath: initialFile.path,
          newTitle: 'My:Renamed*Doc',
        );

        expect(result.isSuccess, isTrue);
        final newPath = result.dataOrNull!;
        expect(await File(newPath).exists(), isTrue);
        expect(await initialFile.exists(), isFalse);
        expect(p.basename(newPath), 'My_Renamed_Doc.pdf');

        verify(
          () => mockDocRepo.renameDocument('doc-123', 'My:Renamed*Doc'),
        ).called(1);
      },
    );

    test(
      'returns current path without error if new name matches current name',
      () async {
        final initialFile = File(p.join(testDir.path, 'same_name.pdf'));
        await initialFile.writeAsString('sample content');

        when(
          () => mockDocRepo.renameDocument(any(), any()),
        ).thenAnswer((_) async {});

        final result = await useCase(
          documentId: 'doc-123',
          currentPdfPath: initialFile.path,
          newTitle: 'same_name',
        );

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, initialFile.path);
        expect(await initialFile.exists(), isTrue);
      },
    );
  });
}
