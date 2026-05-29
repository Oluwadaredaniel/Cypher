import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class ActivityScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ActivityScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
  List<dynamic> _logs = [];
  String _activeFilter = "All Events";
  Map<String, dynamic> _stats = {"transfers": 0, "health": "Nominal"};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final headers = {'X-Auth-Token': widget.authToken};
      final baseUrl = 'http://${widget.pcIpAddress}:5000';

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/system/activity'), headers: headers),
        http.get(Uri.parse('$baseUrl/files/transfers'), headers: headers),
      ]).timeout(const Duration(seconds: 5));

      if (results[0].statusCode == 200) {
        if (mounted) setState(() => _logs = jsonDecode(results[0].body));
      }

      if (results[1].statusCode == 200) {
        final transfers = jsonDecode(results[1].body) as Map;
        if (mounted) setState(() => _stats["transfers"] = transfers.length);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredLogs {
    if (_activeFilter == "All Events") return _logs;
    return _logs.where((log) => log['category'] == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(accent),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryGrid(accent, isDark),
                        const SizedBox(height: 32),
                        _buildFilterHeader(isDark),
                        const SizedBox(height: 24),
                        _isLoading
                          ? const Center(child: Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator()))
                          : _buildActivityStream(accent, isDark),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFloatingHeader(accent, isDark),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav(isDark)),
        ],
      ),
    );
  }

  Widget _buildFloatingHeader(Color accent, bool isDark) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7)).withOpacity(0.8),
          border: Border(bottom: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
                Text("ACTIVITY", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            IconButton(icon: Icon(Icons.refresh_rounded, color: accent, size: 18), onPressed: _fetchData),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent) => const SizedBox(height: 64);

  Widget _buildSummaryGrid(Color accent, bool isDark) {
    return Column(
      children: [
        _summaryBento("Active Transfers", "${_stats['transfers']}", Icons.sync_rounded, accent, isDark, sub: "Tracking file updates in real-time."),
        const SizedBox(height: 12),
        _summaryBento("System Status", _stats['health'], Icons.check_circle_outline_rounded, const Color(0xFF10B981), isDark, sub: "Everything is running smoothly."),
      ],
    );
  }

  Widget _summaryBento(String label, String value, IconData icon, Color color, bool isDark, {double? progress, String? sub}) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label.toUpperCase(), style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                if (sub != null) Text(sub, style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: color, size: 24),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("ACTIVITY STREAM", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: ["All Events", "Transfers", "Commands", "Connections"].map((f) {
              bool active = _activeFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _activeFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF6C63FF) : (isDark ? const Color(0xFF192029) : Colors.white).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(f, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : (isDark ? Colors.white24 : Colors.black26))),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityStream(Color accent, bool isDark) {
    final logs = _filteredLogs;
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Text("No events found in this category.", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.12), fontSize: 13)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          delay: Duration(milliseconds: index * 20),
          child: _buildLogItem(logs[index], accent, isDark),
        );
      },
    );
  }

  Widget _buildLogItem(dynamic log, Color accent, bool isDark) {
    final category = log['category']?.toString() ?? "General";
    final time = log['time'] ?? "--:--";

    IconData icon = Icons.info_outline_rounded;
    Color color = accent;

    if (category == "Commands") { icon = Icons.terminal_rounded; color = Colors.redAccent; }
    else if (category == "Transfers") { icon = Icons.sync_alt_rounded; color = const Color(0xFFFFB786); }
    else if (category == "Connections") { icon = Icons.smartphone_rounded; color = accent; }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF192029) : Colors.white).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(log['title'] ?? "System Update", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    Text(time, style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.12))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(log['desc'] ?? "Operation completed successfully.", style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context), isDark),
          _navItem(Icons.folder_copy_rounded, "Files", false, () => Navigator.pushReplacementNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
          _navItem(Icons.grid_view_rounded, "Tools", false, () => Navigator.pushReplacementNamed(context, '/controls', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
          _navItem(Icons.tune_rounded, "Settings", false, null, isDark),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, [VoidCallback? tap, bool isDark = true]) {
    final accent = const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: tap,
      child: Opacity(
        opacity: active ? 1.0 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? accent : (isDark ? Colors.white : Colors.black), size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: active ? accent : (isDark ? Colors.white : Colors.black))),
          ],
        ),
      ),
    );
  }
}
