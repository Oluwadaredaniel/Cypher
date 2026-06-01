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

class RemoteViewScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const RemoteViewScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<RemoteViewScreen> createState() => _RemoteViewScreenState();
}

class _RemoteViewScreenState extends State<RemoteViewScreen> {
  bool _isLive = false;
  double _quality = 50;
  String? _activeWindow;
  Timer? _windowTimer;

  @override
  void initState() {
    super.initState();
    _startWindowTracking();
  }

  @override
  void dispose() {
    _windowTimer?.cancel();
    super.dispose();
  }

  void _startWindowTracking() {
    _windowTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final res = await http.get(
          Uri.parse('http://${widget.pcIpAddress}:5000/activewindow'),
          headers: {'X-Auth-Token': widget.authToken},
        );
        if (res.statusCode == 200 && mounted) {
          setState(() => _activeWindow = jsonDecode(res.body)['window_title']);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: const Color(0xFF080F17),
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
                        _buildLiveView(accent),
                        const SizedBox(height: 24),
                        _buildControlPanel(accent, isDark),
                        const SizedBox(height: 24),
                        _buildSystemOverlay(accent, isDark),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFloatingHeader(accent),
        ],
      ),
    );
  }

  Widget _buildFloatingHeader(Color accent) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF080F17).withOpacity(0.8),
          border: const Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
                Text("REMOTE VIEW", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.sensors_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Text("LIVE", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent) => const SizedBox(height: 64);

  Widget _buildLiveView(Color accent) {
    final streamUrl = 'http://${widget.pcIpAddress}:5000/system/stream?token=${widget.authToken}&q=${_quality.toInt()}';

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _isLive
                ? Image.network(streamUrl, fit: BoxFit.contain, gaplessPlayback: true)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_off_rounded, color: Colors.white10, size: 48),
                        const SizedBox(height: 16),
                        Text("Stream is Standby", style: GoogleFonts.roboto(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ACTIVE WINDOW", style: GoogleFonts.roboto(fontSize: 8, color: Colors.white24, letterSpacing: 1)),
                    Text(_activeWindow ?? "Desktop", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                  ],
                ),
                Switch.adaptive(
                  value: _isLive,
                  onChanged: (v) {
                    HapticFeedback.mediumImpact();
                    setState(() => _isLive = v);
                  },
                  activeColor: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("STREAM QUALITY", style: GoogleFonts.roboto(fontSize: 9, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: accent.withOpacity(0.1),
            ),
            child: Slider(
              value: _quality,
              min: 10, max: 100,
              onChanged: (v) => setState(() => _quality = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Performance", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white12)),
              Text("Ultra Detail", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSystemOverlay(Color accent, bool isDark) {
    return Column(
      children: [
        _overlayAction("Take Screenshot", "Save current PC view to phone", Icons.camera_alt_rounded, accent, () {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Capturing system screen...")));
        }),
        const SizedBox(height: 12),
        _overlayAction("Toggle Privacy", "Blank out the PC monitor", Icons.visibility_off_rounded, const Color(0xFFFFB786), () {}),
      ],
    );
  }

  Widget _overlayAction(String title, String sub, IconData icon, Color color, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(sub, style: GoogleFonts.roboto(fontSize: 11, color: Colors.white24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
