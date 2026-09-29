import 'package:flutter/material.dart';

/// Category item descriptor.
class _CategoryItem {
  const _CategoryItem({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  final String name;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
}

/// Horizontal category selector card displaying colorful category icon circles
/// [All] [Invoice] [Receipt] [Business Card] [Contract]
class CategorySelectorCard extends StatelessWidget {
  const CategorySelectorCard({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  static const _categories = [
    _CategoryItem(
      name: 'All',
      icon: Icons.description_outlined,
      iconColor: Color(0xFF059669),
      bgColor: Color(0xFFE6F9F0),
    ),
    _CategoryItem(
      name: 'Invoice',
      icon: Icons.description_outlined,
      iconColor: Color(0xFF2563EB),
      bgColor: Color(0xFFEBF5FE),
    ),
    _CategoryItem(
      name: 'Receipt',
      icon: Icons.receipt_long_outlined,
      iconColor: Color(0xFF9333EA),
      bgColor: Color(0xFFF3E8FF),
    ),
    _CategoryItem(
      name: 'Business Card',
      icon: Icons.badge_outlined,
      iconColor: Color(0xFFD97706),
      bgColor: Color(0xFFFEF3C7),
    ),
    _CategoryItem(
      name: 'Contract',
      icon: Icons.history_edu_outlined,
      iconColor: Color(0xFFEF4444),
      bgColor: Color(0xFFFEE2E2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _categories.map((item) {
          final isSelected = selectedCategory == item.name ||
              (selectedCategory.isEmpty && item.name == 'All');

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onCategorySelected(item.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected && item.name == 'All'
                      ? item.bgColor.withValues(alpha: 0.7)
                      : isSelected
                          ? item.bgColor.withValues(alpha: 0.5)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular icon container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.bgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        color: item.iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Category label
                    Text(
                      item.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected && item.name == 'All'
                            ? item.iconColor
                            : isSelected
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
