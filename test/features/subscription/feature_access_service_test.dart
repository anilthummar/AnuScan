import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/feature_access_service.dart';
import 'package:anuscan/features/subscription/domain/entities/subscription_status.dart';
import 'package:anuscan/features/subscription/domain/repositories/subscription_repository.dart';

class MockSubscriptionRepository extends Mock implements SubscriptionRepository {}

void main() {
  late MockSubscriptionRepository mockRepo;
  late StreamController<SubscriptionInfo> updateStreamController;
  late FeatureAccessServiceImpl accessService;

  setUp(() {
    mockRepo = MockSubscriptionRepository();
    updateStreamController = StreamController<SubscriptionInfo>.broadcast();
    when(() => mockRepo.subscriptionUpdates).thenAnswer((_) => updateStreamController.stream);

    accessService = FeatureAccessServiceImpl(
      subscriptionRepository: mockRepo,
      isMonetizationHidden: false,
    );
  });

  tearDown(() {
    updateStreamController.close();
  });

  group('FeatureAccessService Tests', () {
    test('Free tier blocks all premium features', () {
      expect(accessService.isPremium, isFalse);
      expect(accessService.currentSubscriptionInfo.tier, equals(SubscriptionTier.free));

      for (final feature in PremiumFeature.values) {
        expect(accessService.canUse(feature), isFalse, reason: 'Failed for $feature');
      }
    });

    test('Active Pro subscription unlocks all premium features', () {
      accessService.updateSubscriptionInfo(
        SubscriptionInfo.premium(
          activeProductId: 'anuscan_pro_monthly',
          expirationDate: DateTime.now().add(const Duration(days: 30)),
        ),
      );

      expect(accessService.isPremium, isTrue);

      for (final feature in PremiumFeature.values) {
        expect(accessService.canUse(feature), isTrue, reason: 'Failed for $feature');
      }
    });

    test('Subscription stream updates propagate automatically to access service', () async {
      expect(accessService.isPremium, isFalse);

      updateStreamController.add(
        SubscriptionInfo.premium(
          activeProductId: 'anuscan_pro_yearly',
          expirationDate: DateTime.now().add(const Duration(days: 365)),
        ),
      );

      await pumpEventQueue();

      expect(accessService.isPremium, isTrue);
      expect(accessService.canUse(PremiumFeature.advancedPdfExport), isTrue);
      expect(accessService.canUse(PremiumFeature.batchPdfExport), isTrue);
    });

    test('Downgrade back to free disables premium access immediately', () async {
      accessService.updateSubscriptionInfo(
        SubscriptionInfo.premium(activeProductId: 'anuscan_pro_monthly'),
      );
      expect(accessService.isPremium, isTrue);

      updateStreamController.add(SubscriptionInfo.free());
      await pumpEventQueue();

      expect(accessService.isPremium, isFalse);
      expect(accessService.canUse(PremiumFeature.batchPdfExport), isFalse);
    });

    test('PremiumFeatureInfo registry provides metadata for every feature', () {
      for (final feature in PremiumFeature.values) {
        final info = PremiumFeatureInfo.forFeature(feature);
        expect(info.title, isNotEmpty);
        expect(info.description, isNotEmpty);
        expect(info.icon, isNotNull);
        expect(info.feature, equals(feature));
      }
    });
  });

  group('Monetization Hidden Mode Tests', () {
    test(
      'When monetization is hidden (default), all features are unconditionally unlocked even on free tier',
      () {
        final hiddenAccessService = FeatureAccessServiceImpl(
          subscriptionRepository: mockRepo,
          isMonetizationHidden: true,
        );
        expect(hiddenAccessService.isPremium, isFalse);
        for (final feature in PremiumFeature.values) {
          expect(
            hiddenAccessService.canUse(feature),
            isTrue,
            reason: 'Feature $feature must be unlocked when monetization is hidden',
          );
        }
      },
    );
  });
}
