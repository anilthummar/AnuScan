import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/premium_constants.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../domain/entities/purchase_result.dart';
import '../../domain/entities/subscription_product.dart';
import '../../domain/entities/subscription_status.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/purchases_datasource.dart';

/// Concrete implementation of [SubscriptionRepository] combining a store data source
/// with hardware-backed secure storage for offline entitlement resilience.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({
    required PurchasesDataSource purchasesDataSource,
    required SecureStorageService secureStorageService,
  })  : _purchasesDataSource = purchasesDataSource,
        _secureStorageService = secureStorageService {
    // Listen to store updates and update secure cache accordingly
    _purchasesDataSource.customerInfoStream.listen((info) {
      _cacheSubscriptionInfo(info);
      _subscriptionUpdatesController.add(info);
    });
  }

  final PurchasesDataSource _purchasesDataSource;
  final SecureStorageService _secureStorageService;

  final StreamController<SubscriptionInfo> _subscriptionUpdatesController =
      StreamController<SubscriptionInfo>.broadcast();

  SubscriptionInfo? _memoryCache;

  @override
  Stream<SubscriptionInfo> get subscriptionUpdates =>
      _subscriptionUpdatesController.stream;

  @override
  Future<SubscriptionInfo> getSubscriptionInfo({
    bool forceRefresh = false,
  }) async {
    // 1. If not forcing refresh and memory cache is available, return immediately
    if (!forceRefresh && _memoryCache != null) {
      return _memoryCache!;
    }

    // 2. Read from secure storage cache first (for fast offline startup)
    final cachedInfo = await _readCachedSubscriptionInfo();
    if (cachedInfo != null && !forceRefresh) {
      _memoryCache = cachedInfo;
      // Trigger background verification without blocking UI
      _verifyWithStoreInBackground();
      return cachedInfo;
    }

    // 3. Query the store data source
    try {
      final freshInfo =
          await _purchasesDataSource.getCustomerSubscriptionInfo();
      await _cacheSubscriptionInfo(freshInfo);
      _memoryCache = freshInfo;
      return freshInfo;
    } catch (e) {
      debugPrint('Subscription verification failed, falling back to cache: $e');
      // If store is unreachable (e.g. offline), use secure cache
      final fallback = cachedInfo ?? SubscriptionInfo.free();
      _memoryCache = fallback;
      return fallback;
    }
  }

  @override
  Future<List<SubscriptionProduct>> getProducts() async {
    try {
      return await _purchasesDataSource.getOfferings();
    } catch (e) {
      debugPrint('Failed to fetch offerings: $e');
      return [];
    }
  }

  @override
  Future<PurchaseResult> purchaseProduct(String productId) async {
    try {
      final result = await _purchasesDataSource.purchase(productId);
      if (result.isSuccess && result.subscriptionInfo != null) {
        await _cacheSubscriptionInfo(result.subscriptionInfo!);
        _memoryCache = result.subscriptionInfo;
      }
      return result;
    } catch (e) {
      return PurchaseResult.error('Purchase failed: $e');
    }
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    try {
      final result = await _purchasesDataSource.restore();
      if (result.isSuccess && result.subscriptionInfo != null) {
        await _cacheSubscriptionInfo(result.subscriptionInfo!);
        _memoryCache = result.subscriptionInfo;
      }
      return result;
    } catch (e) {
      return PurchaseResult.error('Restore failed: $e');
    }
  }

  Future<void> _verifyWithStoreInBackground() async {
    try {
      final freshInfo =
          await _purchasesDataSource.getCustomerSubscriptionInfo();
      if (freshInfo != _memoryCache) {
        await _cacheSubscriptionInfo(freshInfo);
        _memoryCache = freshInfo;
        _subscriptionUpdatesController.add(freshInfo);
      }
    } catch (e) {
      // Graceful silence in background: user remains on cached entitlement
      debugPrint('Background store verification failed: $e');
    }
  }

  Future<void> _cacheSubscriptionInfo(SubscriptionInfo info) async {
    try {
      final jsonStr = jsonEncode(info.toJson());
      await _secureStorageService.write(
        PremiumConstants.cachedEntitlementKey,
        jsonStr,
      );
      await _secureStorageService.write(
        PremiumConstants.cachedVerifiedAtKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Failed to cache subscription info in secure storage: $e');
    }
  }

  Future<SubscriptionInfo?> _readCachedSubscriptionInfo() async {
    try {
      final raw = await _secureStorageService.read(
        PremiumConstants.cachedEntitlementKey,
      );
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final info = SubscriptionInfo.fromJson(decoded);

      // Verify expiration if present and not lifetime
      if (info.isPremium && info.expirationDate != null) {
        if (DateTime.now().isAfter(info.expirationDate!)) {
          // Entitlement has expired locally
          return SubscriptionInfo.free();
        }
      }

      return info;
    } catch (e) {
      debugPrint('Failed to parse cached subscription info: $e');
      return null;
    }
  }
}
