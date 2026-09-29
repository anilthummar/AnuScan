import 'package:flutter/material.dart';
import '../../../../core/constants/premium_constants.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/feature_access_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Modal bottom sheet presenting a clean, non-deceptive feature gate explanation
/// when a free-tier user taps on a premium-only feature.
class FeatureGateSheet extends StatelessWidget {
  const FeatureGateSheet({
    super.key,
    required this.feature,
    this.onViewPro,
  });

  final PremiumFeature feature;
  final VoidCallback? onViewPro;

  /// Convenience method to show the feature gate modal sheet.
  static Future<void> show(
    BuildContext context, {
    required PremiumFeature feature,
    VoidCallback? onViewPro,
  }) {
    if (PremiumConstants.isMonetizationHidden) {
      return Future.value();
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FeatureGateSheet(
        feature: feature,
        onViewPro: onViewPro,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final info = PremiumFeatureInfo.forFeature(feature);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Feature Icon & Pro Badge
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  info.icon,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Feature Title
            Text(
              info.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // Pro Tag
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ANUSCAN PRO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Feature Description
            Text(
              info.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Offline & Privacy Guarantee Badge
            Container(
              padding: const EdgeInsets.all(12),
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
                    Icons.offline_bolt_outlined,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All Pro features process 100% offline on your device.',
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

            // Primary CTA: View Pro Plans
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                if (onViewPro != null) {
                  onViewPro!();
                } else {
                  Navigator.pushNamed(context, AppRoutes.premium);
                }
              },
              child: const Text(
                'View Pro Plans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary CTA: Not Now
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Not Now',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
