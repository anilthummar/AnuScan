import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anuscan/core/database/app_database.dart';
import 'package:anuscan/core/services/feature_access_service.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/secure_storage_service.dart';
import 'package:anuscan/core/services/security_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_history/data/datasources/local_document_datasource.dart';
import 'package:anuscan/features/document_history/data/repositories/document_repository_impl.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_status.dart';
import 'package:anuscan/features/subscription/domain/repositories/subscription_repository.dart';

class MockFileStorageService extends Mock implements FileStorageService {}
class MockSubscriptionRepository extends Mock implements SubscriptionRepository {}

class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<void> write(String key, String value) async => _storage[key] = value;

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> delete(String key) async => _storage.remove(key);

  @override
  Future<void> clear() async => _storage.clear();

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDatabase;
  late LocalDocumentDataSource documentDataSource;
  late MockFileStorageService mockStorageService;
  late DocumentRepositoryImpl documentRepository;

  late InMemorySecureStorageService secureStorage;
  late SecurityServiceImpl securityService;

  late MockSubscriptionRepository mockSubscriptionRepo;
  late StreamController<SubscriptionInfo> subscriptionStream;
  late FeatureAccessServiceImpl featureAccessService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);

    appDatabase = AppDatabase(initialDatabase: db);
    documentDataSource = LocalDocumentDataSourceImpl(appDatabase);
    mockStorageService = MockFileStorageService();
    documentRepository = DocumentRepositoryImpl(
      localDataSource: documentDataSource,
      fileStorageService: mockStorageService,
    );

    secureStorage = InMemorySecureStorageService();
    securityService = SecurityServiceImpl(secureStorage);

    mockSubscriptionRepo = MockSubscriptionRepository();
    subscriptionStream = StreamController<SubscriptionInfo>.broadcast();
    when(() => mockSubscriptionRepo.subscriptionUpdates).thenAnswer((_) => subscriptionStream.stream);

    featureAccessService = FeatureAccessServiceImpl(
      subscriptionRepository: mockSubscriptionRepo,
      isMonetizationHidden: false,
    );
  });

  tearDown(() async {
    await db.close();
    subscriptionStream.close();
  });

  group('Phase 15 Zero Document Lockout on Downgrade Tests', () {
    test(
      'Documents created while Pro remain 100% accessible, editable, and private when downgraded to Free',
      () async {
        // Step 1: User is Pro
        final proInfo = SubscriptionInfo.premium(
          activeProductId: 'anuscan_pro_yearly',
          expirationDate: DateTime.now().add(const Duration(days: 365)),
        );
        featureAccessService.updateSubscriptionInfo(proInfo);
        expect(featureAccessService.isPremium, isTrue);
        expect(featureAccessService.canUse(PremiumFeature.advancedPdfExport), isTrue);
        expect(featureAccessService.canUse(PremiumFeature.batchPdfExport), isTrue);

        // Step 2: Configure App Lock & Security while Pro
        await securityService.setPin('4321');
        await securityService.setBiometricsEnabled(true);
        expect(await securityService.isAppLockEnabled(), isTrue);

        // Step 3: Create documents while Pro
        final now = DateTime.now();

        // Doc 1: Regular multi-page scan with pages
        final doc1 = DocumentEntity(
          id: 'pro_doc_standard',
          title: 'Tax Declaration 2026',
          pdfPath: '/storage/tax_2026.pdf',
          pageCount: 3,
          fileSizeBytes: 204800,
          createdAt: now,
          updatedAt: now,
          pages: [
            ScannedPage(
              id: 'page_1',
              documentId: 'pro_doc_standard',
              pageIndex: 0,
              originalImagePath: '/img/p1.jpg',
              processedImagePath: '/img/p1_proc.jpg',
              createdAt: now,
            ),
            ScannedPage(
              id: 'page_2',
              documentId: 'pro_doc_standard',
              pageIndex: 1,
              originalImagePath: '/img/p2.jpg',
              processedImagePath: '/img/p2_proc.jpg',
              createdAt: now,
            ),
          ],
        );

        // Doc 2: Private document with sensitive flag
        final doc2 = DocumentEntity(
          id: 'pro_doc_private',
          title: 'Confidential Medical Records',
          pdfPath: '/storage/medical.pdf',
          pageCount: 1,
          fileSizeBytes: 102400,
          createdAt: now,
          updatedAt: now,
          isPrivate: true,
        );

        await documentRepository.saveDocument(doc1);
        await documentRepository.saveDocument(doc2);

        // Verify both documents exist
        final initialDocs = await documentRepository.getAllDocuments();
        expect(initialDocs.length, equals(2));

        // Step 4: SUBSCRIPTION EXPIRES / DOWNGRADES TO FREE
        final freeInfo = SubscriptionInfo.free();
        subscriptionStream.add(freeInfo);
        featureAccessService.updateSubscriptionInfo(freeInfo);
        await pumpEventQueue();

        // Verify subscription state is now Free
        expect(featureAccessService.isPremium, isFalse);
        expect(featureAccessService.canUse(PremiumFeature.advancedPdfExport), isFalse);
        expect(featureAccessService.canUse(PremiumFeature.batchPdfExport), isFalse);

        // Step 5: VERIFY ZERO DOCUMENT LOCKOUT
        // 5a. Documents are NOT deleted
        final docsAfterDowngrade = await documentRepository.getAllDocuments();
        expect(docsAfterDowngrade.length, equals(2));

        // 5b. Document 1 is fully readable with all scanned pages
        final retrievedDoc1 = await documentRepository.getDocumentById('pro_doc_standard');
        expect(retrievedDoc1, isNotNull);
        expect(retrievedDoc1!.title, equals('Tax Declaration 2026'));
        expect(retrievedDoc1.pdfPath, equals('/storage/tax_2026.pdf'));
        expect(retrievedDoc1.pages.length, equals(2));
        expect(retrievedDoc1.pages.first.originalImagePath, equals('/img/p1.jpg'));

        // 5c. Private Document retains private status & is completely intact
        final retrievedDoc2 = await documentRepository.getDocumentById('pro_doc_private');
        expect(retrievedDoc2, isNotNull);
        expect(retrievedDoc2!.title, equals('Confidential Medical Records'));
        expect(retrievedDoc2.isPrivate, isTrue);

        // 5d. Search continues to function without restriction
        final searchResults = await documentRepository.searchDocuments('Tax');
        expect(searchResults.length, equals(1));
        expect(searchResults.first.id, equals('pro_doc_standard'));

        // 5e. User can still edit/rename documents
        await documentRepository.renameDocument('pro_doc_standard', 'Renamed Tax Declaration');
        final renamedDoc = await documentRepository.getDocumentById('pro_doc_standard');
        expect(renamedDoc!.title, equals('Renamed Tax Declaration'));

        // 5f. User can soft-delete and restore documents
        await documentRepository.deleteDocument('pro_doc_standard');
        final afterTrash = await documentRepository.getDocumentById('pro_doc_standard');
        expect(afterTrash!.isDeleted, isTrue);

        await documentRepository.restoreFromTrash('pro_doc_standard');
        final afterRestore = await documentRepository.getDocumentById('pro_doc_standard');
        expect(afterRestore!.isDeleted, isFalse);

        // 5g. App Lock and PIN credentials remain 100% active and functional
        expect(await securityService.isAppLockEnabled(), isTrue);
        expect(await securityService.verifyPin('4321'), isTrue);
        expect(await securityService.verifyPin('0000'), isFalse);
        expect(await securityService.isBiometricsEnabled(), isTrue);
      },
    );
  });
}
