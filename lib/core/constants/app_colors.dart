import 'package:flutter/material.dart';

/// Central colour palette for LenDen.
/// All UI components must reference these — never raw hex values.
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF1A56DB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark  = Color(0xFF1E3A8A);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color danger       = Color(0xFFDC2626);
  static const Color dangerLight  = Color(0xFFFEE2E2);
  static const Color warning      = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningAmber = Color(0xFFFFC107); // offline banner

  // ── Neutrals (Light) ─────────────────────────────────────────────────────
  static const Color background     = Color(0xFFF9FAFB);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color border         = Color(0xFFE5E7EB);
  static const Color borderFocus    = Color(0xFF93C5FD);

  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled  = Color(0xFF9CA3AF);
  static const Color textHint      = Color(0xFFD1D5DB);

  // ── Neutrals (Dark) ───────────────────────────────────────────────────────
  static const Color darkBackground     = Color(0xFF0F172A);
  static const Color darkSurface        = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkBorder         = Color(0xFF475569);

  static const Color darkTextPrimary    = Color(0xFFF1F5F9);
  static const Color darkTextSecondary  = Color(0xFF94A3B8);

  // ── Shimmer ───────────────────────────────────────────────────────────────
  static const Color shimmerBase      = Color(0xFFE5E7EB);
  static const Color shimmerHighlight = Color(0xFFF9FAFB);

  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlay = Color(0x80000000);
}
