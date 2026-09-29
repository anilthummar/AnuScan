import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/features/subscription/domain/entities/purchase_result.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_product.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_status.dart';
import 'package:anuscan/features/subscription/domain/usecases/subscription_usecases.dart';
import 'package:anuscan/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:anuscan/features/subscription/presentation/screens/premium_screen.dart';

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
      title: 'Monthly Plan',
      description: 'Flexible monthly billing',
      priceString: r'$4.99',
      price: 4.99,
      currencyCode: 'USD',
      duration: ProductDuration.monthly,
    ),
    SubscriptionProduct(
      id: 'anuscan_pro_yearly',
      title: 'Annual Plan',
      description: '7-day free trial included',
      priceString: r'$29.99',
      price: 29.99,
      currencyCode: 'USD',
      duration: ProductDuration.yearly,
      freeTrialPeriod: '7-day free trial',
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

  Widget buildTestWidget() {
    return MaterialApp(
      home: PremiumScreen(customCubit: cubit),
    );
  }

  group('PremiumScreen Widget Tests', () {
    testWidgets('renders paywall header, benefits, restore button, and pricing cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify Restore action in AppBar
      expect(find.text('Restore'), findsOneWidget);

      // Verify Header
      expect(find.text('AnuScan Pro'), findsAtLeastNWidgets(1));

      // Verify Product Cards
      expect(find.text('Annual Plan'), findsOneWidget);
      expect(find.text('Monthly Plan'), findsOneWidget);
      expect(find.text(r'$29.99'), findsOneWidget);
      expect(find.text(r'$4.99'), findsOneWidget);

      // Verify Subscribe CTA button
      expect(find.textContaining('Start 7-day free trial'), findsOneWidget);

      // Verify Legal footer links
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('tapping product card switches active selection and CTA text', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially Annual is selected with trial text
      expect(find.textContaining('Start 7-day free trial'), findsOneWidget);

      // Tap Monthly card
      await tester.tap(find.text('Monthly Plan'));
      await tester.pumpAndSettle();

      // CTA text updates to Continue with Monthly Plan
      expect(find.textContaining('Continue with Monthly Plan'), findsOneWidget);
    });

    testWidgets('tapping Restore invokes restorePurchases', (tester) async {
      when(() => mockRestore())
          .thenAnswer((_) async => PurchaseResult.success(SubscriptionInfo.free()));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore'));
      await tester.pump();

      verify(() => mockRestore()).called(1);
    });
  });
}
