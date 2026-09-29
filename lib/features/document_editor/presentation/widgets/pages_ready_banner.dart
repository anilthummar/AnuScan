import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Banner displaying "All Pages Ready!" with stacked documents illustration and checkmark badge.
class PagesReadyBanner extends StatelessWidget {
  const PagesReadyBanner({
    super.key,
    this.title = 'All Pages Ready!',
    this.subtitle =
        'Your documents are scanned and ready to be exported as PDF.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDBEAFE).withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Left: Stacked Document Graphic with Checkmark
          const _StackedDocumentGraphic(),
          const SizedBox(width: 16),

          // Right: Status Copy
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedDocumentGraphic extends StatelessWidget {
  const _StackedDocumentGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Back tilted sheet
          Positioned(
            left: 4,
            top: 6,
            child: Transform.rotate(
              angle: -math.pi / 16,
              child: _buildMiniSheet(
                color: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
                borderColor: const Color(0xFF93C5FD),
              ),
            ),
          ),

          // Middle tilted sheet
          Positioned(
            left: 10,
            top: 4,
            child: Transform.rotate(
              angle: -math.pi / 32,
              child: _buildMiniSheet(
                color: Colors.white,
                borderColor: const Color(0xFFBFDBFE),
                hasLines: true,
              ),
            ),
          ),

          // Front prominent sheet
          Positioned(
            left: 14,
            top: 2,
            child: _buildMiniSheet(
              color: Colors.white,
              borderColor: const Color(0xFF93C5FD),
              hasLines: true,
              showTopBar: true,
            ),
          ),

          // Blue Circular Checkmark Badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSheet({
    required Color color,
    required Color borderColor,
    bool hasLines = false,
    bool showTopBar = false,
  }) {
    return Container(
      width: 34,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: hasLines
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTopBar)
                  Container(
                    width: 14,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  height: 2,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 3),
                Container(
                  width: double.infinity,
                  height: 2,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: 2,
                  color: const Color(0xFFE2E8F0),
                ),
              ],
            )
          : null,
    );
  }
}
