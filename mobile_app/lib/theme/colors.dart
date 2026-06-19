import 'package:flutter/material.dart';

class CypherColors {
  CypherColors._();

  // ── DARK MODE ────────────────────────────────────────────────
  // Backgrounds
  static const bgDeep    = Color(0xFF08080F);
  static const bgPrimary = Color(0xFF0F0F17);
  static const bgCard    = Color(0xFF1A1A25);
  static const bgHover   = Color(0xFF252530);
  static const bgOverlay = Color(0xFF2A2A35);

  // Accent (Violet)
  static const accent       = Color(0xFF7C3AED);
  static const accentLight  = Color(0xFF8B5CF6);
  static const accentBright = Color(0xFFA78BFA);
  static       Color accentDim = const Color(0xFF7C3AED).withOpacity(0.15);
  static       Color accentGlow = const Color(0xFF7C3AED).withOpacity(0.25);

  // Semantic (stat ring colors)
  static const cpu     = Color(0xFFF43F5E); // rose
  static const ram     = Color(0xFF7C3AED); // violet
  static const storage = Color(0xFFF59E0B); // amber
  static const battery = Color(0xFF10B981); // emerald
  static const success = Color(0xFF22C55E);
  static const error   = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info    = Color(0xFF3B82F6);

  static       Color successDim = const Color(0xFF22C55E).withOpacity(0.15);
  static       Color errorDim   = const Color(0xFFEF4444).withOpacity(0.15);
  static       Color warningDim = const Color(0xFFF59E0B).withOpacity(0.15);

  // Text
  static const textPrimary   = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted     = Color(0xFF52525B);
  static const textDisabled  = Color(0xFF3F3F46);

  // Borders
  static       Color border      = const Color(0xFFFFFFFF).withOpacity(0.06);
  static       Color borderHover = const Color(0xFFFFFFFF).withOpacity(0.10);
  static       Color borderFocus = const Color(0xFF7C3AED).withOpacity(0.50);

  // ── LIGHT MODE ───────────────────────────────────────────────
  // Backgrounds
  static const lightBgPrimary = Color(0xFFF5F4FF);
  static const lightBgCard    = Color(0xFFFFFFFF);
  static const lightBgHover   = Color(0xFFF9F8FF);
  static const lightBgOverlay = Color(0xFFF0EFFF);

  // Text
  static const lightTextPrimary   = Color(0xFF0A0A1A);
  static const lightTextSecondary = Color(0xFF5A5975);
  static const lightTextMuted     = Color(0xFF8A8A9A);
  static const lightTextDisabled  = Color(0xFFB5B5C5);

  // Borders
  static       Color lightBorder      = const Color(0xFF0A0A1A).withOpacity(0.08);
  static       Color lightBorderHover = const Color(0xFF0A0A1A).withOpacity(0.12);
  static       Color lightBorderFocus = const Color(0xFF7C3AED).withOpacity(0.50);
}
