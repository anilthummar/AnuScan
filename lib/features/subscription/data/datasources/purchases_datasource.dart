import '../../domain/entities/purchase_result.dart';
import '../../domain/entities/subscription_product.dart';
import '../../domain/entities/subscription_status.dart';

/// Low-level data source interface for store purchases and billing.
abstract class PurchasesDataSource {
  /// Initializes the underlying purchase SDK (e.g. RevenueCat).
  Future<void> initialize();

  /// Queries the current customer info from the purchase provider.
  Future<SubscriptionInfo> getCustomerSubscriptionInfo();

  /// Queries available offerings / products from the store.
  Future<List<SubscriptionProduct>> getOfferings();

  /// Purchases a product given its store [productId].
  Future<PurchaseResult> purchase(String productId);

  /// Restores previous purchases.
  Future<PurchaseResult> restore();

  /// Emits whenever the purchase provider's customer info updates in the background.
  Stream<SubscriptionInfo> get customerInfoStream;
}
