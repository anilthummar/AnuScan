import 'dart:io';
import 'package:get_it/get_it.dart';
import '../database/app_database.dart';
import '../services/document_scanner_service.dart';
import '../services/file_storage_service.dart';
import '../services/gallery_service.dart';
import '../services/image_processing_service.dart';
import '../services/mlkit_ocr_service_impl.dart';
import '../services/ocr_service.dart';
import '../services/pdf_generator_service.dart';
import '../services/preferences_service.dart';
import '../services/searchable_pdf_service.dart';
import '../services/share_service.dart';
import '../../features/document_history/data/datasources/local_document_datasource.dart';
import '../../features/document_history/data/repositories/document_repository_impl.dart';
import '../../features/document_history/domain/repositories/document_repository.dart';
import '../../features/document_history/domain/usecases/document_usecases.dart';
import '../../features/document_history/domain/usecases/management_usecases.dart';
import '../../features/document_history/presentation/cubit/document_history_cubit.dart';
import '../../features/gallery/data/repositories/gallery_repository_impl.dart';
import '../../features/gallery/domain/repositories/gallery_repository.dart';
import '../../features/gallery/domain/usecases/import_gallery_images_usecase.dart';
import '../../features/gallery/presentation/cubit/gallery_cubit.dart';
import '../../features/scanner/data/repositories/scanner_repository_impl.dart';
import '../../features/scanner/domain/repositories/scanner_repository.dart';
import '../../features/scanner/domain/usecases/import_gallery_usecase.dart';
import '../../features/scanner/domain/usecases/scan_document_usecase.dart';
import '../../features/scanner/domain/usecases/scan_documents_usecase.dart';
import '../../features/ocr/data/datasources/local_ocr_datasource.dart';
import '../../features/ocr/data/repositories/ocr_repository_impl.dart';
import '../../features/ocr/domain/repositories/ocr_repository.dart';
import '../../features/ocr/domain/usecases/ocr_usecases.dart';
import '../../features/ocr/presentation/cubit/ocr_cubit.dart';
import '../../features/document_editor/domain/entities/document_session.dart';
import '../../features/document_editor/domain/usecases/process_page_usecase.dart';
import '../../features/document_editor/domain/usecases/reorder_pages_usecase.dart';
import '../../features/document_editor/presentation/cubit/document_session_cubit.dart';
import '../../features/pdf_viewer/data/repositories/pdf_repository_impl.dart';
import '../../features/pdf_viewer/domain/repositories/pdf_repository.dart';
import '../../features/pdf_viewer/domain/usecases/delete_pdf_usecase.dart';
import '../../features/pdf_viewer/domain/usecases/generate_pdf_usecase.dart';
import '../../features/pdf_viewer/domain/usecases/rename_pdf_usecase.dart';
import '../../features/pdf_viewer/domain/usecases/share_pdf_usecase.dart';
import '../../features/pdf_viewer/presentation/cubit/pdf_cubit.dart';
import '../../features/pdf_viewer/presentation/cubit/pdf_preview_cubit.dart';
import '../../features/smart_document/data/datasources/local_recognition_datasource.dart';
import '../../features/smart_document/data/repositories/document_recognition_repository_impl.dart';
import '../../features/smart_document/data/services/document_classifier.dart';
import '../../features/smart_document/data/services/document_metadata_extractor.dart';
import '../../features/smart_document/data/services/document_recognition_service.dart';
import '../../features/smart_document/data/services/smart_filename_generator.dart';
import '../../features/smart_document/domain/repositories/document_recognition_repository.dart';
import '../../features/smart_document/domain/usecases/smart_document_usecases.dart';
import '../../features/smart_document/presentation/cubit/smart_document_cubit.dart';
import '../services/local_auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/security_service.dart';
import '../services/private_document_encryption_service.dart';
import '../services/feature_access_service.dart';
import '../../features/security/presentation/cubit/app_lock_cubit.dart';
import '../../features/subscription/data/datasources/purchases_datasource.dart';
import '../../features/subscription/data/datasources/revenuecat_purchases_datasource.dart';
import '../../features/subscription/data/repositories/subscription_repository_impl.dart';
import '../../features/subscription/domain/repositories/subscription_repository.dart';
import '../../features/subscription/domain/usecases/subscription_usecases.dart';
import '../../features/subscription/presentation/cubit/subscription_cubit.dart';
import '../routes/app_router.dart';

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
  GalleryRepository? customGalleryRepository,
  PdfRepository? customPdfRepository,
  OcrRepository? customOcrRepository,
  LocalOcrDataSource? customLocalOcrDataSource,
  DocumentRecognitionRepository? customDocumentRecognitionRepository,
  LocalRecognitionDataSource? customLocalRecognitionDataSource,
  SecureStorageService? customSecureStorageService,
  LocalAuthService? customLocalAuthService,
  SecurityService? customSecurityService,
  PrivateDocumentEncryptionService? customEncryptionService,
  PurchasesDataSource? customPurchasesDataSource,
  SubscriptionRepository? customSubscriptionRepository,
  FeatureAccessService? customFeatureAccessService,
  SubscriptionCubit? customSubscriptionCubit,
}) async {
  // Database
  if (customDatabase != null) {
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(customDatabase);
  } else if (!sl.isRegistered<AppDatabase>()) {
    sl.registerLazySingleton<AppDatabase>(() => AppDatabase());
  }

  // Core Platform & Storage Services
  if (customStorageService != null) {
    if (sl.isRegistered<FileStorageService>()) {
      await sl.unregister<FileStorageService>();
    }
    sl.registerSingleton<FileStorageService>(customStorageService);
  } else if (!sl.isRegistered<FileStorageService>()) {
    sl.registerLazySingleton<FileStorageService>(
      () => const FileStorageServiceImpl(),
    );
  }

  if (customImageService != null) {
    if (sl.isRegistered<ImageProcessingService>()) {
      await sl.unregister<ImageProcessingService>();
    }
    sl.registerSingleton<ImageProcessingService>(customImageService);
  } else if (!sl.isRegistered<ImageProcessingService>()) {
    sl.registerLazySingleton<ImageProcessingService>(
      () => const ImageProcessingServiceImpl(),
    );
  }

  if (customPdfService != null) {
    if (sl.isRegistered<PdfGeneratorService>()) {
      await sl.unregister<PdfGeneratorService>();
    }
    sl.registerSingleton<PdfGeneratorService>(customPdfService);
  } else if (!sl.isRegistered<PdfGeneratorService>()) {
    sl.registerLazySingleton<PdfGeneratorService>(
      () => const PdfGeneratorServiceImpl(),
    );
  }

  if (!sl.isRegistered<SearchablePdfService>()) {
    sl.registerLazySingleton<SearchablePdfService>(
      () => const SearchablePdfServiceImpl(),
    );
  }

  if (!sl.isRegistered<PreferencesService>()) {
    sl.registerLazySingleton<PreferencesService>(
      () => PreferencesServiceImpl(sl<AppDatabase>()),
    );
  }

  // Security & Hardware Auth Services
  if (customSecureStorageService != null) {
    if (sl.isRegistered<SecureStorageService>()) {
      await sl.unregister<SecureStorageService>();
    }
    sl.registerSingleton<SecureStorageService>(customSecureStorageService);
  } else if (!sl.isRegistered<SecureStorageService>()) {
    sl.registerLazySingleton<SecureStorageService>(
      () => SecureStorageServiceImpl(),
    );
  }

  if (customLocalAuthService != null) {
    if (sl.isRegistered<LocalAuthService>()) {
      await sl.unregister<LocalAuthService>();
    }
    sl.registerSingleton<LocalAuthService>(customLocalAuthService);
  } else if (!sl.isRegistered<LocalAuthService>()) {
    sl.registerLazySingleton<LocalAuthService>(() => LocalAuthServiceImpl());
  }

  if (customSecurityService != null) {
    if (sl.isRegistered<SecurityService>()) {
      await sl.unregister<SecurityService>();
    }
    sl.registerSingleton<SecurityService>(customSecurityService);
  } else if (!sl.isRegistered<SecurityService>()) {
    sl.registerLazySingleton<SecurityService>(
      () => SecurityServiceImpl(sl<SecureStorageService>()),
    );
  }

  if (customEncryptionService != null) {
    if (sl.isRegistered<PrivateDocumentEncryptionService>()) {
      await sl.unregister<PrivateDocumentEncryptionService>();
    }
    sl.registerSingleton<PrivateDocumentEncryptionService>(
      customEncryptionService,
    );
  } else if (!sl.isRegistered<PrivateDocumentEncryptionService>()) {
    sl.registerLazySingleton<PrivateDocumentEncryptionService>(
      () => PrivateDocumentEncryptionServiceImpl(sl<SecureStorageService>()),
    );
  }

  if (customScannerService != null) {
    if (sl.isRegistered<DocumentScannerService>()) {
      await sl.unregister<DocumentScannerService>();
    }
    sl.registerSingleton<DocumentScannerService>(customScannerService);
  } else if (!sl.isRegistered<DocumentScannerService>()) {
    sl.registerLazySingleton<DocumentScannerService>(
      () => DocumentScannerServiceImpl(),
    );
  }

  if (customGalleryService != null) {
    if (sl.isRegistered<GalleryService>()) {
      await sl.unregister<GalleryService>();
    }
    sl.registerSingleton<GalleryService>(customGalleryService);
  } else if (!sl.isRegistered<GalleryService>()) {
    sl.registerLazySingleton<GalleryService>(() => GalleryServiceImpl());
  }

  if (customShareService != null) {
    if (sl.isRegistered<ShareService>()) {
      await sl.unregister<ShareService>();
    }
    sl.registerSingleton<ShareService>(customShareService);
  } else if (!sl.isRegistered<ShareService>()) {
    sl.registerLazySingleton<ShareService>(
      () => ShareServiceImpl(
        securityService: sl.isRegistered<SecurityService>()
            ? sl<SecurityService>()
            : null,
      ),
    );
  }

  if (customOcrService != null) {
    if (sl.isRegistered<OcrService>()) {
      await sl.unregister<OcrService>();
    }
    sl.registerSingleton<OcrService>(customOcrService);
  } else if (!sl.isRegistered<OcrService>()) {
    sl.registerLazySingleton<OcrService>(
      () => (Platform.isAndroid || Platform.isIOS)
          ? MlKitOcrServiceImpl()
          : const StubOcrServiceImpl(),
    );
  }

  // Data Sources
  if (customLocalOcrDataSource != null) {
    if (sl.isRegistered<LocalOcrDataSource>()) {
      await sl.unregister<LocalOcrDataSource>();
    }
    sl.registerSingleton<LocalOcrDataSource>(customLocalOcrDataSource);
  } else if (!sl.isRegistered<LocalOcrDataSource>()) {
    sl.registerLazySingleton<LocalOcrDataSource>(
      () => LocalOcrDataSourceImpl(sl<AppDatabase>()),
    );
  }

  if (!sl.isRegistered<LocalDocumentDataSource>()) {
    sl.registerLazySingleton<LocalDocumentDataSource>(
      () => LocalDocumentDataSourceImpl(sl<AppDatabase>()),
    );
  }

  // Repositories
  if (customDocumentRepository != null) {
    if (sl.isRegistered<DocumentRepository>()) {
      await sl.unregister<DocumentRepository>();
    }
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
    if (sl.isRegistered<ScannerRepository>()) {
      await sl.unregister<ScannerRepository>();
    }
    sl.registerSingleton<ScannerRepository>(customScannerRepository);
  } else if (!sl.isRegistered<ScannerRepository>()) {
    sl.registerLazySingleton<ScannerRepository>(
      () => ScannerRepositoryImpl(
        scannerService: sl<DocumentScannerService>(),
        galleryService: sl<GalleryService>(),
      ),
    );
  }

  if (customGalleryRepository != null) {
    if (sl.isRegistered<GalleryRepository>()) {
      await sl.unregister<GalleryRepository>();
    }
    sl.registerSingleton<GalleryRepository>(customGalleryRepository);
  } else if (!sl.isRegistered<GalleryRepository>()) {
    sl.registerLazySingleton<GalleryRepository>(
      () => GalleryRepositoryImpl(
        galleryService: sl<GalleryService>(),
        fileStorageService: sl<FileStorageService>(),
        imageProcessingService: sl<ImageProcessingService>(),
      ),
    );
  }

  if (customPdfRepository != null) {
    if (sl.isRegistered<PdfRepository>()) {
      await sl.unregister<PdfRepository>();
    }
    sl.registerSingleton<PdfRepository>(customPdfRepository);
  } else if (!sl.isRegistered<PdfRepository>()) {
    sl.registerLazySingleton<PdfRepository>(
      () => PdfRepositoryImpl(
        pdfGeneratorService: sl<PdfGeneratorService>(),
        fileStorageService: sl<FileStorageService>(),
      ),
    );
  }

  if (customOcrRepository != null) {
    if (sl.isRegistered<OcrRepository>()) {
      await sl.unregister<OcrRepository>();
    }
    sl.registerSingleton<OcrRepository>(customOcrRepository);
  } else if (!sl.isRegistered<OcrRepository>()) {
    sl.registerLazySingleton<OcrRepository>(
      () => OcrRepositoryImpl(
        ocrService: sl<OcrService>(),
        localOcrDataSource: sl<LocalOcrDataSource>(),
        localDocumentDataSource: sl<LocalDocumentDataSource>(),
      ),
    );
  }

  // Use Cases
  if (!sl.isRegistered<ExtractDocumentTextUseCase>()) {
    sl.registerFactory(() => ExtractDocumentTextUseCase(sl<OcrRepository>()));
  }
  if (!sl.isRegistered<ExtractPageTextUseCase>()) {
    sl.registerFactory(() => ExtractPageTextUseCase(sl<OcrRepository>()));
  }
  if (!sl.isRegistered<GetDocumentOcrUseCase>()) {
    sl.registerFactory(() => GetDocumentOcrUseCase(sl<OcrRepository>()));
  }
  if (!sl.isRegistered<SearchDocumentTextUseCase>()) {
    sl.registerFactory(() => SearchDocumentTextUseCase(sl<OcrRepository>()));
  }
  if (!sl.isRegistered<SearchAllDocumentsUseCase>()) {
    sl.registerFactory(() => SearchAllDocumentsUseCase(sl<OcrRepository>()));
  }
  if (!sl.isRegistered<InvalidatePageOcrUseCase>()) {
    sl.registerFactory(() => InvalidatePageOcrUseCase(sl<OcrRepository>()));
  }
  if (!sl.isRegistered<OcrCubit>()) {
    sl.registerFactory(
      () => OcrCubit(
        extractDocumentTextUseCase: sl<ExtractDocumentTextUseCase>(),
        getDocumentOcrUseCase: sl<GetDocumentOcrUseCase>(),
        searchDocumentTextUseCase: sl<SearchDocumentTextUseCase>(),
      ),
    );
  }
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
  if (!sl.isRegistered<GetFilteredDocumentsUseCase>()) {
    sl.registerFactory(
      () => GetFilteredDocumentsUseCase(sl<DocumentRepository>()),
    );
  }
  if (!sl.isRegistered<GetDocumentCountsUseCase>()) {
    sl.registerFactory(
      () => GetDocumentCountsUseCase(sl<DocumentRepository>()),
    );
  }
  if (!sl.isRegistered<ToggleFavoriteUseCase>()) {
    sl.registerFactory(() => ToggleFavoriteUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<TogglePrivateUseCase>()) {
    sl.registerFactory(() => TogglePrivateUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<ArchiveDocumentUseCase>()) {
    sl.registerFactory(() => ArchiveDocumentUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<TrashDocumentUseCase>()) {
    sl.registerFactory(() => TrashDocumentUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<RestoreFromTrashUseCase>()) {
    sl.registerFactory(() => RestoreFromTrashUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<PermanentDeleteDocumentUseCase>()) {
    sl.registerFactory(
      () => PermanentDeleteDocumentUseCase(sl<DocumentRepository>()),
    );
  }
  if (!sl.isRegistered<RecordDocumentOpenedUseCase>()) {
    sl.registerFactory(
      () => RecordDocumentOpenedUseCase(sl<DocumentRepository>()),
    );
  }
  if (!sl.isRegistered<GetFoldersUseCase>()) {
    sl.registerFactory(() => GetFoldersUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<CreateFolderUseCase>()) {
    sl.registerFactory(() => CreateFolderUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<RenameFolderUseCase>()) {
    sl.registerFactory(() => RenameFolderUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<DeleteFolderUseCase>()) {
    sl.registerFactory(() => DeleteFolderUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<MoveDocumentToFolderUseCase>()) {
    sl.registerFactory(
      () => MoveDocumentToFolderUseCase(sl<DocumentRepository>()),
    );
  }
  if (!sl.isRegistered<GetTagsUseCase>()) {
    sl.registerFactory(() => GetTagsUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<CreateTagUseCase>()) {
    sl.registerFactory(() => CreateTagUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<DeleteTagUseCase>()) {
    sl.registerFactory(() => DeleteTagUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<AssignTagUseCase>()) {
    sl.registerFactory(() => AssignTagUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<RemoveTagUseCase>()) {
    sl.registerFactory(() => RemoveTagUseCase(sl<DocumentRepository>()));
  }
  if (!sl.isRegistered<BulkDocumentActionUseCase>()) {
    sl.registerFactory(
      () => BulkDocumentActionUseCase(sl<DocumentRepository>()),
    );
  }
  if (!sl.isRegistered<DocumentHistoryCubit>()) {
    sl.registerFactory(
      () => DocumentHistoryCubit(
        getDocumentsUseCase: sl<GetDocumentsUseCase>(),
        deleteDocumentUseCase: sl<DeleteDocumentUseCase>(),
        renameDocumentUseCase: sl<RenameDocumentUseCase>(),
        searchDocumentsUseCase: sl<SearchDocumentsUseCase>(),
        getFilteredDocumentsUseCase: sl<GetFilteredDocumentsUseCase>(),
        getDocumentCountsUseCase: sl<GetDocumentCountsUseCase>(),
        toggleFavoriteUseCase: sl<ToggleFavoriteUseCase>(),
        togglePrivateUseCase: sl<TogglePrivateUseCase>(),
        archiveDocumentUseCase: sl<ArchiveDocumentUseCase>(),
        trashDocumentUseCase: sl<TrashDocumentUseCase>(),
        restoreFromTrashUseCase: sl<RestoreFromTrashUseCase>(),
        permanentDeleteDocumentUseCase: sl<PermanentDeleteDocumentUseCase>(),
        recordDocumentOpenedUseCase: sl<RecordDocumentOpenedUseCase>(),
        getFoldersUseCase: sl<GetFoldersUseCase>(),
        createFolderUseCase: sl<CreateFolderUseCase>(),
        renameFolderUseCase: sl<RenameFolderUseCase>(),
        deleteFolderUseCase: sl<DeleteFolderUseCase>(),
        moveDocumentToFolderUseCase: sl<MoveDocumentToFolderUseCase>(),
        getTagsUseCase: sl<GetTagsUseCase>(),
        createTagUseCase: sl<CreateTagUseCase>(),
        deleteTagUseCase: sl<DeleteTagUseCase>(),
        assignTagUseCase: sl<AssignTagUseCase>(),
        removeTagUseCase: sl<RemoveTagUseCase>(),
        bulkDocumentActionUseCase: sl<BulkDocumentActionUseCase>(),
        preferencesService: sl<PreferencesService>(),
      ),
    );
  }
  if (!sl.isRegistered<ScanDocumentUseCase>()) {
    sl.registerFactory(
      () => ScanDocumentUseCase(sl<DocumentScannerRepository>()),
    );
  }
  if (!sl.isRegistered<ScanDocumentsUseCase>()) {
    sl.registerFactory(() => ScanDocumentsUseCase(sl<ScannerRepository>()));
  }
  if (!sl.isRegistered<ImportGalleryUseCase>()) {
    sl.registerFactory(() => ImportGalleryUseCase(sl<ScannerRepository>()));
  }
  if (!sl.isRegistered<ImportGalleryImagesUseCase>()) {
    sl.registerFactory(
      () => ImportGalleryImagesUseCase(sl<GalleryRepository>()),
    );
  }
  if (!sl.isRegistered<GalleryCubit>()) {
    sl.registerFactory(
      () => GalleryCubit(
        importGalleryImagesUseCase: sl<ImportGalleryImagesUseCase>(),
      ),
    );
  }
  if (!sl.isRegistered<EditScanPageUseCase>()) {
    sl.registerFactory(
      () => EditScanPageUseCase(
        imageProcessingService: sl<ImageProcessingService>(),
        fileStorageService: sl<FileStorageService>(),
      ),
    );
  }
  if (!sl.isRegistered<ProcessPageUseCase>()) {
    sl.registerFactory(
      () => ProcessPageUseCase(
        imageProcessingService: sl<ImageProcessingService>(),
        fileStorageService: sl<FileStorageService>(),
      ),
    );
  }
  if (!sl.isRegistered<ReorderPagesUseCase>()) {
    sl.registerFactory(() => const ReorderPagesUseCase());
  }
  if (!sl.isRegistered<DocumentSessionCubit>()) {
    sl.registerFactoryParam<DocumentSessionCubit, DocumentSession, void>(
      (session, _) => DocumentSessionCubit(
        fileStorageService: sl<FileStorageService>(),
        imageProcessingService: sl<ImageProcessingService>(),
        editScanPageUseCase: sl<EditScanPageUseCase>(),
        reorderPagesUseCase: sl<ReorderPagesUseCase>(),
        initialSession: session,
      ),
    );
  }
  if (!sl.isRegistered<GeneratePdfUseCase>()) {
    sl.registerFactory(
      () => GeneratePdfUseCase(
        pdfRepository: sl<PdfRepository>(),
        fileStorageService: sl<FileStorageService>(),
        imageProcessingService: sl<ImageProcessingService>(),
      ),
    );
  }
  if (!sl.isRegistered<PdfCubit>()) {
    sl.registerFactory(
      () => PdfCubit(generatePdfUseCase: sl<GeneratePdfUseCase>()),
    );
  }
  if (!sl.isRegistered<SharePdfUseCase>()) {
    sl.registerFactory(
      () => SharePdfUseCase(sl<ShareService>(), sl<FileStorageService>()),
    );
  }
  if (!sl.isRegistered<RenamePdfUseCase>()) {
    sl.registerFactory(
      () => RenamePdfUseCase(documentRepository: sl<DocumentRepository>()),
    );
  }
  if (!sl.isRegistered<DeletePdfUseCase>()) {
    sl.registerFactory(
      () => DeletePdfUseCase(
        fileStorageService: sl<FileStorageService>(),
        documentRepository: sl<DocumentRepository>(),
      ),
    );
  }
  if (!sl.isRegistered<PdfPreviewCubit>()) {
    sl.registerFactoryParam<PdfPreviewCubit, PdfPreviewArgs, void>(
      (args, _) => PdfPreviewCubit(
        generatePdfUseCase: sl<GeneratePdfUseCase>(),
        sharePdfUseCase: sl<SharePdfUseCase>(),
        saveDocumentUseCase: sl<SaveDocumentUseCase>(),
        renamePdfUseCase: sl<RenamePdfUseCase>(),
        deletePdfUseCase: sl<DeletePdfUseCase>(),
        documentId: args.documentId,
        title: args.title,
        pages: args.pages,
        existingPdfPath: args.existingPdfPath,
      ),
    );
  }

  // Smart Document Recognition Services & Repository
  if (!sl.isRegistered<DocumentClassifier>()) {
    sl.registerLazySingleton<DocumentClassifier>(
      () => const DocumentClassifier(),
    );
  }
  if (!sl.isRegistered<DocumentMetadataExtractor>()) {
    sl.registerLazySingleton<DocumentMetadataExtractor>(
      () => const DocumentMetadataExtractor(),
    );
  }
  if (!sl.isRegistered<SmartFilenameGenerator>()) {
    sl.registerLazySingleton<SmartFilenameGenerator>(
      () => const SmartFilenameGenerator(),
    );
  }
  if (!sl.isRegistered<DocumentRecognitionService>()) {
    sl.registerLazySingleton<DocumentRecognitionService>(
      () => DocumentRecognitionService(
        classifier: sl<DocumentClassifier>(),
        metadataExtractor: sl<DocumentMetadataExtractor>(),
        filenameGenerator: sl<SmartFilenameGenerator>(),
      ),
    );
  }

  if (customLocalRecognitionDataSource != null) {
    if (sl.isRegistered<LocalRecognitionDataSource>()) {
      await sl.unregister<LocalRecognitionDataSource>();
    }
    sl.registerSingleton<LocalRecognitionDataSource>(
      customLocalRecognitionDataSource,
    );
  } else if (!sl.isRegistered<LocalRecognitionDataSource>()) {
    sl.registerLazySingleton<LocalRecognitionDataSource>(
      () => LocalRecognitionDataSourceImpl(sl<AppDatabase>()),
    );
  }

  if (customDocumentRecognitionRepository != null) {
    if (sl.isRegistered<DocumentRecognitionRepository>()) {
      await sl.unregister<DocumentRecognitionRepository>();
    }
    sl.registerSingleton<DocumentRecognitionRepository>(
      customDocumentRecognitionRepository,
    );
  } else if (!sl.isRegistered<DocumentRecognitionRepository>()) {
    sl.registerLazySingleton<DocumentRecognitionRepository>(
      () => DocumentRecognitionRepositoryImpl(
        recognitionService: sl<DocumentRecognitionService>(),
        localDataSource: sl<LocalRecognitionDataSource>(),
        getDocumentOcrUseCase: sl<GetDocumentOcrUseCase>(),
        filenameGenerator: sl<SmartFilenameGenerator>(),
      ),
    );
  }

  // Smart Document Use Cases
  if (!sl.isRegistered<RecognizeDocumentUseCase>()) {
    sl.registerFactory(
      () => RecognizeDocumentUseCase(sl<DocumentRecognitionRepository>()),
    );
  }
  if (!sl.isRegistered<GetDocumentRecognitionUseCase>()) {
    sl.registerFactory(
      () => GetDocumentRecognitionUseCase(sl<DocumentRecognitionRepository>()),
    );
  }
  if (!sl.isRegistered<OverrideDocumentTypeUseCase>()) {
    sl.registerFactory(
      () => OverrideDocumentTypeUseCase(sl<DocumentRecognitionRepository>()),
    );
  }
  if (!sl.isRegistered<UpdateDocumentMetadataUseCase>()) {
    sl.registerFactory(
      () => UpdateDocumentMetadataUseCase(sl<DocumentRecognitionRepository>()),
    );
  }
  if (!sl.isRegistered<SuggestDocumentNameUseCase>()) {
    sl.registerFactory(
      () => SuggestDocumentNameUseCase(sl<DocumentRecognitionRepository>()),
    );
  }

  if (!sl.isRegistered<SmartDocumentCubit>()) {
    sl.registerFactory(
      () => SmartDocumentCubit(
        recognizeDocumentUseCase: sl<RecognizeDocumentUseCase>(),
        getDocumentRecognitionUseCase: sl<GetDocumentRecognitionUseCase>(),
        overrideDocumentTypeUseCase: sl<OverrideDocumentTypeUseCase>(),
        updateDocumentMetadataUseCase: sl<UpdateDocumentMetadataUseCase>(),
        suggestDocumentNameUseCase: sl<SuggestDocumentNameUseCase>(),
      ),
    );
  }

  // Security & App Lock Cubit
  if (!sl.isRegistered<AppLockCubit>()) {
    sl.registerLazySingleton<AppLockCubit>(
      () => AppLockCubit(
        securityService: sl<SecurityService>(),
        localAuthService: sl<LocalAuthService>(),
      ),
    );
  }

  // Monetization & Subscription (Phase 15)
  if (customPurchasesDataSource != null) {
    if (sl.isRegistered<PurchasesDataSource>()) {
      await sl.unregister<PurchasesDataSource>();
    }
    sl.registerSingleton<PurchasesDataSource>(customPurchasesDataSource);
  } else if (!sl.isRegistered<PurchasesDataSource>()) {
    sl.registerLazySingleton<PurchasesDataSource>(
      () => RevenueCatPurchasesDataSource(),
    );
  }

  if (customSubscriptionRepository != null) {
    if (sl.isRegistered<SubscriptionRepository>()) {
      await sl.unregister<SubscriptionRepository>();
    }
    sl.registerSingleton<SubscriptionRepository>(customSubscriptionRepository);
  } else if (!sl.isRegistered<SubscriptionRepository>()) {
    sl.registerLazySingleton<SubscriptionRepository>(
      () => SubscriptionRepositoryImpl(
        purchasesDataSource: sl<PurchasesDataSource>(),
        secureStorageService: sl<SecureStorageService>(),
      ),
    );
  }

  // Subscription Use Cases
  if (!sl.isRegistered<GetSubscriptionInfoUseCase>()) {
    sl.registerFactory(
      () => GetSubscriptionInfoUseCase(sl<SubscriptionRepository>()),
    );
  }
  if (!sl.isRegistered<GetSubscriptionProductsUseCase>()) {
    sl.registerFactory(
      () => GetSubscriptionProductsUseCase(sl<SubscriptionRepository>()),
    );
  }
  if (!sl.isRegistered<PurchaseProductUseCase>()) {
    sl.registerFactory(
      () => PurchaseProductUseCase(sl<SubscriptionRepository>()),
    );
  }
  if (!sl.isRegistered<RestorePurchasesUseCase>()) {
    sl.registerFactory(
      () => RestorePurchasesUseCase(sl<SubscriptionRepository>()),
    );
  }

  // Feature Access Service
  if (customFeatureAccessService != null) {
    if (sl.isRegistered<FeatureAccessService>()) {
      await sl.unregister<FeatureAccessService>();
    }
    sl.registerSingleton<FeatureAccessService>(customFeatureAccessService);
  } else if (!sl.isRegistered<FeatureAccessService>()) {
    sl.registerLazySingleton<FeatureAccessService>(
      () => FeatureAccessServiceImpl(
        subscriptionRepository: sl<SubscriptionRepository>(),
      ),
    );
  }

  // Subscription Cubit
  if (customSubscriptionCubit != null) {
    if (sl.isRegistered<SubscriptionCubit>()) {
      await sl.unregister<SubscriptionCubit>();
    }
    sl.registerSingleton<SubscriptionCubit>(customSubscriptionCubit);
  } else if (!sl.isRegistered<SubscriptionCubit>()) {
    sl.registerLazySingleton<SubscriptionCubit>(
      () => SubscriptionCubit(
        getSubscriptionInfoUseCase: sl<GetSubscriptionInfoUseCase>(),
        getSubscriptionProductsUseCase: sl<GetSubscriptionProductsUseCase>(),
        purchaseProductUseCase: sl<PurchaseProductUseCase>(),
        restorePurchasesUseCase: sl<RestorePurchasesUseCase>(),
        externalUpdatesStream: sl<SubscriptionRepository>().subscriptionUpdates,
      ),
    );
  }
}
