import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/glass_container.dart';

class HealthTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isDark;
  final Animation<double> waveAnimation;
  final Color accent;
  final VoidCallback onOptimize;
  final bool isOptimizing;

  const HealthTab({
    super.key,
    required this.stats,
    required this.isDark,
    required this.waveAnimation,
    required this.accent,
    required this.onOptimize,
    required this.isOptimizing,
  });

  @override
  Widget build(BuildContext context) {
    final double cpu = (stats['cpu_percent'] as num?)?.toDouble() ?? 0.0;
    final double ramP = (stats['ram_percent'] as num?)?.toDouble() ?? 0.0;
    final double ramUsed = (stats['ram_used'] as num?)?.toDouble() ?? 0.0;
    final double ramTotal = (stats['ram_total'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: _buildCpuCard(cpu)),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildMiniCard('System Uptime', stats['uptime'] ?? 'Active', Icons.timer_rounded, const Color(0xFFFFB786)),
                    const SizedBox(height: 16),
                    _buildMiniCard('Link Status', 'Secure', Icons.link_rounded, const Color(0xFF10B981)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMemoryCard(ramP, ramUsed, ramTotal),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF10B981), letterSpacing: 2)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Performance', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, height: 1.1)),
          ],
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: isOptimizing ? null : onOptimize,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: isOptimizing ? accent.withOpacity(0.4) : accent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isOptimizing ? null : [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  if (isOptimizing)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.bolt_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Text(isOptimizing ? 'Optimizing...' : 'Optimize System', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCpuCard(double cpu) {
    final isHigh = cpu > 70;
    final cpuColor = isHigh ? const Color(0xFFEF4444) : accent;

    return GlassContainer(
      padding: const EdgeInsets.all(28),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: cpuColor.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                    child: Icon(Icons.memory_rounded, color: cpuColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text('Processor', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                ],
              ),
              _statusPill(isHigh ? 'High Load' : 'Stable', isHigh),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${cpu.toInt()}', style: GoogleFonts.inter(fontSize: 52, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 9, left: 3),
                child: Text('%', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w500, color: isDark ? Colors.white30 : Colors.black38)),
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Threads', style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white30 : Colors.black38)),
                  const SizedBox(height: 2),
                  Text('Dynamic', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                ],
              ),
            ],
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: waveAnimation,
            builder: (context, _) => SizedBox(
              height: 90, width: double.infinity,
              child: CustomPaint(painter: WaveformPainter(cpuColor.withOpacity(0.25), waveAnimation.value, cpu)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String title, String val, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      height: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('OK', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF10B981), letterSpacing: 1)),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white30 : Colors.black38, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(val, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
            ],
          ),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(double ramP, double ramUsed, double ramTotal) {
    final ramFree = ramTotal - ramUsed;
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          SizedBox(
            width: 110, height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: 1.0, strokeWidth: 10, color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                CircularProgressIndicator(value: (ramP / 100).clamp(0.0, 1.0), strokeWidth: 10, color: accent, strokeCap: StrokeCap.round),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${ramP.toInt()}%', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, height: 1.1)),
                    Text('RAM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? Colors.white30 : Colors.black38, letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                      child: Icon(Icons.developer_board_rounded, color: accent, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text('Memory', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                    const Spacer(),
                    _statusPill('Healthy', false),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _memMetric('In Use', '${ramUsed.toStringAsFixed(1)} GB', accent),
                    const SizedBox(width: 32),
                    _memMetric('Available', '${ramFree.toStringAsFixed(1)} GB', const Color(0xFF10B981)),
                    const SizedBox(width: 32),
                    _memMetric('Total', '${ramTotal.toStringAsFixed(0)} GB', isDark ? Colors.white38 : Colors.black38),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memMetric(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white30 : Colors.black38, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(val, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _statusPill(String label, bool isWarning) {
    final c = isWarning ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.25))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final Color color;
  final double animationValue;
  final double cpuUsage;
  WaveformPainter(this.color, this.animationValue, this.cpuUsage);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    final phase = animationValue * 2 * pi * (1 + (cpuUsage / 50));
    path.moveTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      final relX = i / size.width;
      final amplitude = (size.height * 0.2) + (cpuUsage * 0.4);
      final y = size.height * 0.6 + sin(relX * 5 * pi + phase) * amplitude * (1 - relX);
      path.lineTo(i, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
