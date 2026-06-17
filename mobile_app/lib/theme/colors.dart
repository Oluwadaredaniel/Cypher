import 'package:flutter/material.dart';

class CypherColors {
  CypherColors._();

  // ── Backgrounds ──────────────────────────────────────────────
  static const bgDeep    = Color(0xFF09090B);
  static const bgPrimary = Color(0xFF0F0F11);
  static const bgCard    = Color(0xFF18181B);
  static const bgHover   = Color(0xFF1F1F24);
  static const bgOverlay = Color(0xFF27272A);

  // ── Accent (Violet) ───────────────────────────────────────────
  static const accent       = Color(0xFF7C3AED);
  static const accentLight  = Color(0xFF8B5CF6);
  static const accentBright = Color(0xFFA78BFA);
  static       Color accentDim = const Color(0xFF7C3AED).withOpacity(0.15);
  static       Color accentGlow = const Color(0xFF7C3AED).withOpacity(0.25);

  // ── Semantic ──────────────────────────────────────────────────
  static const success = Color(0xFF22C55E);
  static const error   = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info    = Color(0xFF3B82F6);

  static       Color successDim = const Color(0xFF22C55E).withOpacity(0.15);
  static       Color errorDim   = const Color(0xFFEF4444).withOpacity(0.15);
  static       Color warningDim = const Color(0xFFF59E0B).withOpacity(0.15);

  // ── Text ──────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted     = Color(0xFF52525B);
  static const textDisabled  = Color(0xFF3F3F46);

  // ── Borders ───────────────────────────────────────────────────
  static       Color border      = const Color(0xFFFFFFFF).withOpacity(0.06);
  static       Color borderHover = const Color(0xFFFFFFFF).withOpacity(0.10);
  static       Color borderFocus = const Color(0xFF7C3AED).withOpacity(0.50);
}
