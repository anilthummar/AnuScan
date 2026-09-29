import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/subscription_usecases.dart';
import 'subscription_state.dart';

/// Cubit managing subscription loading, product offerings, purchases, and restore flows.
class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit({
    required GetSubscriptionInfoUseCase getSubscriptionInfoUseCase,
    required GetSubscriptionProductsUseCase getSubscriptionProductsUseCase,
    required PurchaseProductUseCase purchaseProductUseCase,
    required RestorePurchasesUseCase restorePurchasesUseCase,
    Stream<dynamic>? externalUpdatesStream,
  })  : _getSubscriptionInfoUseCase = getSubscriptionInfoUseCase,
        _getSubscriptionProductsUseCase = getSubscriptionProductsUseCase,
        _purchaseProductUseCase = purchaseProductUseCase,
        _restorePurchasesUseCase = restorePurchasesUseCase,
        super(SubscriptionState.initial()) {
    if (externalUpdatesStream != null) {
      _subscription = externalUpdatesStream.listen((_) {
        loadSubscription();
      });
    }
  }

  final GetSubscriptionInfoUseCase _getSubscriptionInfoUseCase;
  final GetSubscriptionProductsUseCase _getSubscriptionProductsUseCase;
  final PurchaseProductUseCase _purchaseProductUseCase;
  final RestorePurchasesUseCase _restorePurchasesUseCase;

  StreamSubscription<dynamic>? _subscription;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  /// Loads current subscription state and store offerings.
  Future<void> loadSubscription({bool forceRefresh = false}) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final info = await _getSubscriptionInfoUseCase(
        forceRefresh: forceRefresh,
      );
      final products = await _getSubscriptionProductsUseCase();

      String? defaultSelectedId = state.selectedProductId;
      if (defaultSelectedId == null && products.isNotEmpty) {
        // Default to best-value (yearly) or first
        defaultSelectedId = products
            .firstWhere(
              (p) => p.isBestValue,
              orElse: () => products.first,
            )
            .id;
      }

      emit(
        state.copyWith(
          info: info,
          products: products,
          selectedProductId: defaultSelectedId,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load subscription status: $e',
        ),
      );
    }
  }

  /// Selects a product plan on the paywall screen.
  void selectProduct(String productId) {
    emit(state.copyWith(selectedProductId: productId));
  }

  /// Executes a purchase for [productId] or the currently selected product.
  Future<void> purchase([String? productId]) async {
    final targetId = productId ?? state.selectedProductId;
    if (targetId == null) {
      emit(state.copyWith(errorMessage: 'Please select a subscription plan.'));
      return;
    }

    emit(
      state.copyWith(
        isPurchasing: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
        isPending: false,
      ),
    );

    try {
      final result = await _purchaseProductUseCase(targetId);

      if (result.isSuccess && result.subscriptionInfo != null) {
        emit(
          state.copyWith(
            info: result.subscriptionInfo!,
            isPurchasing: false,
            successMessage: 'Welcome to AnuScan Pro!',
          ),
        );
      } else if (result.isCancelled) {
        emit(state.copyWith(isPurchasing: false));
      } else if (result.isPending) {
        emit(
          state.copyWith(
            isPurchasing: false,
            isPending: true,
            errorMessage: result.errorMessage,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isPurchasing: false,
            errorMessage: result.errorMessage ?? 'Purchase could not be completed.',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          isPurchasing: false,
          errorMessage: 'Purchase error: $e',
        ),
      );
    }
  }

  /// Restores previous purchases associated with the store account.
  Future<void> restorePurchases() async {
    emit(
      state.copyWith(
        isRestoring: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final result = await _restorePurchasesUseCase();

      if (result.isSuccess &&
          result.subscriptionInfo != null &&
          result.subscriptionInfo!.isPremium) {
        emit(
          state.copyWith(
            info: result.subscriptionInfo!,
            isRestoring: false,
            successMessage: 'Purchases successfully restored!',
          ),
        );
      } else {
        emit(
          state.copyWith(
            info: result.subscriptionInfo ?? state.info,
            isRestoring: false,
            errorMessage: result.errorMessage ??
                'No active subscription found to restore.',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          isRestoring: false,
          errorMessage: 'Failed to restore purchases: $e',
        ),
      );
    }
  }

  /// Clears active error or success notification messages.
  void clearMessages() {
    emit(state.copyWith(clearErrorMessage: true, clearSuccessMessage: true));
  }
}
