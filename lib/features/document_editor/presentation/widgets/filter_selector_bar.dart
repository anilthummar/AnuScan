import 'package:flutter/material.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Horizontal selection bar for the 5 document enhancement filters.
class FilterSelectorBar extends StatelessWidget {
  const FilterSelectorBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.bwIntensity = BwIntensity.medium,
    this.onBwIntensityChanged,
    this.enabled = true,
  });

  final ScanFilter selectedFilter;
  final ValueChanged<ScanFilter> onFilterSelected;
  final BwIntensity bwIntensity;
  final ValueChanged<BwIntensity>? onBwIntensityChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selectedFilter == DocumentFilterType.blackAndWhite &&
            onBwIntensityChanged != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'B&W Intensity: ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                ...BwIntensity.values.map((intensity) {
                  final isCurrent = intensity == bwIntensity;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(intensity.displayName),
                      selected: isCurrent,
                      onSelected: enabled
                          ? (selected) {
                              if (selected) onBwIntensityChanged!(intensity);
                            }
                          : null,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white12,
                      labelStyle: TextStyle(
                        color: isCurrent ? Colors.white : Colors.white70,
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
        ],
        Container(
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
        ),
      ],
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
