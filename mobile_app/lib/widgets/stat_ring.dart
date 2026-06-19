import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class StatRing extends StatefulWidget {
  final double value;
  final String label;
  final IconData? icon;
  final Color color;
  final double size;

  const StatRing({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = CypherColors.accent,
    this.size  = 110,
  });

  @override
  State<StatRing> createState() => _StatRingState();
}

class _StatRingState extends State<StatRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(StatRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RingPainter(
                value: (widget.value * _controller.value).clamp(0.0, 1.0),
                color: widget.color,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, color: widget.color, size: widget.size * 0.25),
              const SizedBox(height: 4),
              Text(
                '${(widget.value * 100).round()}%',
                style: TextStyle(
                  fontSize: widget.size * 0.22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.size * 0.11,
                  fontWeight: FontWeight.w500,
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
    const strokeWidth = 8.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = const Color(0xFF1A1A24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final valuePaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.5), color],
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi * value,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

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
