import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

/// Solid premium card — BackdropFilter blur doesn't render on Flutter Windows,
/// so this uses layered containers: outer holds the shadow, inner is clipped + bordered.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double blur;       // kept for API compat, ignored
  final double opacity;    // kept for API compat, ignored
  final Color? color;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double? aspectRatio;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.blur = 20.0,
    this.opacity = 0.05,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.all(0),
    this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeService>(context).isDarkMode;

    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? (isDark ? const Color(0xFF16161A) : Colors.white),
            borderRadius: borderRadius,
            border: Border.all(
              color: isDark ? const Color(0xFF2A2A32) : const Color(0xFFE4E4E8),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio!, child: content);
    }
    return content;
  }
}
