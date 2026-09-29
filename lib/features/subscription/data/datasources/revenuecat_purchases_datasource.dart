import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../core/constants/premium_constants.dart';
import '../../domain/entities/purchase_result.dart';
import '../../domain/entities/subscription_product.dart';
import '../../domain/entities/subscription_status.dart';
import 'purchases_datasource.dart';

/// Production implementation of [PurchasesDataSource] using RevenueCat `purchases_flutter`.
class RevenueCatPurchasesDataSource implements PurchasesDataSource {
  RevenueCatPurchasesDataSource({
    String? apiKey,
    this.enableDebugLogs = kDebugMode,
  }) : _apiKey = apiKey ?? PremiumConstants.apiKeyForPlatform;

  final String _apiKey;
  final bool enableDebugLogs;

  bool _isConfigured = false;
  final StreamController<SubscriptionInfo> _infoStreamController =
      StreamController<SubscriptionInfo>.broadcast();

  @override
  Stream<SubscriptionInfo> get customerInfoStream =>
      _infoStreamController.stream;

  @override
  Future<void> initialize() async {
    if (PremiumConstants.isMonetizationHidden) return;
    if (_isConfigured) return;

    try {
      if (enableDebugLogs) {
        await Purchases.setLogLevel(LogLevel.warn);
      }

      final configuration = PurchasesConfiguration(_apiKey);
      await Purchases.configure(configuration);
      _isConfigured = true;

      // Listen to real-time entitlement/subscription updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        final info = _mapCustomerInfo(customerInfo);
        _infoStreamController.add(info);
      });
    } catch (e) {
      debugPrint('RevenueCat initialization skipped or failed: $e');
    }
  }

  @override
  Future<SubscriptionInfo> getCustomerSubscriptionInfo() async {
    if (!_isConfigured) {
      await initialize();
    }
    if (!_isConfigured) {
      return SubscriptionInfo.free();
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _mapCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('Failed to get customer info from RevenueCat: $e');
      return SubscriptionInfo.free();
    }
  }

  @override
  Future<List<SubscriptionProduct>> getOfferings() async {
    if (!_isConfigured) {
      await initialize();
    }
    if (!_isConfigured) {
      return _fallbackProducts;
    }

    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;
      if (currentOffering == null || currentOffering.availablePackages.isEmpty) {
        return _fallbackProducts;
      }

      final products = <SubscriptionProduct>[];
      for (final package in currentOffering.availablePackages) {
        final sp = package.storeProduct;
        ProductDuration duration = ProductDuration.unknown;
        bool isBestValue = false;

        switch (package.packageType) {
          case PackageType.monthly:
            duration = ProductDuration.monthly;
            break;
          case PackageType.annual:
            duration = ProductDuration.yearly;
            isBestValue = true;
            break;
          case PackageType.lifetime:
            duration = ProductDuration.lifetime;
            break;
          default:
            if (sp.identifier.contains('month')) {
              duration = ProductDuration.monthly;
            } else if (sp.identifier.contains('year') ||
                sp.identifier.contains('annual')) {
              duration = ProductDuration.yearly;
              isBestValue = true;
            } else if (sp.identifier.contains('life')) {
              duration = ProductDuration.lifetime;
            }
            break;
        }

        products.add(
          SubscriptionProduct(
            id: sp.identifier,
            title: sp.title.isNotEmpty ? sp.title : package.identifier,
            description: sp.description,
            priceString: sp.priceString,
            price: sp.price,
            currencyCode: sp.currencyCode,
            duration: duration,
            freeTrialPeriod: sp.introductoryPrice?.periodNumberOfUnits != null
                ? '${sp.introductoryPrice!.periodNumberOfUnits} ${sp.introductoryPrice!.periodUnit.name.toLowerCase()}s free'
                : null,
            isBestValue: isBestValue,
          ),
        );
      }

      return products.isNotEmpty ? products : _fallbackProducts;
    } catch (e) {
      debugPrint('Failed to load offerings from RevenueCat: $e');
      return _fallbackProducts;
    }
  }

  @override
  Future<PurchaseResult> purchase(String productId) async {
    if (!_isConfigured) {
      await initialize();
    }
    if (!_isConfigured) {
      return PurchaseResult.error(
        'Store configuration is unavailable. Please verify network access.',
      );
    }

    try {
      final offerings = await Purchases.getOfferings();
      Package? targetPackage;
      for (final package in offerings.current?.availablePackages ?? []) {
        if (package.storeProduct.identifier == productId) {
          targetPackage = package;
          break;
        }
      }

      CustomerInfo customerInfo;
      if (targetPackage != null) {
        customerInfo = await Purchases.purchasePackage(targetPackage);
      } else {
        final products = await Purchases.getProducts([productId]);
        if (products.isEmpty) {
          return PurchaseResult.error('Product not found in store.');
        }
        customerInfo = await Purchases.purchaseStoreProduct(products.first);
      }

      final info = _mapCustomerInfo(customerInfo);
      _infoStreamController.add(info);

      if (info.isPremium) {
        return PurchaseResult.success(info);
      }
      return PurchaseResult.pending();
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      return PurchaseResult.error('An unexpected error occurred during purchase.');
    }
  }

  @override
  Future<PurchaseResult> restore() async {
    if (!_isConfigured) {
      await initialize();
    }
    if (!_isConfigured) {
      return PurchaseResult.error(
        'Store configuration is unavailable. Please check your connection.',
      );
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      final info = _mapCustomerInfo(customerInfo);
      _infoStreamController.add(info);

      if (info.isPremium) {
        return PurchaseResult.success(info);
      }
      return PurchaseResult.error(
        'No active AnuScan Pro subscription found for this store account.',
      );
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      return PurchaseResult.error('Failed to restore purchases: $e');
    }
  }

  SubscriptionInfo _mapCustomerInfo(CustomerInfo customerInfo) {
    final proEntitlement =
        customerInfo.entitlements.all[PremiumConstants.proEntitlementId];

    if (proEntitlement != null && proEntitlement.isActive) {
      StoreType store = StoreType.unknown;
      switch (proEntitlement.store) {
        case Store.playStore:
          store = StoreType.googlePlay;
          break;
        case Store.appStore:
        case Store.macAppStore:
          store = StoreType.appStore;
          break;
        default:
          store = StoreType.unknown;
          break;
      }

      return SubscriptionInfo.premium(
        activeProductId: proEntitlement.productIdentifier,
        expirationDate: proEntitlement.expirationDate != null
            ? DateTime.tryParse(proEntitlement.expirationDate!)
            : null,
        willRenew: proEntitlement.willRenew,
        store: store,
        originalPurchaseDate:
            DateTime.tryParse(proEntitlement.originalPurchaseDate),
        isSandbox: proEntitlement.isSandbox,
      );
    }

    return SubscriptionInfo.free();
  }

  PurchaseResult _handlePlatformException(PlatformException e) {
    final errorCode = PurchasesErrorHelper.getErrorCode(e);
    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        return PurchaseResult.cancelled();
      case PurchasesErrorCode.paymentPendingError:
        return PurchaseResult.pending();
      case PurchasesErrorCode.networkError:
        return PurchaseResult.error(
          'Network connection error. Please check your connection and try again.',
        );
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return PurchaseResult.error(
          'You already own this product. Please tap "Restore Purchases" to activate.',
        );
      case PurchasesErrorCode.storeProblemError:
        return PurchaseResult.error(
          'The app store is experiencing problems. Please try again shortly.',
        );
      default:
        return PurchaseResult.error(
          e.message ?? 'Purchase failed. Please try again.',
        );
    }
  }

  static const List<SubscriptionProduct> _fallbackProducts = [
    SubscriptionProduct(
      id: PremiumConstants.monthlyProductId,
      title: 'Monthly Pro',
      description: 'Full access to all Pro features, billed monthly.',
      priceString: '\$3.99',
      price: 3.99,
      currencyCode: 'USD',
      duration: ProductDuration.monthly,
    ),
    SubscriptionProduct(
      id: PremiumConstants.yearlyProductId,
      title: 'Annual Pro',
      description: 'Save 40% with annual billing. 7-day free trial included.',
      priceString: '\$24.99',
      price: 24.99,
      currencyCode: 'USD',
      duration: ProductDuration.yearly,
      freeTrialPeriod: '7 days free',
      isBestValue: true,
    ),
    SubscriptionProduct(
      id: PremiumConstants.lifetimeProductId,
      title: 'Lifetime Pro',
      description: 'Pay once, keep forever. Unlimited future updates.',
      priceString: '\$59.99',
      price: 59.99,
      currencyCode: 'USD',
      duration: ProductDuration.lifetime,
    ),
  ];
}
