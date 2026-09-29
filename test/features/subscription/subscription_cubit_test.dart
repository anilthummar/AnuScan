import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/features/subscription/domain/entities/purchase_result.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_product.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_status.dart';
import 'package:anuscan/features/subscription/domain/usecases/subscription_usecases.dart';
import 'package:anuscan/features/subscription/presentation/cubit/subscription_cubit.dart';

class MockGetSubscriptionInfoUseCase extends Mock implements GetSubscriptionInfoUseCase {}
class MockGetSubscriptionProductsUseCase extends Mock implements GetSubscriptionProductsUseCase {}
class MockPurchaseProductUseCase extends Mock implements PurchaseProductUseCase {}
class MockRestorePurchasesUseCase extends Mock implements RestorePurchasesUseCase {}

void main() {
  late MockGetSubscriptionInfoUseCase mockGetInfo;
  late MockGetSubscriptionProductsUseCase mockGetProducts;
  late MockPurchaseProductUseCase mockPurchase;
  late MockRestorePurchasesUseCase mockRestore;
  late SubscriptionCubit cubit;

  const sampleProducts = [
    SubscriptionProduct(
      id: 'anuscan_pro_monthly',
      title: 'Monthly',
      description: 'Monthly sub',
      priceString: r'$4.99',
      price: 4.99,
      currencyCode: 'USD',
      duration: ProductDuration.monthly,
    ),
    SubscriptionProduct(
      id: 'anuscan_pro_yearly',
      title: 'Yearly',
      description: 'Annual sub with trial',
      priceString: r'$29.99',
      price: 29.99,
      currencyCode: 'USD',
      duration: ProductDuration.yearly,
      isBestValue: true,
    ),
  ];

  setUp(() {
    mockGetInfo = MockGetSubscriptionInfoUseCase();
    mockGetProducts = MockGetSubscriptionProductsUseCase();
    mockPurchase = MockPurchaseProductUseCase();
    mockRestore = MockRestorePurchasesUseCase();

    when(() => mockGetInfo(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => SubscriptionInfo.free());
    when(() => mockGetProducts()).thenAnswer((_) async => sampleProducts);

    cubit = SubscriptionCubit(
      getSubscriptionInfoUseCase: mockGetInfo,
      getSubscriptionProductsUseCase: mockGetProducts,
      purchaseProductUseCase: mockPurchase,
      restorePurchasesUseCase: mockRestore,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('SubscriptionCubit Tests', () {
    test('initial state has free tier, empty products, and is loading', () {
      expect(cubit.state.isPremium, isFalse);
      expect(cubit.state.isLoading, isTrue);
      expect(cubit.state.products, isEmpty);
    });

    test('loadSubscription loads info, products, and selects best-value product', () async {
      await cubit.loadSubscription();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.products.length, equals(2));
      expect(cubit.state.selectedProductId, equals('anuscan_pro_yearly'));
      expect(cubit.state.selectedProduct?.isBestValue, isTrue);
    });

    test('selectProduct updates selectedProductId', () async {
      await cubit.loadSubscription();
      cubit.selectProduct('anuscan_pro_monthly');

      expect(cubit.state.selectedProductId, equals('anuscan_pro_monthly'));
    });

    test('purchase succeeds and activates Pro with welcome message', () async {
      await cubit.loadSubscription();

      final proInfo = SubscriptionInfo.premium(
        activeProductId: 'anuscan_pro_yearly',
        expirationDate: DateTime.now().add(const Duration(days: 365)),
      );

      when(() => mockPurchase('anuscan_pro_yearly'))
          .thenAnswer((_) async => PurchaseResult.success(proInfo));

      await cubit.purchase('anuscan_pro_yearly');

      expect(cubit.state.isPurchasing, isFalse);
      expect(cubit.state.isPremium, isTrue);
      expect(cubit.state.successMessage, equals('Welcome to AnuScan Pro!'));
    });

    test('purchase cancellation resets purchasing state without setting error', () async {
      await cubit.loadSubscription();

      when(() => mockPurchase(any())).thenAnswer((_) async => PurchaseResult.cancelled());

      await cubit.purchase('anuscan_pro_yearly');

      expect(cubit.state.isPurchasing, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isPremium, isFalse);
    });

    test('purchase failure sets errorMessage', () async {
      await cubit.loadSubscription();

      when(() => mockPurchase(any()))
          .thenAnswer((_) async => PurchaseResult.error('Payment declined'));

      await cubit.purchase('anuscan_pro_yearly');

      expect(cubit.state.isPurchasing, isFalse);
      expect(cubit.state.errorMessage, equals('Payment declined'));
    });

    test('restorePurchases restores Pro entitlement successfully', () async {
      final proInfo = SubscriptionInfo.premium(
        activeProductId: 'anuscan_pro_lifetime',
      );

      when(() => mockRestore())
          .thenAnswer((_) async => PurchaseResult.success(proInfo));

      await cubit.restorePurchases();

      expect(cubit.state.isRestoring, isFalse);
      expect(cubit.state.isPremium, isTrue);
      expect(cubit.state.successMessage, contains('restored'));
    });

    test('restorePurchases notifies user when no active purchases found', () async {
      when(() => mockRestore())
          .thenAnswer((_) async => PurchaseResult.success(SubscriptionInfo.free()));

      await cubit.restorePurchases();

      expect(cubit.state.isRestoring, isFalse);
      expect(cubit.state.isPremium, isFalse);
      expect(cubit.state.errorMessage, contains('No active subscription found'));
    });
  });
}
