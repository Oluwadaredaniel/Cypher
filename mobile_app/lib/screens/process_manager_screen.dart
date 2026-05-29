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

class ProcessManagerScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ProcessManagerScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ProcessManagerScreen> createState() => _ProcessManagerScreenState();
}

class _ProcessManagerScreenState extends State<ProcessManagerScreen> {
  bool _isLoading = true;
  List<dynamic> _processes = [];
  Map<String, dynamic> _systemStats = {"cpu": 0, "ram": 0, "network": 0};
  Timer? _refreshTimer;
  final TextEditingController _filterController = TextEditingController();
  List<dynamic> _filteredProcesses = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) _fetchData(isSilent: true);
    });
  }

  Future<void> _fetchData({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final headers = {'X-Auth-Token': widget.authToken};
      final baseUrl = 'http://${widget.pcIpAddress}:5000';

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/processes'), headers: headers),
        http.get(Uri.parse('$baseUrl/system-stats'), headers: headers),
      ]);

      if (results[0].statusCode == 200 && mounted) {
        final List data = jsonDecode(results[0].body);
        data.sort((a, b) => (b['cpu_percent'] as num).compareTo(a['cpu_percent'] as num));
        setState(() {
          _processes = data;
          _applyFilter(_filterController.text);
        });
      }

      if (results[1].statusCode == 200 && mounted) {
        final stats = jsonDecode(results[1].body);
        setState(() {
          _systemStats = {
            "cpu": stats['cpu_percent'] ?? 0,
            "ram": stats['ram_percent'] ?? 0,
            "network": stats['disk_percent'] ?? 0,
          };
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilter(String query) {
    setState(() {
      _filteredProcesses = _processes.where((p) {
        final name = p['name'].toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _killProcess(int pid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("End Task?", style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to stop $name?", style: GoogleFonts.roboto(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("CANCEL", style: GoogleFonts.roboto(color: Colors.white24))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("END TASK"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.heavyImpact();
    try {
      final res = await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/processes/kill'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'pid': pid}),
      );
      if (res.statusCode == 200) {
        _fetchData(isSilent: true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Process stopped successfully")));
      }
    } catch (_) {}
  }

  IconData _getProcessIcon(String name) {
    name = name.toLowerCase();
    if (name.contains("chrome") || name.contains("edge") || name.contains("browser")) return Icons.public_rounded;
    if (name.contains("code") || name.contains("studio")) return Icons.code_rounded;
    if (name.contains("spotify") || name.contains("music")) return Icons.music_note_rounded;
    if (name.contains("discord") || name.contains("slack")) return Icons.chat_bubble_rounded;
    if (name.contains("system") || name.contains("host")) return Icons.settings_input_component_rounded;
    return Icons.terminal_rounded;
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
                        _buildStatsGrid(isDark),
                        const SizedBox(height: 32),
                        _buildSectionHeader("ACTIVE PROCESSES", _buildSearchFilter(isDark), isDark),
                        const SizedBox(height: 16),
                        _isLoading && _processes.isEmpty
                          ? Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: accent)))
                          : _buildProcessList(accent, isDark),
                        const SizedBox(height: 32),
                        _buildAestheticCard(isDark),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav(isDark)),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
              Text("TASK MANAGER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
            ],
          ),
          Icon(Icons.sensors_rounded, color: accent),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        _statCard("CPU LOAD", "${_systemStats['cpu'].toInt()}%", Icons.memory_rounded, const Color(0xFF6C63FF), _systemStats['cpu'] / 100, isDark),
        _statCard("RAM USAGE", "${_systemStats['ram'].toInt()}%", Icons.developer_board_rounded, const Color(0xFFFFB786), _systemStats['ram'] / 100, isDark),
        _statCard("STORAGE", "${_systemStats['network'].toInt()}%", Icons.storage_rounded, const Color(0xFF10B981), _systemStats['network'] / 100, isDark),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, double percent, bool isDark, {bool isStatus = false}) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 16),
              if (isStatus) Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              Text(label, style: GoogleFonts.roboto(fontSize: 7, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 1)),
            ],
          ),
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, Widget trailing, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
          ],
        ),
        const SizedBox(height: 12),
        trailing,
      ],
    );
  }

  Widget _buildSearchFilter(bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _filterController,
              onChanged: _applyFilter,
              style: GoogleFonts.roboto(color: isDark ? Colors.white : Colors.black, fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Filter processes...",
                hintStyle: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessList(Color accent, bool isDark) {
    final list = _filterController.text.isEmpty ? _processes : _filteredProcesses;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text("No matching processes", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        final cpu = p['cpu_percent'] as num;
        final isHigh = cpu > 15;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03)))),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Icon(_getProcessIcon(p['name']), color: isHigh ? Colors.redAccent : accent, size: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'], style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
                    Text("PID: ${p['pid']} • ${p['memory_mb'].toStringAsFixed(1)} MB", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${cpu.toStringAsFixed(1)}%", style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold, color: isHigh ? Colors.redAccent : accent)),
                  GestureDetector(
                    onTap: () => _killProcess(p['pid'], p['name']),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("END TASK", style: GoogleFonts.roboto(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.redAccent.withOpacity(0.6), letterSpacing: 1)),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildAestheticCard(bool isDark) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuC5yHcdz4xf7kzfA02LGEk25pAo8pyZB2UFgrLODSAa0xn4DJqfLSMJCL8_Ku3YSdz_QMFDWMuUSuZ1gPdGNeDvxJwUg44WygModnuEtBjEDmpZZ-HgUVCdu6-VTMmrzmXPf4eV9Xf50j8CjKBc3zw8V49VMl2fZIK6UthBw2KCEyfmPETZOmq6mD5a4-cPMm2svcPxoOFnxJtVWqFmcxmf_jnxi9-s0UuOTXLtMwdfFQVWRXzOg236KIKm7whle_rlHAZqIh_bLQ8"),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7), Colors.transparent]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.2), borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3))),
                  child: Text("SYSTEM INTEGRITY", style: GoogleFonts.roboto(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
                ),
                const SizedBox(height: 8),
                Text("Secure Core Operations", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
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
