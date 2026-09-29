import 'package:flutter/material.dart';
import '../../domain/entities/document_counts.dart';
import '../../domain/entities/document_query_filter.dart';

/// Horizontal pill filter row matching AnuScan UI design:
/// [All (count)] [Favorites (count)] [Archived (count)] [Private (count)]
class StatusFilterPills extends StatelessWidget {
  const StatusFilterPills({
    super.key,
    required this.activeTab,
    required this.counts,
    required this.onTabSelected,
  });

  final DocumentTab activeTab;
  final DocumentCounts counts;
  final ValueChanged<DocumentTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildPill(
            tab: DocumentTab.all,
            label: 'All (${counts.activeCount})',
            icon: Icons.check_rounded,
            isSelected: activeTab == DocumentTab.all,
          ),
          const SizedBox(width: 8),
          _buildPill(
            tab: DocumentTab.favorites,
            label: 'Favorites (${counts.favoriteCount})',
            icon: Icons.star_outline_rounded,
            isSelected: activeTab == DocumentTab.favorites,
          ),
          const SizedBox(width: 8),
          _buildPill(
            tab: DocumentTab.archived,
            label: 'Archived (${counts.archivedCount})',
            icon: Icons.access_time_rounded,
            isSelected: activeTab == DocumentTab.archived,
          ),
          const SizedBox(width: 8),
          _buildPill(
            tab: DocumentTab.private,
            label: 'Private (${counts.privateCount})',
            icon: Icons.lock_outline_rounded,
            isSelected: activeTab == DocumentTab.private,
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required DocumentTab tab,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTabSelected(tab),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1D4ED8) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_rounded : icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
