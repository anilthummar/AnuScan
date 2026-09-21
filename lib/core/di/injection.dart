import 'package:get_it/get_it.dart';
import '../database/app_database.dart';
import '../services/document_scanner_service.dart';
import '../services/file_storage_service.dart';
import '../services/gallery_service.dart';
import '../services/image_processing_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_generator_service.dart';
import '../services/share_service.dart';
import '../../features/document_history/data/datasources/local_document_datasource.dart';
import '../../features/document_history/data/repositories/document_repository_impl.dart';
import '../../features/document_history/domain/repositories/document_repository.dart';
import '../../features/document_history/domain/usecases/document_usecases.dart';
import '../../features/scanner/data/repositories/scanner_repository_impl.dart';
import '../../features/scanner/domain/repositories/scanner_repository.dart';
import '../../features/scanner/domain/usecases/import_gallery_usecase.dart';
import '../../features/scanner/domain/usecases/scan_documents_usecase.dart';
import '../../features/document_editor/domain/usecases/process_page_usecase.dart';
import '../../features/document_editor/domain/usecases/reorder_pages_usecase.dart';
import '../../features/pdf_viewer/domain/usecases/generate_pdf_usecase.dart';
import '../../features/pdf_viewer/domain/usecases/share_pdf_usecase.dart';

final GetIt sl = GetIt.instance;

/// Registers all core services, repositories, and use cases with GetIt.
Future<void> setupDependencyInjection({
  AppDatabase? customDatabase,
  FileStorageService? customStorageService,
  ImageProcessingService? customImageService,
  PdfGeneratorService? customPdfService,
  DocumentScannerService? customScannerService,
  GalleryService? customGalleryService,
  ShareService? customShareService,
  OcrService? customOcrService,
  DocumentRepository? customDocumentRepository,
  ScannerRepository? customScannerRepository,
}) async {
  // Database
  if (customDatabase != null) {
    sl.registerSingleton<AppDatabase>(customDatabase);
  } else if (!sl.isRegistered<AppDatabase>()) {
    sl.registerLazySingleton<AppDatabase>(() => AppDatabase());
  }

  // Core Platform & Storage Services
  if (customStorageService != null) {
    sl.registerSingleton<FileStorageService>(customStorageService);
  } else if (!sl.isRegistered<FileStorageService>()) {
    sl.registerLazySingleton<FileStorageService>(() => const FileStorageServiceImpl());
  }

  if (customImageService != null) {
    sl.registerSingleton<ImageProcessingService>(customImageService);
  } else if (!sl.isRegistered<ImageProcessingService>()) {
    sl.registerLazySingleton<ImageProcessingService>(() => const ImageProcessingServiceImpl());
  }

  if (customPdfService != null) {
    sl.registerSingleton<PdfGeneratorService>(customPdfService);
  } else if (!sl.isRegistered<PdfGeneratorService>()) {
    sl.registerLazySingleton<PdfGeneratorService>(() => const PdfGeneratorServiceImpl());
  }

  if (customScannerService != null) {
    sl.registerSingleton<DocumentScannerService>(customScannerService);
  } else if (!sl.isRegistered<DocumentScannerService>()) {
    sl.registerLazySingleton<DocumentScannerService>(() => const DocumentScannerServiceImpl());
  }

  if (customGalleryService != null) {
    sl.registerSingleton<GalleryService>(customGalleryService);
  } else if (!sl.isRegistered<GalleryService>()) {
    sl.registerLazySingleton<GalleryService>(() => GalleryServiceImpl());
  }

  if (customShareService != null) {
    sl.registerSingleton<ShareService>(customShareService);
  } else if (!sl.isRegistered<ShareService>()) {
    sl.registerLazySingleton<ShareService>(() => const ShareServiceImpl());
  }

  if (customOcrService != null) {
    sl.registerSingleton<OcrService>(customOcrService);
  } else if (!sl.isRegistered<OcrService>()) {
    sl.registerLazySingleton<OcrService>(() => const StubOcrServiceImpl());
  }

  // Data Sources
  if (!sl.isRegistered<LocalDocumentDataSource>()) {
    sl.registerLazySingleton<LocalDocumentDataSource>(
      () => LocalDocumentDataSourceImpl(sl<AppDatabase>()),
    );
  }

  // Repositories
  if (customDocumentRepository != null) {
    sl.registerSingleton<DocumentRepository>(customDocumentRepository);
  } else if (!sl.isRegistered<DocumentRepository>()) {
    sl.registerLazySingleton<DocumentRepository>(
      () => DocumentRepositoryImpl(
        localDataSource: sl<LocalDocumentDataSource>(),
        fileStorageService: sl<FileStorageService>(),
      ),
    );
  }

  if (customScannerRepository != null) {
    sl.registerSingleton<ScannerRepository>(customScannerRepository);
  } else if (!sl.isRegistered<ScannerRepository>()) {
    sl.registerLazySingleton<ScannerRepository>(
      () => ScannerRepositoryImpl(
        scannerService: sl<DocumentScannerService>(),
        galleryService: sl<GalleryService>(),
      ),
    );
  }

  // Use Cases
  if (!sl.isRegistered<GetDocumentsUseCase>()) {
    sl.registerFactory(() => GetDocumentsUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<GetDocumentByIdUseCase>()) {
    sl.registerFactory(() => GetDocumentByIdUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<SaveDocumentUseCase>()) {
    sl.registerFactory(() => SaveDocumentUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<DeleteDocumentUseCase>()) {
    sl.registerFactory(() => DeleteDocumentUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<RenameDocumentUseCase>()) {
    sl.registerFactory(() => RenameDocumentUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<SearchDocumentsUseCase>()) {
    sl.registerFactory(() => SearchDocumentsUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<ScanDocumentsUseCase>()) {
    sl.registerFactory(() => ScanDocumentsUseCase(sl<ScannerRepository>()));
  }
  if (!sl.isRegistered<ImportGalleryUseCase>()) {
    sl.registerFactory(() => ImportGalleryUseCase(sl<ScannerRepository>()));
  }
  if (!sl.isRegistered<ProcessPageUseCase>()) {
    sl.registerFactory(() => ProcessPageUseCase(
          imageProcessingService: sl<ImageProcessingService>(),
          fileStorageService: sl<FileStorageService>(),
        ));
  }
  if (!sl.isRegistered<ReorderPagesUseCase>()) {
    sl.registerFactory(() => const ReorderPagesUseCase());
  }
  if (!sl.isRegistered<GeneratePdfUseCase>()) {
    sl.registerFactory(() => GeneratePdfUseCase(
          pdfGeneratorService: sl<PdfGeneratorService>(),
          fileStorageService: sl<FileStorageService>(),
          imageProcessingService: sl<ImageProcessingService>(),
        ));
  }
  if (!sl.isRegistered<SharePdfUseCase>()) {
    sl.registerFactory(() => SharePdfUseCase(sl<ShareService>()));
  }
}
