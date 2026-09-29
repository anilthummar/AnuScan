import 'package:equatable/equatable.dart';

/// Available subscription tiers in AnuScan.
enum SubscriptionTier {
  free,
  premium,
}

/// The store platform providing the subscription.
enum StoreType {
  googlePlay,
  appStore,
  testStore,
  unknown,
}

/// Domain entity representing the user's active entitlement and subscription state.
class SubscriptionInfo extends Equatable {
  const SubscriptionInfo({
    required this.tier,
    this.activeProductId,
    this.expirationDate,
    this.willRenew = false,
    this.store = StoreType.unknown,
    this.originalPurchaseDate,
    this.isSandbox = false,
  });

  /// Factory for the default, unauthenticated or non-paying free tier.
  factory SubscriptionInfo.free() => const SubscriptionInfo(
        tier: SubscriptionTier.free,
      );

  /// Factory for an active AnuScan Pro subscription or lifetime purchase.
  factory SubscriptionInfo.premium({
    String? activeProductId,
    DateTime? expirationDate,
    bool willRenew = false,
    StoreType store = StoreType.unknown,
    DateTime? originalPurchaseDate,
    bool isSandbox = false,
  }) =>
      SubscriptionInfo(
        tier: SubscriptionTier.premium,
        activeProductId: activeProductId,
        expirationDate: expirationDate,
        willRenew: willRenew,
        store: store,
        originalPurchaseDate: originalPurchaseDate,
        isSandbox: isSandbox,
      );

  final SubscriptionTier tier;
  final String? activeProductId;
  final DateTime? expirationDate;
  final bool willRenew;
  final StoreType store;
  final DateTime? originalPurchaseDate;
  final bool isSandbox;

  bool get isPremium => tier == SubscriptionTier.premium;

  /// Returns true if this subscription is a non-recurring lifetime purchase (no expiration).
  bool get isLifetime => isPremium && expirationDate == null;

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'activeProductId': activeProductId,
        'expirationDate': expirationDate?.toIso8601String(),
        'willRenew': willRenew,
        'store': store.name,
        'originalPurchaseDate': originalPurchaseDate?.toIso8601String(),
        'isSandbox': isSandbox,
      };

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final tierName = json['tier'] as String? ?? 'free';
    final tier = tierName == 'premium'
        ? SubscriptionTier.premium
        : SubscriptionTier.free;

    StoreType parseStore(String? name) {
      if (name == 'googlePlay') return StoreType.googlePlay;
      if (name == 'appStore') return StoreType.appStore;
      if (name == 'testStore') return StoreType.testStore;
      return StoreType.unknown;
    }

    return SubscriptionInfo(
      tier: tier,
      activeProductId: json['activeProductId'] as String?,
      expirationDate: json['expirationDate'] != null
          ? DateTime.tryParse(json['expirationDate'] as String)
          : null,
      willRenew: json['willRenew'] as bool? ?? false,
      store: parseStore(json['store'] as String?),
      originalPurchaseDate: json['originalPurchaseDate'] != null
          ? DateTime.tryParse(json['originalPurchaseDate'] as String)
          : null,
      isSandbox: json['isSandbox'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        tier,
        activeProductId,
        expirationDate,
        willRenew,
        store,
        originalPurchaseDate,
        isSandbox,
      ];
}
