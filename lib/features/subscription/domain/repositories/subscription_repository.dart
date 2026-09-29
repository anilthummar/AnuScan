import '../entities/purchase_result.dart';
import '../entities/subscription_product.dart';
import '../entities/subscription_status.dart';

/// Clean Architecture abstraction for subscription & entitlement operations.
abstract class SubscriptionRepository {
  /// Retrieves the current subscription info.
  /// If [forceRefresh] is true, queries the backend store; otherwise uses verified local cache.
  Future<SubscriptionInfo> getSubscriptionInfo({bool forceRefresh = false});

  /// Retrieves the available subscription products/offerings from the store.
  Future<List<SubscriptionProduct>> getProducts();

  /// Initiates a purchase flow for [productId].
  Future<PurchaseResult> purchaseProduct(String productId);

  /// Restores previous purchases associated with the current store account.
  Future<PurchaseResult> restorePurchases();

  /// Real-time stream of subscription updates emitted by customer info changes.
  Stream<SubscriptionInfo> get subscriptionUpdates;
}
