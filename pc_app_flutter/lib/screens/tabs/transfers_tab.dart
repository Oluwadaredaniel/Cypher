import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/glass_container.dart';

class TransfersTab extends StatelessWidget {
  final Map<String, dynamic> activeTransfers;
  final List<dynamic> activityLog;
  final bool isDark;
  final Color accent;

  const TransfersTab({
    super.key,
    required this.activeTransfers,
    required this.activityLog,
    required this.isDark,
    required this.accent,
  });

  List<dynamic> get _recentTransfers {
    return activityLog.where((log) => log['category'] == "Transfers").take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader("File Progress", "Managing items being sent and received."),
              Row(
                children: [
                  _actionBtn("Filter", Icons.filter_list_rounded, isOutline: true),
                  const SizedBox(width: 12),
                  _actionBtn("New Sync", Icons.add_rounded),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: activeTransfers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(100),
                          child: Text("No active transfers",
                              style: TextStyle(color: isDark ? Colors.white10 : Colors.black12)),
                        ),
                      )
                    : Column(
                        children: activeTransfers.entries.map((e) {
                          final t = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildTransferCard(
                              t['name'] ?? "Unknown File",
                              t['status'] == 'receiving' ? "Phone ➔ Computer" : "Computer ➔ Phone",
                              ((t['progress'] ?? 0) as num).toDouble() / 100,
                              t['speed'] ?? "0 MB/s",
                              "Syncing",
                              isPaused: t['status'] == 'paused',
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildPerformanceCard(),
                    const SizedBox(height: 16),
                    _buildRecentHistoryCard(),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _actionBtn(String label, IconData icon, {bool isOutline = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : accent,
        borderRadius: BorderRadius.circular(12),
        border: isOutline ? Border.all(color: isDark ? Colors.white10 : Colors.black12) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: isOutline ? accent : Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold, color: isOutline ? accent : Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTransferCard(String name, String direction, double progress, String speed, String time, {bool isPaused = false}) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.description_rounded, color: isPaused ? Colors.white24 : accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 4),
                    Text(direction, style: GoogleFonts.roboto(fontSize: 12, color: isDark ? Colors.white24 : Colors.black38)),
                  ],
                ),
              ),
              if (!isPaused)
                Row(
                  children: [
                    _miniIconBtn(Icons.pause_rounded),
                    const SizedBox(width: 8),
                    _miniIconBtn(Icons.close_rounded, color: Colors.redAccent),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isPaused ? "Paused" : "Syncing...", style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26)),
              Text("${(progress * 100).toInt()}%", style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: isPaused ? (isDark ? Colors.white24 : Colors.black26) : accent)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), valueColor: AlwaysStoppedAnimation(isPaused ? (isDark ? Colors.white10 : Colors.black12) : accent)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat(Icons.speed_rounded, speed),
              const SizedBox(width: 24),
              _miniStat(Icons.timer_rounded, time),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniIconBtn(IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), shape: BoxShape.circle),
      child: Icon(icon, color: color ?? (isDark ? Colors.white30 : Colors.black26), size: 16),
    );
  }

  Widget _miniStat(IconData icon, String val) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white12 : Colors.black12),
        const SizedBox(width: 8),
        Text(val, style: GoogleFonts.roboto(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45)),
      ],
    );
  }

  Widget _buildPerformanceCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("SYNC PERFORMANCE", style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bar(0.3), _bar(0.5), _bar(0.8), _bar(0.6),
              _bar(activeTransfers.isNotEmpty ? 1.0 : 0.2, active: activeTransfers.isNotEmpty),
              _bar(activeTransfers.isNotEmpty ? 0.85 : 0.1, active: activeTransfers.isNotEmpty),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric("Active Transfers", "${activeTransfers.length}", accent),
              _metric("Status", activeTransfers.isNotEmpty ? "Syncing" : "Idle", const Color(0xFFFFB786)),
            ],
          )
        ],
      ),
    );
  }

  Widget _bar(double h, {bool active = false}) {
    return Container(
      width: 12, height: 80 * h,
      decoration: BoxDecoration(color: active ? accent : accent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _metric(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.roboto(fontSize: 11, color: isDark ? Colors.white24 : Colors.black38)),
        Text(val, style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      ],
    );
  }

  Widget _buildRecentHistoryCard() {
    final history = _recentTransfers;
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("RECENT", style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold)),
              Text("View All", style: GoogleFonts.roboto(fontSize: 11, color: accent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          if (history.isEmpty)
             Text("No recent transfers", style: GoogleFonts.roboto(fontSize: 12, color: isDark ? Colors.white10 : Colors.black12))
          else
            ...history.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _historyItem(h['attachment'] ?? h['title'], "Completed • ${h['time']}"),
            )).toList(),
        ],
      ),
    );
  }

  Widget _historyItem(String name, String sub) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(sub, style: GoogleFonts.roboto(fontSize: 10, color: isDark ? Colors.white12 : Colors.black12)),
            ],
          ),
        )
      ],
    );
  }
}
