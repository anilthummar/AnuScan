import 'package:equatable/equatable.dart';

/// Subscription billing periods.
enum ProductDuration {
  monthly,
  yearly,
  lifetime,
  unknown,
}

/// Domain entity representing a purchasable subscription plan or lifetime license.
class SubscriptionProduct extends Equatable {
  const SubscriptionProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.priceString,
    required this.price,
    required this.currencyCode,
    required this.duration,
    this.freeTrialPeriod,
    this.isBestValue = false,
  });

  final String id;
  final String title;
  final String description;
  final String priceString;
  final double price;
  final String currencyCode;
  final ProductDuration duration;
  final String? freeTrialPeriod;
  final bool isBestValue;

  /// Returns user-friendly duration label, e.g. "Monthly", "Annual", "Lifetime".
  String get durationLabel {
    switch (duration) {
      case ProductDuration.monthly:
        return 'Monthly';
      case ProductDuration.yearly:
        return 'Annual';
      case ProductDuration.lifetime:
        return 'Lifetime';
      case ProductDuration.unknown:
        return 'Standard';
    }
  }

  /// Returns billing frequency subtitle, e.g. "/ month", "/ year", "one-time payment".
  String get billingPeriodLabel {
    switch (duration) {
      case ProductDuration.monthly:
        return '/ month';
      case ProductDuration.yearly:
        return '/ year';
      case ProductDuration.lifetime:
        return 'one-time';
      case ProductDuration.unknown:
        return '';
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        priceString,
        price,
        currencyCode,
        duration,
        freeTrialPeriod,
        isBestValue,
      ];
}
