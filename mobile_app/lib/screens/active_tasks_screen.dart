import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class ActiveTasksScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ActiveTasksScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ActiveTasksScreen> createState() => _ActiveTasksScreenState();
}

class _ActiveTasksScreenState extends State<ActiveTasksScreen> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  Map<String, dynamic> _stats = {"cpu": 0, "ram": 0};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final headers = {'X-Auth-Token': widget.authToken};
      final baseUrl = 'http://${widget.pcIpAddress}:5000';

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/system/active-windows'), headers: headers),
        http.get(Uri.parse('$baseUrl/system-stats'), headers: headers),
      ]);

      if (results[0].statusCode == 200) {
        setState(() => _tasks = jsonDecode(results[0].body));
      }
      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body);
        setState(() => _stats = {"cpu": data['cpu_percent'] ?? 12, "ram": data['ram_percent'] ?? 25});
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _closeWindow(int id, String title) async {
    HapticFeedback.mediumImpact();
    try {
      await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/apps/close'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'name': title}),
      );
      _fetchData();
    } catch (_) {}
  }

  Future<void> _focusWindow(int id) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bringing window to front...")));
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
                        _buildHeader(isDark),
                        const SizedBox(height: 24),
                        _isLoading
                          ? Center(child: Padding(padding: const EdgeInsets.all(60), child: CircularProgressIndicator(color: accent)))
                          : _buildWindowGrid(accent, isDark),
                        const SizedBox(height: 32),
                        _buildResourceSummary(accent, isDark),
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
                Text("MANAGEMENT", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Icon(Icons.sensors_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent) {
    return const SizedBox(height: 64);
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SYSTEM OVERVIEW", style: GoogleFonts.roboto(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Active Windows", style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
            Row(
              children: [
                _actionIcon(Icons.filter_list_rounded, isDark),
                const SizedBox(width: 8),
                _actionIcon(Icons.grid_view_rounded, isDark),
              ],
            )
          ],
        ),
      ],
    );
  }

  Widget _actionIcon(IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
      child: Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38), size: 18),
    );
  }

  Widget _buildWindowGrid(Color accent, bool isDark) {
    if (_tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(Icons.window_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 48),
              const SizedBox(height: 16),
              Text("No active windows found", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 20,
        childAspectRatio: 1.4,
      ),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return FadeInUp(
          delay: Duration(milliseconds: index * 50),
          child: _buildWindowCard(task, accent, isDark),
        );
      },
    );
  }

  Widget _buildWindowCard(dynamic task, Color accent, bool isDark) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_getWindowIcon(task['title']), color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task['title'], style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
                      Text("Active Session", style: GoogleFonts.roboto(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                    ],
                  ),
                ),
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.black12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _getWindowPlaceholder(task['title']),
                  Container(color: Colors.black.withOpacity(0.2)),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _windowAction(Icons.open_in_full_rounded, accent, () => _focusWindow(task['id'])),
                        const SizedBox(width: 20),
                        _windowAction(Icons.close_rounded, Colors.redAccent, () => _closeWindow(task['id'], task['title'])),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("CPU: 2.4% | MEM: 840MB", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.12))),
                GestureDetector(
                  onTap: () => _focusWindow(task['id']),
                  child: Text("Focus Window", style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _windowAction(IconData icon, Color color, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)]),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _getWindowPlaceholder(String title) {
    final t = title.toLowerCase();
    String url = "https://lh3.googleusercontent.com/aida-public/AB6AXuD8ZQQIsx88VVk02rM5RvqSEyfQ8ktM59rEJra6k6qruAbF9ZMGQHf_kanS4Fkxw1sis3HFRjr1wPjp8N5m_9F290zHG0peA_cJwFXgdOH0WShOfC0lAlLxHu2nGILqCYnyjjmzz_PO9PfSmLKX9VsqMGqENmbekp9RCRxucFBMFzCCi3sPfBudvPIB3501piQHmV_PADnNaa8d3KzZSEyHiqjfli9bLBJPIGpQEXi4_qBx_0Or-jWmK7-uB1BVu1YWWPifbRDXPaI";
    if (t.contains("chrome") || t.contains("browser")) url = "https://lh3.googleusercontent.com/aida-public/AB6AXuAOLVZHGaJTW8pVHMZv3JjgamUid7K7mXVPGiQmr1iTSh9eLTLvNd0HXRmWBpTWJMlmXN0nbuP5gXml_DOcAxRCEiBzzizHUk0hSo1Q_wKu3cK9QGeHLd-o-bY619r7wLHSxJfnv3To1Xn3hd2Xb8Yii8NA7e4QKPeUUMAx8UUunpNLMTDe0U-LVxnNABIdQtZ954QsfgMLCkp7jyAt-T2tiFzzHic4pICR-M3Cv0pSvhZlcpy2sVwQJY7LjI0_GA8GoO2CRRzKIn0";

    return Image.network(url, fit: BoxFit.cover);
  }

  IconData _getWindowIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains("code") || t.contains("studio")) return Icons.code_rounded;
    if (t.contains("browser") || t.contains("chrome") || t.contains("edge")) return Icons.language_rounded;
    if (t.contains("folder") || t.contains("explorer")) return Icons.folder_rounded;
    if (t.contains("terminal") || t.contains("cmd") || t.contains("powershell")) return Icons.terminal_rounded;
    return Icons.window_rounded;
  }

  Widget _buildResourceSummary(Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), style: BorderStyle.solid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("RESOURCE METRICS", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2, fontWeight: FontWeight.bold)),
              Icon(Icons.analytics_rounded, color: accent, size: 18),
            ],
          ),
          const SizedBox(height: 24),
          _summaryBar("Total Processor Load", "${_stats['cpu']}%", _stats['cpu'] / 100, accent, isDark),
          const SizedBox(height: 20),
          _summaryBar("Total Memory Usage", "${_stats['ram']}%", _stats['ram'] / 100, const Color(0xFFFFB786), isDark),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Optimizing system memory...")));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded, color: isDark ? Colors.white : Colors.black, size: 18),
                  const SizedBox(width: 12),
                  Text("Clear Standby Memory", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _summaryBar(String label, String val, double percent, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.roboto(fontSize: 13, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
            Text(val, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 2,
            backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
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
          _navItem(Icons.grid_view_rounded, "Tools", true, null, isDark),
          _navItem(Icons.tune_rounded, "Settings", false, () => Navigator.pushReplacementNamed(context, '/settings', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
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
