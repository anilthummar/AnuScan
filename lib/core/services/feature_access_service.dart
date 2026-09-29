import 'package:flutter/material.dart';
import '../constants/premium_constants.dart';
import '../../features/subscription/domain/entities/subscription_status.dart';
import '../../features/subscription/domain/repositories/subscription_repository.dart';

/// Enumeration of premium-gated capabilities in AnuScan.
enum PremiumFeature {
  /// Custom high-fidelity PDF compression, custom page aspect ratios, and advanced export presets.
  advancedPdfExport,

  /// Embedding invisible OCR text layers into generated PDFs for cross-application search and text selection.
  searchablePdfExport,

  /// Bulk exporting multiple documents to PDF simultaneously.
  batchPdfExport,

  /// Automated tagging and category sorting upon document scan.
  smartClassificationAutomation,

  /// Batch OCR processing for multi-page documents exceeding free-tier limits.
  unlimitedOcrBatch,
}

/// Metadata describing a [PremiumFeature] for user-facing paywalls and feature-gate dialogs.
class PremiumFeatureInfo {
  const PremiumFeatureInfo({
    required this.feature,
    required this.title,
    required this.description,
    required this.icon,
  });

  final PremiumFeature feature;
  final String title;
  final String description;
  final IconData icon;

  static const Map<PremiumFeature, PremiumFeatureInfo> registry = {
    PremiumFeature.advancedPdfExport: PremiumFeatureInfo(
      feature: PremiumFeature.advancedPdfExport,
      title: 'Advanced PDF Export',
      description:
          'Export with custom compression controls, professional presets, and flexible page formats.',
      icon: Icons.picture_as_pdf,
    ),
    PremiumFeature.searchablePdfExport: PremiumFeatureInfo(
      feature: PremiumFeature.searchablePdfExport,
      title: 'Searchable PDF Generation',
      description:
          'Embed local OCR text layers directly into PDFs so you can search and copy text in any viewer.',
      icon: Icons.find_in_page_outlined,
    ),
    PremiumFeature.batchPdfExport: PremiumFeatureInfo(
      feature: PremiumFeature.batchPdfExport,
      title: 'Batch PDF Export',
      description:
          'Compile and export multiple documents at once with background queueing.',
      icon: Icons.folder_zip_outlined,
    ),
    PremiumFeature.smartClassificationAutomation: PremiumFeatureInfo(
      feature: PremiumFeature.smartClassificationAutomation,
      title: 'Smart Automation',
      description:
          'Automatically tag, categorize, and route scanned documents based on local document recognition.',
      icon: Icons.auto_awesome,
    ),
    PremiumFeature.unlimitedOcrBatch: PremiumFeatureInfo(
      feature: PremiumFeature.unlimitedOcrBatch,
      title: 'Unlimited Batch OCR',
      description:
          'Run on-device text recognition on unlimited pages simultaneously without batch throttles.',
      icon: Icons.document_scanner_outlined,
    ),
  };

  static PremiumFeatureInfo forFeature(PremiumFeature feature) {
    return registry[feature] ??
        PremiumFeatureInfo(
          feature: feature,
          title: 'AnuScan Pro Feature',
          description: 'Unlock this advanced capability with AnuScan Pro.',
          icon: Icons.star_border,
        );
  }
}

/// Centralized service to evaluate whether a user can access a gated feature.
/// Prevents scattering `if (isPremium)` checks across the codebase.
abstract class FeatureAccessService {
  /// Whether the user has access to [feature].
  bool canUse(PremiumFeature feature);

  /// Whether the user currently has an active AnuScan Pro entitlement.
  bool get isPremium;

  /// Returns the current known subscription info.
  SubscriptionInfo get currentSubscriptionInfo;

  /// Updates the internal cached subscription state.
  void updateSubscriptionInfo(SubscriptionInfo info);
}

/// Concrete implementation of [FeatureAccessService].
class FeatureAccessServiceImpl implements FeatureAccessService {
  FeatureAccessServiceImpl({
    required SubscriptionRepository subscriptionRepository,
    bool? isMonetizationHidden,
  })  : _subscriptionRepository = subscriptionRepository,
        _isMonetizationHidden =
            isMonetizationHidden ?? PremiumConstants.isMonetizationHidden {
    // Listen to subscription updates from the repository
    _subscriptionRepository.subscriptionUpdates.listen((info) {
      _currentInfo = info;
    });
  }

  final SubscriptionRepository _subscriptionRepository;
  final bool _isMonetizationHidden;
  SubscriptionInfo _currentInfo = SubscriptionInfo.free();

  @override
  bool canUse(PremiumFeature feature) {
    // When monetization is hidden, all features are completely unlocked without restriction
    if (_isMonetizationHidden) return true;

    // Pro users have access to all premium features
    if (_currentInfo.isPremium) return true;

    // Feature-specific free-tier allowances:
    // Core scanning, basic OCR viewer, basic PDF export, tags, folders,
    // app lock, and AES-GCM encryption are always free and NEVER blocked.
    switch (feature) {
      case PremiumFeature.advancedPdfExport:
      case PremiumFeature.searchablePdfExport:
      case PremiumFeature.batchPdfExport:
      case PremiumFeature.smartClassificationAutomation:
      case PremiumFeature.unlimitedOcrBatch:
        return false;
    }
  }

  @override
  bool get isPremium => _currentInfo.isPremium;

  @override
  SubscriptionInfo get currentSubscriptionInfo => _currentInfo;

  @override
  void updateSubscriptionInfo(SubscriptionInfo info) {
    _currentInfo = info;
  }
}
