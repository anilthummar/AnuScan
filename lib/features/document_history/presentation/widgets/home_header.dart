import 'package:flutter/material.dart';

/// Top header bar displaying app logo, title, tagline, and action icons.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onSearchPressed,
    required this.onViewModeToggle,
    required this.onSettingsPressed,
    this.isGridMode = false,
  });

  final VoidCallback onSearchPressed;
  final VoidCallback onViewModeToggle;
  final VoidCallback onSettingsPressed;
  final bool isGridMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
      child: Row(
        children: [
          // App Logo Squircle with Scanner Graphic
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Viewfinder corners
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Document icon in center
                  const Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Tagline
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AnuScan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Scan  •  Detect  •  Save as PDF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Actions: Search, Grid/List, Settings
          IconButton(
            icon: const Icon(Icons.search, size: 24),
            color: const Color(0xFF0F172A),
            tooltip: 'Search',
            splashRadius: 20,
            onPressed: onSearchPressed,
          ),
          IconButton(
            icon: Icon(
              isGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 22,
            ),
            color: const Color(0xFF0F172A),
            tooltip: isGridMode ? 'List View' : 'Grid View',
            splashRadius: 20,
            onPressed: onViewModeToggle,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            color: const Color(0xFF0F172A),
            tooltip: 'Settings',
            splashRadius: 20,
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}
