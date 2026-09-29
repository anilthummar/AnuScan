import '../entities/purchase_result.dart';
import '../entities/subscription_product.dart';
import '../entities/subscription_status.dart';
import '../repositories/subscription_repository.dart';

/// Use case to fetch current subscription status and active entitlement info.
class GetSubscriptionInfoUseCase {
  const GetSubscriptionInfoUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<SubscriptionInfo> call({bool forceRefresh = false}) =>
      _repository.getSubscriptionInfo(forceRefresh: forceRefresh);
}

/// Use case to load configured subscription products from the store.
class GetSubscriptionProductsUseCase {
  const GetSubscriptionProductsUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<List<SubscriptionProduct>> call() => _repository.getProducts();
}

/// Use case to initiate a store purchase for a given product ID.
class PurchaseProductUseCase {
  const PurchaseProductUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<PurchaseResult> call(String productId) =>
      _repository.purchaseProduct(productId);
}

/// Use case to restore previous purchases from the current store account.
class RestorePurchasesUseCase {
  const RestorePurchasesUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<PurchaseResult> call() => _repository.restorePurchases();
}
