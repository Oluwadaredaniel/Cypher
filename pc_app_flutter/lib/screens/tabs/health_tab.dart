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
    double cpu = (stats['cpu_percent'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader("Performance", "Monitoring live computer resources."),
              _actionBtn(
                isOptimizing ? "Optimizing..." : "Optimize System",
                Icons.bolt_rounded,
                onTap: isOptimizing ? null : onOptimize,
                isLoading: isOptimizing,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 8,
                child: GlassContainer(
                  padding: const EdgeInsets.all(28),
                  height: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.memory_rounded, color: accent, size: 20),
                              const SizedBox(width: 12),
                              Text("Processor Performance", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            ],
                          ),
                          _buildStatusPill(cpu > 70 ? "High Usage" : "Stable", cpu > 70),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${cpu.toInt()}", style: GoogleFonts.roboto(fontSize: 48, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, left: 4),
                            child: Text("%", style: GoogleFonts.roboto(fontSize: 18, color: isDark ? Colors.white24 : Colors.black26)),
                          ),
                          const SizedBox(width: 48),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Active Threads", style: GoogleFonts.roboto(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26)),
                              Text("Dynamic", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            ],
                          )
                        ],
                      ),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: waveAnimation,
                        builder: (context, child) {
                          return SizedBox(
                            height: 100, width: double.infinity,
                            child: CustomPaint(painter: WaveformPainter(accent.withOpacity(0.3), waveAnimation.value, cpu)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildSmallCard("System Uptime", stats['uptime'] ?? "Active", Icons.timer_rounded, const Color(0xFFFFB786), 1.0),
                    const SizedBox(height: 24),
                    _buildSmallCard("Link Status", "Secure", Icons.link_rounded, const Color(0xFFC0C6DB), 1.0),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildMemoryCard(),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text("LIVE CONNECTION", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        Text(sub, style: GoogleFonts.roboto(fontSize: 14, color: isDark ? Colors.white24 : Colors.black38)),
      ],
    );
  }

  Widget _buildMemoryCard() {
    double ramP = (stats['ram_percent'] as num?)?.toDouble() ?? 0.0;
    double ramUsed = (stats['ram_used'] as num?)?.toDouble() ?? 0.0;
    double ramTotal = (stats['ram_total'] as num?)?.toDouble() ?? 0.0;

    return GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          SizedBox(
            width: 100, height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: 1.0, strokeWidth: 8, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                CircularProgressIndicator(value: (ramP / 100).clamp(0.0, 1.0), strokeWidth: 8, color: accent, strokeCap: StrokeCap.round),
                Text("${ramP.toInt()}%", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.memory_rounded, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Text("Memory Allocation", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  ],
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _metric("In Use", "$ramUsed GB"),
                      const SizedBox(width: 48),
                      _metric("Available", "${(ramTotal - ramUsed).toStringAsFixed(1)} GB"),
                      const SizedBox(width: 48),
                      _metric("Hardware Total", "$ramTotal GB"),
                    ],
                  ),
                )
              ],
            ),
          ),
          _buildStatusPill("Healthy", false),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, String val, IconData icon, Color color, double progress) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      height: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text("Stable", style: GoogleFonts.roboto(fontSize: 10, color: isDark ? Colors.white12 : Colors.black12)),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(val.split(' ').first, style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(width: 4),
              Text(val.contains(' ') ? val.split(' ').last : "", style: GoogleFonts.roboto(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26)),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, minHeight: 2, backgroundColor: isDark ? Colors.white10 : Colors.black12, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.roboto(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26)),
        Text(val, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      ],
    );
  }

  Widget _buildStatusPill(String label, bool isWarning) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: (isWarning ? Colors.redAccent : (isDark ? Colors.white10 : Colors.black12)).withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: isWarning ? Colors.redAccent : (isDark ? Colors.white24 : Colors.black26), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold, color: isWarning ? Colors.redAccent : (isDark ? Colors.white38 : Colors.black38))),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, {VoidCallback? onTap, bool isLoading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isLoading ? accent.withOpacity(0.5) : accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
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
    double phase = animationValue * 2 * pi * (1 + (cpuUsage / 50));
    path.moveTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      double relativeX = i / size.width;
      double amplitude = (size.height * 0.2) + (cpuUsage * 0.4);
      double y = size.height * 0.6 + sin(relativeX * 5 * pi + phase) * amplitude * (1 - relativeX);
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
