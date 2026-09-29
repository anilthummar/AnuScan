import 'package:flutter/material.dart';
import 'scanner_empty_state.dart';

/// Clean empty state placeholder when no documents have been scanned.
/// Matches the AnuScan redesigned dashboard empty state.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.onScanPressed,
    required this.onGalleryPressed,
  });

  final VoidCallback onScanPressed;
  final VoidCallback onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScannerEmptyState(
        onScanPressed: onScanPressed,
        onGalleryPressed: onGalleryPressed,
      ),
    );
  }
}
