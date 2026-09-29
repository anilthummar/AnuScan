import 'package:equatable/equatable.dart';
import '../../domain/entities/subscription_product.dart';
import '../../domain/entities/subscription_status.dart';

/// State representation for subscription, entitlement, and paywall interactions.
class SubscriptionState extends Equatable {
  const SubscriptionState({
    required this.info,
    this.products = const [],
    this.selectedProductId,
    this.isLoading = false,
    this.isPurchasing = false,
    this.isRestoring = false,
    this.errorMessage,
    this.successMessage,
    this.isPending = false,
  });

  factory SubscriptionState.initial() => SubscriptionState(
        info: SubscriptionInfo.free(),
        isLoading: true,
      );

  final SubscriptionInfo info;
  final List<SubscriptionProduct> products;
  final String? selectedProductId;
  final bool isLoading;
  final bool isPurchasing;
  final bool isRestoring;
  final String? errorMessage;
  final String? successMessage;
  final bool isPending;

  bool get isPremium => info.isPremium;

  SubscriptionProduct? get selectedProduct {
    if (products.isEmpty) return null;
    if (selectedProductId == null) {
      // Default to best-value (e.g. yearly) or first product
      return products.firstWhere(
        (p) => p.isBestValue,
        orElse: () => products.first,
      );
    }
    return products.firstWhere(
      (p) => p.id == selectedProductId,
      orElse: () => products.first,
    );
  }

  SubscriptionState copyWith({
    SubscriptionInfo? info,
    List<SubscriptionProduct>? products,
    String? selectedProductId,
    bool? isLoading,
    bool? isPurchasing,
    bool? isRestoring,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successMessage,
    bool clearSuccessMessage = false,
    bool? isPending,
  }) {
    return SubscriptionState(
      info: info ?? this.info,
      products: products ?? this.products,
      selectedProductId: selectedProductId ?? this.selectedProductId,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      isPending: isPending ?? this.isPending,
    );
  }

  @override
  List<Object?> get props => [
        info,
        products,
        selectedProductId,
        isLoading,
        isPurchasing,
        isRestoring,
        errorMessage,
        successMessage,
        isPending,
      ];
}
