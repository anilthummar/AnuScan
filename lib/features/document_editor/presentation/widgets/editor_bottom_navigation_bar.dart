import 'package:flutter/material.dart';

/// 4-tab bottom navigation bar for Document Editor screen:
/// [Documents] (active), [Categories], [Favorites], [Profile]
class EditorBottomNavigationBar extends StatelessWidget {
  const EditorBottomNavigationBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: 'Documents',
                icon: Icons.description_outlined,
                selectedIcon: Icons.description,
              ),
              _buildNavItem(
                index: 1,
                label: 'Categories',
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view_rounded,
              ),
              _buildNavItem(
                index: 2,
                label: 'Favorites',
                icon: Icons.star_outline_rounded,
                selectedIcon: Icons.star_rounded,
              ),
              _buildNavItem(
                index: 3,
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final isSelected = currentIndex == index;
    const activeColor = Color(0xFF1D4ED8);
    const inactiveColor = Color(0xFF64748B);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (onTap != null) {
            onTap!(index);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            // Blue active underline indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 22 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
