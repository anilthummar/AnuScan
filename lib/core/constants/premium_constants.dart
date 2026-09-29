import 'package:flutter/foundation.dart';

/// Centralized configuration and constants for AnuScan Pro monetization and entitlements.
abstract class PremiumConstants {
  /// When true, completely hides all RevenueCat UI, paywalls, and Pro badges,
  /// skipping RevenueCat initialization and granting full access to app functionality
  /// without any monetization gates or prompts.
  static bool isMonetizationHidden = true;

  // Entitlement
  /// The primary entitlement identifier for full premium access in RevenueCat.
  static const String proEntitlementId = 'anuscan_pro';

  // Product Identifiers
  static const String monthlyProductId = 'anuscan_pro_monthly';
  static const String yearlyProductId = 'anuscan_pro_yearly';
  static const String lifetimeProductId = 'anuscan_pro_lifetime';

  static const List<String> allProductIds = [
    monthlyProductId,
    yearlyProductId,
    lifetimeProductId,
  ];

  // RevenueCat Public Client Keys (Configurable via environment or placeholders)
  // NEVER put secret server keys here!
  static const String googleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_API_KEY',
    defaultValue: 'goog_anuscan_client_placeholder',
  );

  static const String appleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_API_KEY',
    defaultValue: 'appl_anuscan_client_placeholder',
  );

  // Legal & Subscription URLs
  static const String privacyPolicyUrl = 'https://anuscan.app/privacy';
  static const String termsOfServiceUrl = 'https://anuscan.app/terms';
  static const String googlePlaySubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';
  static const String appleAppStoreSubscriptionsUrl =
      'https://apps.apple.com/account/subscriptions';

  // Secure Storage Keys
  static const String cachedEntitlementKey = 'anuscan_entitlement_v1_cache';
  static const String cachedVerifiedAtKey = 'anuscan_entitlement_v1_verified_at';

  /// Returns the appropriate public API key for the current runtime platform.
  static String get apiKeyForPlatform {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return appleApiKey;
    }
    return googleApiKey;
  }
}
