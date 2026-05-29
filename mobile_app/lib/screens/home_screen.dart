import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/socket_service.dart';
import '../services/theme_service.dart';
import '../services/central_service.dart';
import '../widgets/glass_container.dart';

class HomeScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const HomeScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isError = false;

  Map<String, dynamic> _liveStats = {
    "cpu_percent": 0.0,
    "ram_percent": 0.0,
    "disk_percent": 0.0,
    "battery_percent": 0.0
  };
  String _pcName = "COMPUTER";
  List<dynamic> _recentActivity = [];
  Map<String, dynamic>? _broadcast;

  final SocketService _socketService = SocketService();
  late AnimationController _pulseController;
  Timer? _activityTimer;
  StreamSubscription? _connectionSub;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _initConnection();
    _initFetch();
    _checkUpdates();
    _activityTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchActivity());
  }

  void _initConnection() {
    _socketService.connect(widget.pcIpAddress, widget.authToken);
    _connectionSub = _socketService.connectionStatus.listen((status) {
      if (mounted) setState(() => _isConnected = status);
      if (!status && mounted) {
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute == '/home') {
          Navigator.pushNamed(context, '/disconnected', arguments: {
            'pcIpAddress': widget.pcIpAddress,
            'authToken': widget.authToken,
            'onReconnected': () => Navigator.pop(context),
          });
        }
      }
    });
    _statsSub = _socketService.systemStats.listen((stats) {
      if (mounted) setState(() => _liveStats = stats);
    });
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _statsSub?.cancel();
    _pulseController.dispose();
    _activityTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUpdates() async {
    final update = await CentralService.checkForUpdates();
    if (mounted && update != null && update['update_available'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✨ New Version v${update['version']} available!", style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF6C63FF),
          action: SnackBarAction(label: "GET", textColor: Colors.white, onPressed: () => launchUrlString(update['url'])),
        ),
      );
    }
    final bData = await CentralService.getBroadcast();
    if (mounted && bData != null) setState(() => _broadcast = bData);
  }

  Future<void> _initFetch() async {
    setState(() { _isLoading = true; _isError = false; });
    try {
      final headers = {'X-Auth-Token': widget.authToken};
      final baseUrl = 'http://${widget.pcIpAddress}:5000';

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/settings'), headers: headers),
        http.get(Uri.parse('$baseUrl/system/activity'), headers: headers),
        http.get(Uri.parse('$baseUrl/ping'), headers: headers),
      ]).timeout(const Duration(seconds: 8));

      if (results[0].statusCode == 200) {
        _pcName = jsonDecode(results[0].body)['device_name']?.toString().toUpperCase() ?? "COMPUTER";
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _isError = true; });
        Navigator.pushNamed(context, '/disconnected', arguments: {
          'pcIpAddress': widget.pcIpAddress,
          'authToken': widget.authToken,
        });
      }
    }
  }

  Future<void> _fetchActivity() async {
    try {
      final headers = {'X-Auth-Token': widget.authToken};
      final baseUrl = 'http://${widget.pcIpAddress}:5000';
      final res = await http.get(Uri.parse('$baseUrl/system/activity'), headers: headers);
      if (res.statusCode == 200) {
        if (mounted) setState(() => _recentActivity = (jsonDecode(res.body) as List).take(3).toList());
      }
    } catch (_) {}
  }

  void _showMasterLogin() {
    HapticFeedback.heavyImpact();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("MASTER ACCESS", style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Enter Management Key", hintStyle: TextStyle(color: Colors.white24)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: GoogleFonts.roboto(color: Colors.white38))),
          ElevatedButton(
            onPressed: () {
              if (controller.text == "emerald-admin") {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/master_control');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text("UNLOCK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          SafeArea(
            child: _isError
              ? _buildErrorState()
              : (_isLoading ? _buildShimmerLoading() : _buildDashboard(isDark)),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildDashboard(bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(isDark),

        // System Overview Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("System Overview", style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.computer_rounded, size: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                        const SizedBox(width: 6),
                        Text("Connected", style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildMiniHeaderStat(Icons.memory_rounded, "${(_liveStats['cpu_percent'] ?? 0).toInt()}%", "CPU"),
                    const SizedBox(width: 8),
                    _buildMiniHeaderStat(Icons.speed_rounded, "${(_liveStats['ram_percent'] ?? 0).toInt()}%", "RAM"),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Main Transfer Actions
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildQuickAction(
                icon: Icons.upload_file_rounded,
                title: "Send to PC",
                subtitle: "Photos, Docs, Files",
                color: const Color(0xFF6C63FF),
                onTap: () => Navigator.pushNamed(context, '/send', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}),
              ),
              _buildQuickAction(
                icon: Icons.download_for_offline_rounded,
                title: "Get from PC",
                subtitle: "Download files",
                color: const Color(0xFF10B981),
                onTap: () => Navigator.pushNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}),
              ),
            ],
          ),
        ),

        // Live Performance Bento Wide
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("System Performance", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                        child: Text("LIVE", style: GoogleFonts.roboto(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildProgressBar("CPU Usage", "${(_liveStats['cpu_percent'] ?? 0).toInt()}%", (_liveStats['cpu_percent'] ?? 0) / 100, const Color(0xFF6C63FF), isDark),
                  const SizedBox(height: 20),
                  _buildProgressBar("Memory", "${(_liveStats['ram_percent'] ?? 0).toInt()}%", (_liveStats['ram_percent'] ?? 0) / 100, const Color(0xFFC0C6DB), isDark),
                  const SizedBox(height: 20),
                  _buildProgressBar("Battery", "${(_liveStats['battery_percent'] ?? 0).toInt()}%", (_liveStats['battery_percent'] ?? 0) / 100, const Color(0xFFFFB786), isDark),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.shield_moon_outlined, color: Color(0xFF6C63FF), size: 28),
          const SizedBox(width: 12),
          Text("CYPHER", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF6C63FF), letterSpacing: -1)),
        ],
      ),
      actions: [
        GestureDetector(
          onLongPress: _showMasterLogin,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(100), border: Border.all(color: Colors.white10)),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _pulseController,
                  child: Container(width: 6, height: 6, decoration: BoxDecoration(color: _isConnected ? const Color(0xFF10B981) : Colors.redAccent, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 8),
                Text(_pcName, style: GoogleFonts.roboto(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMiniHeaderStat(IconData icon, String value, String label) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: GoogleFonts.roboto(fontSize: 7, color: Colors.white38)),
              Text(value, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, String value, double percent, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
            Text(value, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    final isDark = Provider.of<ThemeService>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.roboto(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_filled, "Home", true),
          _navItem(Icons.folder_copy_rounded, "Files", false, () => Navigator.pushNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken})),
          _navItem(Icons.grid_view_rounded, "Tools", false, () => Navigator.pushNamed(context, '/controls', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken})),
          _navItem(Icons.tune_rounded, "Settings", false, () => Navigator.pushNamed(context, '/settings', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken})),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, [VoidCallback? tap]) {
    final accent = const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: tap,
      child: Opacity(
        opacity: active ? 1.0 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? accent : Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: active ? accent : Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.05),
      highlightColor: Colors.white.withOpacity(0.1),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(height: 100, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24))),
          const SizedBox(height: 24),
          Container(height: 200, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24))),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Container(height: 150, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)))),
              const SizedBox(width: 16),
              Expanded(child: Container(height: 150, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 60),
          const SizedBox(height: 24),
          Text("Connection Lost", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _initFetch, child: const Text("RETRY")),
        ],
      ),
    );
  }
}
