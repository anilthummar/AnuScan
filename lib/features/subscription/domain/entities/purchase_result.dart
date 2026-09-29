import 'package:equatable/equatable.dart';
import 'subscription_status.dart';

/// The final outcome of a purchase or restore request.
enum PurchaseStatus {
  success,
  cancelled,
  pending,
  error,
}

/// Domain result representing the outcome of a purchase or restore attempt.
class PurchaseResult extends Equatable {
  const PurchaseResult({
    required this.status,
    this.subscriptionInfo,
    this.errorMessage,
  });

  factory PurchaseResult.success(SubscriptionInfo info) => PurchaseResult(
        status: PurchaseStatus.success,
        subscriptionInfo: info,
      );

  factory PurchaseResult.cancelled() => const PurchaseResult(
        status: PurchaseStatus.cancelled,
      );

  factory PurchaseResult.pending() => const PurchaseResult(
        status: PurchaseStatus.pending,
        errorMessage: 'Payment is currently pending verification from your store.',
      );

  factory PurchaseResult.error(String message) => PurchaseResult(
        status: PurchaseStatus.error,
        errorMessage: message,
      );

  final PurchaseStatus status;
  final SubscriptionInfo? subscriptionInfo;
  final String? errorMessage;

  bool get isSuccess => status == PurchaseStatus.success;
  bool get isCancelled => status == PurchaseStatus.cancelled;
  bool get isPending => status == PurchaseStatus.pending;
  bool get isError => status == PurchaseStatus.error;

  @override
  List<Object?> get props => [status, subscriptionInfo, errorMessage];
}
