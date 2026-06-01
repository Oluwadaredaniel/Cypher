import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class ControlsScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ControlsScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  double _volume = 50;
  double _micLevel = 45;
  String _activeWindow = "HOME";
  bool _isPlaying = false;
  bool _isLoading = false;

  Map<String, dynamic> _systemStats = {"cpu_percent": 0.0, "ram_percent": 0.0};
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _fetchActiveWindow();
    _fetchStats();
    _fetchVolume();
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchActiveWindow();
      _fetchStats();
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchActiveWindow() async {
    try {
      final res = await http.get(Uri.parse('http://${widget.pcIpAddress}:5000/activewindow'), headers: {'X-Auth-Token': widget.authToken});
      if (res.statusCode == 200) {
        if (mounted) setState(() => _activeWindow = jsonDecode(res.body)['window_title'] ?? "HOME");
      }
    } catch (_) {}
  }

  Future<void> _fetchVolume() async {
    try {
      final res = await http.get(Uri.parse('http://${widget.pcIpAddress}:5000/media/volume/get'), headers: {'X-Auth-Token': widget.authToken});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => _volume = (data['level'] ?? 50).toDouble());
      }
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('http://${widget.pcIpAddress}:5000/system-stats'), headers: {'X-Auth-Token': widget.authToken});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _systemStats = {
              "cpu_percent": (data['cpu_percent'] ?? 0.0).toDouble(),
              "ram_percent": (data['ram_percent'] ?? 0.0).toDouble(),
            };
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendCommand(String endpoint, [Map<String, dynamic>? body]) async {
    try {
      final res = await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000$endpoint'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Command executed"), duration: Duration(seconds: 1)),
          );
        }
        if (endpoint.contains("volume")) {
          _fetchVolume();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Action failed. Check PC app."), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection error"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showPowerConfirm(String title, String endpoint) {
    final isDark = Provider.of<ThemeService>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.roboto(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to execute this power command?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendCommand(endpoint);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("EXECUTE"),
          ),
        ],
      ),
    );
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 32),

                  // Media Player Card
                  _buildMediaCard(accent, isDark),
                  const SizedBox(height: 24),

                  // Volume Card
                  _buildVolumeCard(accent, isDark),
                  const SizedBox(height: 24),

                  // Quick Actions Grid
                  _buildSystemActions(isDark),
                  const SizedBox(height: 24),

                  // Health Section
                  _buildHealthStatus(accent, isDark),
                  const SizedBox(height: 24),

                  // Specialized Tools
                  _buildSpecializedTools(accent, isDark),
                ],
              ),
            ),
          ),
          _buildFloatingHeader(accent, isDark),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
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
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
          border: Border(bottom: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
                Text("TOOLS", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Icon(Icons.grid_view_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("System Tools", style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 6),
        Text("Manage apps, and power.", style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
      ],
    );
  }

  Widget _buildMediaCard(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      height: 280,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                child: Text("NOW PLAYING", style: GoogleFonts.roboto(fontSize: 9, fontWeight: FontWeight.bold, color: accent)),
              ),
              _buildActiveTag(isDark),
            ],
          ),
          Column(
            children: [
              Text("Current Track", style: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              Text(_activeWindow, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
            ],
          ),
          Column(
            children: [
              LinearPercentIndicator(
                lineHeight: 4.0,
                percent: 0.65,
                progressColor: accent,
                backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                barRadius: const Radius.circular(10),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: Icon(Icons.skip_previous_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), size: 32), onPressed: () => _sendCommand('/media/prev')),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: () {
                      setState(() => _isPlaying = !_isPlaying);
                      _sendCommand('/media/playpause');
                    },
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 20)]),
                      child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(width: 32),
                  IconButton(icon: Icon(Icons.skip_next_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), size: 32), onPressed: () => _sendCommand('/media/next')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTag(bool isDark) {
    final accent = const Color(0xFF6C63FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(100), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(_activeWindow, overflow: TextOverflow.ellipsis, style: GoogleFonts.roboto(fontSize: 9, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          )
        ],
      ),
    );
  }

  Widget _buildVolumeCard(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("SOUND CONTROL", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2)),
              Row(
                children: [
                  _miniVolumeBtn(Icons.remove_rounded, () => _sendCommand('/media/volumedown'), isDark),
                  const SizedBox(width: 12),
                  _miniVolumeBtn(Icons.add_rounded, () => _sendCommand('/media/volumeup'), isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSliderItem("Volume", _volume, (v) {
            setState(() => _volume = v);
          }, (v) => _sendCommand('/media/volume/set', {'level': v.toInt()}), accent, isDark),
          const SizedBox(height: 24),
          _buildSliderItem("Mic Level", _micLevel, (v) {
            setState(() => _micLevel = v);
          }, (v) {}, const Color(0xFFFFB786), isDark),
        ],
      ),
    );
  }

  Widget _miniVolumeBtn(IconData icon, VoidCallback tap, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        tap();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), size: 18),
      ),
    );
  }

  Widget _buildSliderItem(String label, double value, Function(double) onChanging, Function(double) onChangeEnd, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
            Text("${value.toInt()}%", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: color,
            inactiveTrackColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            thumbColor: isDark ? Colors.white : color,
            overlayColor: color.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: 0, max: 100,
            onChanged: onChanging,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemActions(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildActionBtn("Mute Audio", Icons.volume_off_rounded, Colors.teal, () => _sendCommand('/media/mute'), isDark),
        _buildActionBtn("Lock screen", Icons.lock_rounded, const Color(0xFFC0C6DB), () => _showPowerConfirm("Lock PC?", '/power/lock'), isDark),
        _buildActionBtn("Hibernate", Icons.snooze_rounded, const Color(0xFFADC6FF), () => _showPowerConfirm("Hibernate PC?", '/power/hibernate'), isDark),
        _buildActionBtn("Restart", Icons.restart_alt_rounded, const Color(0xFFFFB786), () => _showPowerConfirm("Restart PC?", '/power/restart'), isDark),
        _buildActionBtn("Shutdown", Icons.power_settings_new_rounded, Colors.redAccent, () => _showPowerConfirm("Shutdown PC?", '/power/shutdown'), isDark),
      ],
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback tap, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        tap();
      },
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7)))),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStatus(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("SYSTEM STATUS", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHealthMetric("PROCESSOR", "${_systemStats['cpu_percent'].toInt()}%", accent, isDark),
              Container(width: 1, height: 30, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
              _buildHealthMetric("MEMORY", "${_systemStats['ram_percent'].toInt()}%", accent, isDark),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String label, String val, Color color, bool isDark, {String unit = ""}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(val, style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
            if (unit.isNotEmpty) Text(" $unit", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.12))),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecializedTools(Color accent, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SPECIALIZED TOOLS", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildToolTile("App Manager", Icons.apps_rounded, () => Navigator.pushNamed(context, '/apps_launcher', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark)),
            const SizedBox(width: 16),
            Expanded(child: _buildToolTile("Keyboard", Icons.keyboard_rounded, () => Navigator.pushNamed(context, '/keyboard', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildToolTile("Task Manager", Icons.list_rounded, () => Navigator.pushNamed(context, '/processes', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark)),
            const SizedBox(width: 16),
            Expanded(child: _buildToolTile("Close Apps", Icons.task_alt_rounded, () => Navigator.pushNamed(context, '/active_tasks', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildToolTile(String label, IconData icon, VoidCallback tap, bool isDark, {bool wide = false}) {
    return GestureDetector(
      onTap: tap,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: wide ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
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
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;
    return GestureDetector(
      onTap: tap,
      child: Opacity(
        opacity: 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? accent : inactiveColor, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: active ? accent : inactiveColor)),
          ],
        ),
      ),
    );
  }
}
