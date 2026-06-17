import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class StatRing extends StatelessWidget {
  final double value;
  final String label;
  final String? sublabel;
  final Color color;
  final double size;

  const StatRing({
    super.key,
    required this.value,
    required this.label,
    this.sublabel,
    this.color = CypherColors.accent,
    this.size  = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(value: value.clamp(0.0, 1.0), color: color),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.w700,
                  color: CypherColors.textPrimary,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: TextStyle(
                    fontSize: size * 0.13,
                    color: CypherColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color  = CypherColors.bgOverlay
      ..style  = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;

    final valuePaint = Paint()
      ..shader = SweepGradient(
          colors: [color.withOpacity(0.6), color],
          startAngle: -math.pi / 2,
          endAngle:   -math.pi / 2 + 2 * math.pi * value,
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style  = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), r, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}
