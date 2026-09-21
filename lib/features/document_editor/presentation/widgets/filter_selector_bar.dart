import 'package:flutter/material.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Horizontal selection bar for the 5 document enhancement filters.
class FilterSelectorBar extends StatelessWidget {
  const FilterSelectorBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.enabled = true,
  });

  final DocumentFilterType selectedFilter;
  final ValueChanged<DocumentFilterType> onFilterSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: DocumentFilterType.values.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = DocumentFilterType.values[index];
          final isSelected = filter == selectedFilter;

          return _FilterOptionItem(
            filter: filter,
            isSelected: isSelected,
            enabled: enabled,
            onTap: () => onFilterSelected(filter),
          );
        },
      ),
    );
  }
}

class _FilterOptionItem extends StatelessWidget {
  const _FilterOptionItem({
    required this.filter,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final DocumentFilterType filter;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  IconData _getFilterIcon() {
    switch (filter) {
      case DocumentFilterType.original:
        return Icons.image_outlined;
      case DocumentFilterType.color:
        return Icons.palette_outlined;
      case DocumentFilterType.grayscale:
        return Icons.filter_b_and_w_outlined;
      case DocumentFilterType.blackAndWhite:
        return Icons.contrast;
      case DocumentFilterType.enhanced:
        return Icons.auto_fix_high;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = AppColors.primary;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFilterIcon(),
              size: 24,
              color: isSelected ? activeColor : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 6),
            Text(
              filter.displayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
