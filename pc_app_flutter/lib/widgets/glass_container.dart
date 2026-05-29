import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double blur;
  final double opacity;
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
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = const EdgeInsets.all(0),
    this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeService>(context).isDarkMode;
    final baseColor = color ?? (isDark ? Colors.white : Colors.black);
    final borderOpacity = isDark ? 0.08 : 0.12;

    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: baseColor.withOpacity(opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(borderOpacity),
              width: 0.5,
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
