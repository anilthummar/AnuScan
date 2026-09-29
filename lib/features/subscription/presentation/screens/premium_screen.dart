import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/premium_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/subscription_product.dart';
import '../cubit/subscription_cubit.dart';
import '../cubit/subscription_state.dart';

/// Dedicated paywall and subscription screen for AnuScan Pro.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.customCubit});

  final SubscriptionCubit? customCubit;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  SubscriptionCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = widget.customCubit ??
        (sl.isRegistered<SubscriptionCubit>() ? sl<SubscriptionCubit>() : null);
    _cubit?.loadSubscription();
  }

  @override
  Widget build(BuildContext context) {
    if (_cubit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AnuScan Pro')),
        body: const Center(
          child: Text('Subscription service is initializing...'),
        ),
      );
    }

    return BlocProvider<SubscriptionCubit>.value(
      value: _cubit!,
      child: const _PremiumView(),
    );
  }
}

class _PremiumView extends StatelessWidget {
  const _PremiumView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<SubscriptionCubit, SubscriptionState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<SubscriptionCubit>().clearMessages();
        }

        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.successMessage!)),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<SubscriptionCubit>().clearMessages();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              TextButton(
                onPressed: state.isRestoring
                    ? null
                    : () => context.read<SubscriptionCubit>().restorePurchases(),
                child: state.isRestoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Restore',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Badge & Title
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.secondary,
                                  AppColors.secondary.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withValues(alpha: 0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.workspace_premium,
                              size: 42,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AnuScan Pro',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Professional document workflows with zero cloud lock-in.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Pro Benefits Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Column(
                            children: const [
                              _BenefitRow(
                                icon: Icons.find_in_page_outlined,
                                title: 'Searchable PDF Export',
                                description:
                                    'Embed OCR text layers directly in PDFs for easy searching and copying.',
                              ),
                              Divider(height: 24),
                              _BenefitRow(
                                icon: Icons.tune,
                                title: 'Advanced Export Controls',
                                description:
                                    'Custom compression quality, custom page dimensions, and high-DPI presets.',
                              ),
                              Divider(height: 24),
                              _BenefitRow(
                                icon: Icons.folder_zip_outlined,
                                title: 'Batch PDF Export',
                                description:
                                    'Compile and export multiple scanned documents simultaneously.',
                              ),
                              Divider(height: 24),
                              _BenefitRow(
                                icon: Icons.auto_awesome_outlined,
                                title: 'Smart Automation',
                                description:
                                    'Auto-tag, categorize, and organize scans using local recognition.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Privacy & Ownership Guarantee
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                color: AppColors.success,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '100% Offline Processing. Your documents always belong to you and are never locked out.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Products / Pricing Options
                        if (state.products.isNotEmpty) ...[
                          Text(
                            'Choose a Plan',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...state.products.map(
                            (product) => _ProductCard(
                              product: product,
                              isSelected: state.selectedProductId == product.id,
                              onTap: () => context
                                  .read<SubscriptionCubit>()
                                  .selectProduct(product.id),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Purchase CTA Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: state.isPurchasing
                              ? null
                              : () => context.read<SubscriptionCubit>().purchase(),
                          child: state.isPurchasing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _getButtonTitle(state.selectedProduct),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // Store Terms & Legal Links
                        Text(
                          'Payment will be charged to your App Store or Google Play account. Subscriptions automatically renew unless cancelled at least 24 hours prior to renewal.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Terms: ${PremiumConstants.termsOfServiceUrl}',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Terms of Use', style: TextStyle(fontSize: 12)),
                            ),
                            const Text('•', style: TextStyle(color: Colors.grey)),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Privacy: ${PremiumConstants.privacyPolicyUrl}',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _getButtonTitle(SubscriptionProduct? product) {
    if (product == null) return 'Unlock Pro';
    if (product.freeTrialPeriod != null) {
      final trial = product.freeTrialPeriod!;
      if (trial.toLowerCase().contains('trial')) {
        return 'Start $trial';
      }
      return 'Start $trial Free Trial';
    }
    if (product.duration == ProductDuration.lifetime) {
      return 'Get Lifetime Pro';
    }
    return 'Continue with ${product.title}';
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  final SubscriptionProduct product;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${product.title} plan, ${product.priceString} ${product.billingPeriodLabel}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
                  : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white12 : Colors.black12),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Radio indicator
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primary : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            product.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (product.isBestValue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product.freeTrialPeriod != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.freeTrialPeriod!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Price and frequency
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      product.priceString,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    Text(
                      product.billingPeriodLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
