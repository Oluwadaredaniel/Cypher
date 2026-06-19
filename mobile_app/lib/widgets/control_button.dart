import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class ControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool active;
  final double size;

  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.active = false,
    this.size   = 60,
  });

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? (widget.active ? CypherColors.accent : CypherColors.textSecondary);

    return GestureDetector(
      onTapDown: (_) { HapticFeedback.lightImpact(); _ctrl.forward(); },
      onTapUp:   (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width:  widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.active
                    ? CypherColors.accentDim
                    : CypherColors.bgCard,
                borderRadius: BorderRadius.circular(widget.size * 0.28),
                border: Border.all(
                  color: widget.active
                      ? CypherColors.borderFocus
                      : CypherColors.border,
                ),
              ),
              child: Icon(widget.icon, color: color, size: widget.size * 0.44),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: CypherColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
