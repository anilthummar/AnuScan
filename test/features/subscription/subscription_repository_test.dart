import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/constants/premium_constants.dart';
import 'package:anuscan/core/services/secure_storage_service.dart';
import 'package:anuscan/features/subscription/data/datasources/purchases_datasource.dart';
import 'package:anuscan/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:anuscan/features/subscription/domain/entities/purchase_result.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_product.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_status.dart';

class MockPurchasesDataSource extends Mock implements PurchasesDataSource {}

class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }
}

void main() {
  late MockPurchasesDataSource mockDataSource;
  late InMemorySecureStorageService secureStorage;
  late StreamController<SubscriptionInfo> customerInfoController;
  late SubscriptionRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockPurchasesDataSource();
    secureStorage = InMemorySecureStorageService();
    customerInfoController = StreamController<SubscriptionInfo>.broadcast();

    when(() => mockDataSource.customerInfoStream).thenAnswer((_) => customerInfoController.stream);

    repository = SubscriptionRepositoryImpl(
      purchasesDataSource: mockDataSource,
      secureStorageService: secureStorage,
    );
  });

  tearDown(() {
    customerInfoController.close();
  });

  group('SubscriptionRepositoryImpl Tests', () {
    test('getSubscriptionInfo queries data source and caches into secure storage', () async {
      final proInfo = SubscriptionInfo.premium(
        activeProductId: 'anuscan_pro_monthly',
        expirationDate: DateTime.now().add(const Duration(days: 30)),
      );

      when(() => mockDataSource.getCustomerSubscriptionInfo()).thenAnswer((_) async => proInfo);

      final result = await repository.getSubscriptionInfo(forceRefresh: true);

      expect(result.isPremium, isTrue);
      expect(result.activeProductId, equals('anuscan_pro_monthly'));

      // Check secure storage cache
      final cachedStr = await secureStorage.read(PremiumConstants.cachedEntitlementKey);
      expect(cachedStr, isNotNull);
      expect(cachedStr, contains('premium'));
    });

    test('getSubscriptionInfo falls back to secure storage cache when store is unreachable (offline)', () async {
      // Pre-populate secure cache
      await secureStorage.write(
        PremiumConstants.cachedEntitlementKey,
        '{"tier":"premium","activeProductId":"anuscan_pro_yearly","isSandbox":false}',
      );

      // Store throws offline exception
      when(() => mockDataSource.getCustomerSubscriptionInfo()).thenThrow(Exception('No network connection'));

      final result = await repository.getSubscriptionInfo(forceRefresh: true);

      expect(result.isPremium, isTrue);
      expect(result.activeProductId, equals('anuscan_pro_yearly'));
    });

    test('getSubscriptionInfo defaults to free when store fails and no cache exists', () async {
      when(() => mockDataSource.getCustomerSubscriptionInfo()).thenThrow(Exception('Network error'));

      final result = await repository.getSubscriptionInfo(forceRefresh: true);

      expect(result.isPremium, isFalse);
      expect(result.tier, equals(SubscriptionTier.free));
    });

    test('getProducts delegates to data source getOfferings', () async {
      const mockProducts = [
        SubscriptionProduct(
          id: 'anuscan_pro_monthly',
          title: 'Monthly',
          description: 'Monthly sub',
          priceString: r'$4.99',
          price: 4.99,
          currencyCode: 'USD',
          duration: ProductDuration.monthly,
        ),
      ];

      when(() => mockDataSource.getOfferings()).thenAnswer((_) async => mockProducts);

      final products = await repository.getProducts();

      expect(products.length, equals(1));
      expect(products.first.id, equals('anuscan_pro_monthly'));
    });

    test('purchaseProduct delegates to data source and updates cache on success', () async {
      final proInfo = SubscriptionInfo.premium(activeProductId: 'anuscan_pro_monthly');
      when(() => mockDataSource.purchase('anuscan_pro_monthly'))
          .thenAnswer((_) async => PurchaseResult.success(proInfo));

      final result = await repository.purchaseProduct('anuscan_pro_monthly');

      expect(result.isSuccess, isTrue);
      expect(result.subscriptionInfo?.isPremium, isTrue);

      final cached = await secureStorage.read(PremiumConstants.cachedEntitlementKey);
      expect(cached, isNotNull);
    });

    test('restorePurchases delegates to data source', () async {
      final proInfo = SubscriptionInfo.premium(activeProductId: 'anuscan_pro_lifetime');
      when(() => mockDataSource.restore())
          .thenAnswer((_) async => PurchaseResult.success(proInfo));

      final result = await repository.restorePurchases();

      expect(result.isSuccess, isTrue);
      expect(result.subscriptionInfo?.isPremium, isTrue);
    });
  });
}
