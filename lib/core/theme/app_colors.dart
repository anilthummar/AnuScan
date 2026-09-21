import 'package:flutter/material.dart';

/// Semantic and design system color tokens for AnuScan.
abstract class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF1E40AF); // Deep Indigo
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A8A);

  static const Color secondary = Color(0xFF0D9488); // Emerald Teal
  static const Color secondaryLight = Color(0xFF14B8A6);

  // Surface & Neutral Colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);

  // Typography Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // Functional Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0284C7);

  // Scanner & Overlay Specifics
  static const Color cropHandle = Color(0xFF2563EB);
  static const Color cropHandleBorder = Color(0xFFFFFFFF);
  static const Color cropOverlay = Color(0x66000000);
  static const Color cropLine = Color(0xFF38BDF8);
}
