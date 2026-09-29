import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_status.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_product.dart';
import 'package:anuscan/features/subscription/domain/entities/purchase_result.dart';

void main() {
  group('SubscriptionStatus & SubscriptionInfo Domain Tests', () {
    test('SubscriptionInfo.free defaults to free tier and inactive status', () {
      final freeInfo = SubscriptionInfo.free();

      expect(freeInfo.tier, equals(SubscriptionTier.free));
      expect(freeInfo.isPremium, isFalse);
      expect(freeInfo.isLifetime, isFalse);
      expect(freeInfo.expirationDate, isNull);
      expect(freeInfo.activeProductId, isNull);
      expect(freeInfo.willRenew, isFalse);
    });

    test('SubscriptionInfo pro active with expiration date', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final proInfo = SubscriptionInfo.premium(
        activeProductId: 'anuscan_pro_monthly',
        expirationDate: futureDate,
        store: StoreType.googlePlay,
        willRenew: true,
      );

      expect(proInfo.isPremium, isTrue);
      expect(proInfo.tier, equals(SubscriptionTier.premium));
      expect(proInfo.isLifetime, isFalse);
      expect(proInfo.expirationDate, equals(futureDate));
      expect(proInfo.store, equals(StoreType.googlePlay));
      expect(proInfo.willRenew, isTrue);
    });

    test('SubscriptionInfo lifetime pro has no expiration and isLifetime=true', () {
      final lifetimeInfo = SubscriptionInfo.premium(
        activeProductId: 'anuscan_pro_lifetime',
        expirationDate: null,
        store: StoreType.appStore,
      );

      expect(lifetimeInfo.isPremium, isTrue);
      expect(lifetimeInfo.isLifetime, isTrue);
      expect(lifetimeInfo.expirationDate, isNull);
    });

    test('SubscriptionInfo toJson and fromJson serialize symmetrically', () {
      final date = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final original = SubscriptionInfo.premium(
        activeProductId: 'anuscan_pro_yearly',
        expirationDate: date,
        store: StoreType.googlePlay,
        willRenew: true,
      );

      final json = original.toJson();
      final restored = SubscriptionInfo.fromJson(json);

      expect(restored.tier, equals(original.tier));
      expect(restored.isPremium, equals(original.isPremium));
      expect(restored.activeProductId, equals(original.activeProductId));
      expect(restored.store, equals(original.store));
      expect(restored.willRenew, equals(original.willRenew));
      expect(restored.isLifetime, equals(original.isLifetime));
      expect(restored.expirationDate?.toIso8601String(), equals(date.toIso8601String()));
    });
  });

  group('SubscriptionProduct Tests', () {
    test('SubscriptionProduct properties and duration labels', () {
      const trialProduct = SubscriptionProduct(
        id: 'anuscan_pro_yearly',
        title: 'AnuScan Pro Yearly',
        description: 'Unlimited documents, OCR batch, and smart tools',
        priceString: r'$29.99',
        price: 29.99,
        currencyCode: 'USD',
        duration: ProductDuration.yearly,
        freeTrialPeriod: '7-day free trial',
        isBestValue: true,
      );

      expect(trialProduct.duration, equals(ProductDuration.yearly));
      expect(trialProduct.durationLabel, equals('Annual'));
      expect(trialProduct.billingPeriodLabel, equals('/ year'));
      expect(trialProduct.priceString, equals(r'$29.99'));
      expect(trialProduct.freeTrialPeriod, equals('7-day free trial'));
      expect(trialProduct.isBestValue, isTrue);

      const lifetimeProduct = SubscriptionProduct(
        id: 'anuscan_pro_lifetime',
        title: 'AnuScan Pro Lifetime',
        description: 'Pay once, keep forever',
        priceString: r'$59.99',
        price: 59.99,
        currencyCode: 'USD',
        duration: ProductDuration.lifetime,
      );

      expect(lifetimeProduct.duration, equals(ProductDuration.lifetime));
      expect(lifetimeProduct.durationLabel, equals('Lifetime'));
      expect(lifetimeProduct.billingPeriodLabel, equals('one-time'));
    });
  });

  group('PurchaseResult Tests', () {
    test('success, cancelled, pending, and error results', () {
      final success = PurchaseResult.success(
        SubscriptionInfo.premium(activeProductId: 'anuscan_pro_monthly'),
      );
      expect(success.isSuccess, isTrue);
      expect(success.isCancelled, isFalse);
      expect(success.subscriptionInfo?.isPremium, isTrue);

      final cancelled = PurchaseResult.cancelled();
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isSuccess, isFalse);

      final pending = PurchaseResult.pending();
      expect(pending.isPending, isTrue);

      final error = PurchaseResult.error('Billing service unavailable');
      expect(error.isError, isTrue);
      expect(error.errorMessage, equals('Billing service unavailable'));
    });
  });
}
