import 'package:flutter/material.dart';

/// Quick Add action cards (Add Gallery, Scan Camera) + circular '+' FAB,
/// and primary Review & Export PDF CTA button.
class EditorQuickActions extends StatelessWidget {
  const EditorQuickActions({
    super.key,
    required this.onAddGallery,
    required this.onScanCamera,
    required this.onAddAnother,
    required this.onExportPdf,
    this.isProcessing = false,
  });

  final VoidCallback onAddGallery;
  final VoidCallback onScanCamera;
  final VoidCallback onAddAnother;
  final VoidCallback onExportPdf;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row with Add Gallery card, Scan Camera card, and circular '+' FAB
          Row(
            children: [
              // Add Gallery Card
              Expanded(
                child: _QuickAddCard(
                  icon: Icons.image_outlined,
                  title: 'Add Gallery',
                  subtitle: 'Import from your device >',
                  onTap: isProcessing ? null : onAddGallery,
                ),
              ),
              const SizedBox(width: 8),

              // Scan Camera Card
              Expanded(
                child: _QuickAddCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Scan Camera',
                  subtitle: 'Capture new document >',
                  onTap: isProcessing ? null : onScanCamera,
                ),
              ),
              const SizedBox(width: 10),

              // Deep Blue Circular '+' FAB
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: isProcessing ? null : onAddAnother,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Tooltip(
                      message: 'Add Another Page',
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Primary "Review & Export PDF ✨" CTA Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: isProcessing ? null : onExportPdf,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Review & Export PDF',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                // Soft blue icon square
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: const Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
