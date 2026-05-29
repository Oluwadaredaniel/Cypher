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

class ScreenRecorderScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ScreenRecorderScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ScreenRecorderScreen> createState() => _ScreenRecorderScreenState();
}

class _ScreenRecorderScreenState extends State<ScreenRecorderScreen> {
  bool _isRecording = false;
  bool _isPaused = false;
  int _duration = 0;
  Timer? _timer;
  late String _streamUrl;

  // UI Toggles
  bool _micEnabled = true;
  bool _cameraEnabled = false;
  String _captureSource = "Full Screen";

  @override
  void initState() {
    super.initState();
    _streamUrl = 'http://${widget.pcIpAddress}:5000/system/stream?token=${widget.authToken}';
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final res = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/recording/status'),
        headers: {'X-Auth-Token': widget.authToken},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _isRecording = data['is_recording'];
            _isPaused = data['is_paused'];
            _duration = data['duration'];
          });
          if (_isRecording && !_isPaused) _startTimer();
        }
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _duration++);
    });
  }

  Future<void> _toggleRecording() async {
    HapticFeedback.mediumImpact();
    final endpoint = _isRecording ? '/recording/stop' : '/recording/start';
    try {
      final res = await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000$endpoint'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'source': 'fullscreen'}),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _isRecording = !_isRecording;
            if (!_isRecording) {
              _timer?.cancel();
              _duration = 0;
            } else {
              _startTimer();
            }
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(accent, isDark),
                  const SizedBox(height: 24),
                  _buildPreviewCanvas(accent, isDark),
                  const SizedBox(height: 24),
                  _buildConfigurationBento(accent, isDark),
                  const SizedBox(height: 24),
                  _buildActionGrid(accent, isDark),
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
                Text("RECORDER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Icon(Icons.sensors_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SYSTEM RECORDER", style: GoogleFonts.roboto(fontSize: 10, color: accent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text("Save your screen activity", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
      ],
    );
  }

  Widget _buildPreviewCanvas(Color accent, bool isDark) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                _streamUrl,
                headers: {'X-Auth-Token': widget.authToken},
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(Icons.videocam_off_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 48),
                ),
              ),
            ),
            Container(color: Colors.black.withOpacity(0.3)),
            if (_isRecording)
              Center(
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black,
                  opacity: 0.5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeIn(
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text("RECORDING ${_formatDuration(_duration)}", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 16, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                child: Text("Live Preview", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white70)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationBento(Color accent, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source Selector
        Expanded(
          flex: 3,
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CAPTURE SOURCE", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 1)),
                const SizedBox(height: 12),
                _sourceItem(Icons.desktop_windows_rounded, "Entire Screen", true, accent, isDark),
                _sourceItem(Icons.window_rounded, "Specific Window", false, accent, isDark),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Quick Toggles
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _toggleCard(Icons.mic_rounded, "Microphone", _micEnabled, () => setState(() => _micEnabled = !_micEnabled), accent, isDark),
              const SizedBox(height: 12),
              _toggleCard(Icons.videocam_rounded, "Facecam", _cameraEnabled, () => setState(() => _cameraEnabled = !_cameraEnabled), const Color(0xFFFFB786), isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sourceItem(IconData icon, String label, bool active, Color accent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.1) : (isDark ? Colors.white : Colors.black).withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? accent.withOpacity(0.2) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? accent : (isDark ? Colors.white : Colors.black).withOpacity(0.24), size: 16),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.roboto(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
          ],
        ),
      ),
    );
  }

  Widget _toggleCard(IconData icon, String label, bool active, VoidCallback tap, Color color, bool isDark) {
    return GestureDetector(
      onTap: tap,
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: active ? color : (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 20),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
            const SizedBox(height: 8),
            Container(
              width: 24, height: 12,
              decoration: BoxDecoration(color: active ? color : (isDark ? Colors.white : Colors.black).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              alignment: active ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(width: 8, height: 8, margin: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(Color accent, bool isDark) {
    return Row(
      children: [
        // Audio Mix Summary
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("AUDIO MIX", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                const SizedBox(height: 12),
                _miniProgress("SYSTEM", 0.8, accent, isDark),
                const SizedBox(height: 8),
                _miniProgress("MIC", 0.45, const Color(0xFFFFB786), isDark),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Central CTA
        GestureDetector(
          onTap: _toggleRecording,
          child: Container(
            width: 120, height: 110,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.redAccent : accent,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: (_isRecording ? Colors.redAccent : accent).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(_isRecording ? "STOP" : "RECORD", style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniProgress(String label, double val, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.roboto(fontSize: 7, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
            Text("${(val * 100).toInt()}%", style: GoogleFonts.roboto(fontSize: 7, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: val, minHeight: 2, backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05), valueColor: AlwaysStoppedAnimation(color)),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context)),
          _navItem(Icons.folder_copy_rounded, "Files", false, () => Navigator.pushReplacementNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken})),
          _navItem(Icons.settings_input_component_rounded, "Controls", true),
          _navItem(Icons.tune_rounded, "Settings", false),
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
}
