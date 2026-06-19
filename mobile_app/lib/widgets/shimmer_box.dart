import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/colors.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:      CypherColors.bgCard,
      highlightColor: CypherColors.bgHover,
      child: Container(
        width:  width,
        height: height,
        decoration: BoxDecoration(
          color:        CypherColors.bgCard,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const ShimmerList({super.key, this.count = 6, this.itemHeight = 64});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ShimmerBox(width: double.infinity, height: itemHeight, radius: 12),
      )),
    );
  }
}

class ShimmerStatRow extends StatelessWidget {
  const ShimmerStatRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: ShimmerBox(height: 80, radius: 12)),
        const SizedBox(width: 12),
        const Expanded(child: ShimmerBox(height: 80, radius: 12)),
        const SizedBox(width: 12),
        const Expanded(child: ShimmerBox(height: 80, radius: 12)),
      ],
    );
  }
}
