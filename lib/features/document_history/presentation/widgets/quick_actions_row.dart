import 'package:flutter/material.dart';

/// 4 Quick Action cards matching the AnuScan design:
/// [Import Gallery] [Create PDF] [Cloud Backup] [App Lock]
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.onImportGallery,
    required this.onCreatePdf,
    required this.onCloudBackup,
    required this.onAppLock,
  });

  final VoidCallback onImportGallery;
  final VoidCallback onCreatePdf;
  final VoidCallback onCloudBackup;
  final VoidCallback onAppLock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 1. Import Gallery
          Expanded(
            child: _ActionCard(
              title: 'Import\nGallery',
              icon: Icons.image_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFDBEAFE),
              cardBgColor: const Color(0xFFEFF6FF),
              onTap: onImportGallery,
            ),
          ),
          const SizedBox(width: 8),

          // 2. Create PDF
          Expanded(
            child: _ActionCard(
              title: 'Create\nPDF',
              icon: Icons.picture_as_pdf_outlined,
              iconColor: const Color(0xFF9333EA),
              iconBgColor: const Color(0xFFF3E8FF),
              cardBgColor: const Color(0xFFFAF5FF),
              onTap: onCreatePdf,
            ),
          ),
          const SizedBox(width: 8),

          // 3. Cloud Backup
          Expanded(
            child: _ActionCard(
              title: 'Cloud\nBackup',
              icon: Icons.cloud_outlined,
              iconColor: const Color(0xFF16A34A),
              iconBgColor: const Color(0xFFDCFCE7),
              cardBgColor: const Color(0xFFF0FDF4),
              onTap: onCloudBackup,
            ),
          ),
          const SizedBox(width: 8),

          // 4. App Lock
          Expanded(
            child: _ActionCard(
              title: 'App Lock\n',
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFFD97706),
              iconBgColor: const Color(0xFFFEF3C7),
              cardBgColor: const Color(0xFFFFFBEB),
              onTap: onAppLock,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.cardBgColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color cardBgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: iconBgColor.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),

              // Title and Arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: iconColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
