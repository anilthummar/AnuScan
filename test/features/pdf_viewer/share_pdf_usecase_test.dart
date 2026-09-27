import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:anuscan/core/errors/exceptions.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/share_service.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/share_pdf_usecase.dart';

class MockShareService extends Mock implements ShareService {}

class MockFileStorageService extends Mock implements FileStorageService {}

void main() {
  late MockShareService mockShareService;
  late MockFileStorageService mockStorageService;
  late SharePdfUseCase useCase;
  late Directory testDir;

  setUp(() async {
    mockShareService = MockShareService();
    mockStorageService = MockFileStorageService();
    useCase = SharePdfUseCase(mockShareService, mockStorageService);
    testDir = await Directory.systemTemp.createTemp('share_test_');
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('SharePdfUseCase - share', () {
    test('returns StorageFailure when PDF file does not exist', () async {
      final nonExistentPath = p.join(testDir.path, 'missing.pdf');
      final result = await useCase(nonExistentPath, title: 'My PDF');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<StorageFailure>());
      verifyNever(
        () => mockShareService.shareFile(
          any(),
          subject: any(named: 'subject'),
          text: any(named: 'text'),
        ),
      );
    });

    test(
      'invokes shareService and clears temp cache when file exists',
      () async {
        final pdfFile = File(p.join(testDir.path, 'test_doc.pdf'));
        await pdfFile.writeAsString('sample pdf content');

        when(
          () => mockShareService.shareFile(
            any(),
            subject: any(named: 'subject'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockStorageService.clearTempFiles(),
        ).thenAnswer((_) async {});

        final result = await useCase(pdfFile.path, title: 'Important Report');

        expect(result.isSuccess, isTrue);
        verify(
          () => mockShareService.shareFile(
            pdfFile.path,
            subject: 'Important Report',
            text: 'Shared from AnuScan: Important Report',
          ),
        ).called(1);
        verify(() => mockStorageService.clearTempFiles()).called(1);
      },
    );

    test(
      'returns ShareFailure when shareService throws ShareException',
      () async {
        final pdfFile = File(p.join(testDir.path, 'test_doc.pdf'));
        await pdfFile.writeAsString('content');

        when(
          () => mockShareService.shareFile(
            any(),
            subject: any(named: 'subject'),
            text: any(named: 'text'),
          ),
        ).thenThrow(const ShareException('No share targets'));

        final result = await useCase(pdfFile.path);

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<ShareFailure>());
        expect(result.failureOrNull!.message, 'No share targets');
      },
    );
  });

  group('SharePdfUseCase - openExternal', () {
    test('returns StorageFailure when PDF file does not exist', () async {
      final nonExistentPath = p.join(testDir.path, 'missing.pdf');
      final result = await useCase.openExternal(nonExistentPath);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<StorageFailure>());
      verifyNever(() => mockShareService.openFile(any()));
    });

    test('calls shareService.openFile when file exists', () async {
      final pdfFile = File(p.join(testDir.path, 'test_open.pdf'));
      await pdfFile.writeAsString('content');

      when(() => mockShareService.openFile(any())).thenAnswer((_) async {});

      final result = await useCase.openExternal(pdfFile.path);

      expect(result.isSuccess, isTrue);
      verify(() => mockShareService.openFile(pdfFile.path)).called(1);
    });

    test('returns ShareFailure when no external app found', () async {
      final pdfFile = File(p.join(testDir.path, 'test_open.pdf'));
      await pdfFile.writeAsString('content');

      when(() => mockShareService.openFile(any())).thenThrow(
        const ShareException(
          'No external application found on this device to open PDF files',
        ),
      );

      final result = await useCase.openExternal(pdfFile.path);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ShareFailure>());
      expect(
        result.failureOrNull!.message,
        contains('No external application found'),
      );
    });
  });
}
