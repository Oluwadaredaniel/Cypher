import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/glass_container.dart';

class ActivityTab extends StatefulWidget {
  final bool isDark;
  final Color accent;
  final List<dynamic> logs;

  const ActivityTab({
    super.key,
    required this.isDark,
    required this.accent,
    required this.logs,
  });

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  String _activityFilter = "All Events";

  List<dynamic> get _filteredLogs {
    if (_activityFilter == "All Events") return widget.logs;
    return widget.logs.where((log) => (log['category'] ?? "").toString() == _activityFilter).toList();
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
              _buildHeader("System Activity", "Historical records of connections and tasks."),
              _buildLogFilters(),
            ],
          ),
          const SizedBox(height: 48),
          if (_filteredLogs.isEmpty)
            GlassContainer(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 64, color: widget.isDark ? Colors.white10 : Colors.black12),
                    const SizedBox(height: 16),
                    Text("No activity recorded yet.",
                        style: GoogleFonts.inter(color: widget.isDark ? Colors.white24 : Colors.black26, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Interactions from your mobile app will appear here.",
                        style: GoogleFonts.inter(color: widget.isDark ? Colors.white10 : Colors.black12, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            _buildTimeline(),
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
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF10B981), letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 6),
        Text(title, style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : Colors.black, height: 1.1)),
        Text(sub, style: GoogleFonts.inter(fontSize: 12, color: widget.isDark ? Colors.white30 : Colors.black38)),
      ],
    );
  }

  Widget _buildLogFilters() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.black12)),
      child: Row(
        children: ["All Events", "Connections", "Transfers", "Commands", "Security"].map((f) {
          bool active = _activityFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _activityFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: active ? widget.accent : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Text(f, style: GoogleFonts.inter(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? Colors.white : (widget.isDark ? Colors.white38 : Colors.black38))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeline() {
    final logs = _filteredLogs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: logs.map((log) {
        return _timelineItem(
          log['title'] ?? "Unknown Event",
          log['desc'] ?? "",
          log['time'] ?? "--:--:--",
          _getIconForCategory(log['category']),
          _getColorForCategory(log['category']),
          isUrgent: log['is_urgent'] ?? false,
          attachment: log['attachment'],
        );
      }).toList(),
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category) {
      case "Connections": return Icons.smartphone_rounded;
      case "Transfers": return Icons.sync_alt_rounded;
      case "Commands": return Icons.terminal_rounded;
      case "Security": return Icons.shield_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _getColorForCategory(String? category) {
    switch (category) {
      case "Connections": return widget.accent;
      case "Transfers": return const Color(0xFFFFB786);
      case "Commands": return Colors.redAccent;
      case "Security": return const Color(0xFFF59E0B);
      default: return const Color(0xFF10B981);
    }
  }

  Widget _timelineItem(String title, String desc, String time, IconData icon, Color color, {bool isUrgent = false, String? attachment}) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: widget.isDark ? Colors.white10 : Colors.black12, width: 2))),
              Container(width: 2, height: 100, color: widget.isDark ? Colors.white10 : Colors.black12),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 12),
                          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(time, style: GoogleFonts.inter(fontSize: 9, color: widget.isDark ? Colors.white12 : Colors.black12)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: (isUrgent ? Colors.redAccent : const Color(0xFF10B981)).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(isUrgent ? "CRITICAL" : "SUCCESS", style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.bold, color: isUrgent ? Colors.redAccent : const Color(0xFF10B981))),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(desc, style: GoogleFonts.inter(fontSize: 13, color: widget.isDark ? Colors.white38 : Colors.black45)),
                  if (attachment != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_zip_rounded, size: 14, color: widget.isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(width: 8),
                          Text(attachment, style: GoogleFonts.inter(fontSize: 9, color: widget.isDark ? Colors.white38 : Colors.black45)),
                        ],
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
