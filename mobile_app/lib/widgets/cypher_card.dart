import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class CypherCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool glowing;
  final bool interactive;

  const CypherCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color,
    this.glowing    = false,
    this.interactive = true,
  });

  @override
  State<CypherCard> createState() => _CypherCardState();
}

class _CypherCardState extends State<CypherCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  void _down(_) {
    if (!widget.interactive || widget.onTap == null) return;
    HapticFeedback.selectionClick();
    setState(() => _pressed = true);
  }

  void _up(_) => setState(() => _pressed = false);
  void _cancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? CypherColors.bgCard;
    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: widget.padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pressed ? CypherColors.bgHover : base,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.glowing ? CypherColors.accentGlow : CypherColors.border,
            width: widget.glowing ? 1.5 : 1,
          ),
          boxShadow: widget.glowing
              ? [
                  BoxShadow(
                    color: CypherColors.accentGlow,
                    blurRadius: 20,
                    spreadRadius: -4,
                  )
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

class CypherSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const CypherSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CypherColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: CypherColors.accentBright,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
