import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class ScreenRecorderScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ScreenRecorderScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<ScreenRecorderScreen> createState() => _ScreenRecorderScreenState();
}

class _ScreenRecorderScreenState extends State<ScreenRecorderScreen> {
  bool _isRecording = false;
  bool _isPaused = false;
  int _duration = 0;
  String _source = "fullscreen";
  bool _saveToPhone = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {"X-Auth-Token": widget.authToken, "Content-Type": "application/json"};

  Future<void> _fetchStatus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/recording/status'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isRecording = data['is_recording'];
          _isPaused = data['is_paused'];
          _duration = data['duration'];
        });
        if (_isRecording && !_isPaused) {
          _startTimer();
        }
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused) {
        setState(() => _duration++);
      }
    });
  }

  Future<void> _startRecording() async {
    HapticFeedback.heavyImpact();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/recording/start'),
        headers: _headers,
        body: jsonEncode({"source": _source}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _isRecording = true;
          _isPaused = false;
        });
        _startTimer();
      }
    } catch (_) {}
  }

  Future<void> _pauseResume() async {
    HapticFeedback.mediumImpact();
    try {
      final response = await http.post(Uri.parse('$_baseUrl/recording/pause'), headers: _headers);
      if (response.statusCode == 200) {
        setState(() {
          _isPaused = jsonDecode(response.body)['is_paused'];
        });
      }
    } catch (_) {}
  }

  Future<void> _stopRecording() async {
    HapticFeedback.heavyImpact();
    _timer?.cancel();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/recording/stop'),
        headers: _headers,
        body: jsonEncode({"save_to_phone": _saveToPhone}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _isRecording = false;
          _duration = 0;
        });
        _showSuccessSheet();
      }
    } catch (_) {}
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF30D158), size: 64),
            const SizedBox(height: 20),
            Text("Recording Saved", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("File saved to Videos/CYPHER on your PC.", textAlign: TextAlign.center, style: GoogleFonts.outfit(color: const Color(0xFF86868B))),
            if (_saveToPhone) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text("Transferring copy to phone...", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), padding: const EdgeInsets.all(16), shape: const StadiumBorder()),
                child: Text("Done", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Pro Screen Recorder", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildStatusDisplay(),
            const SizedBox(height: 40),
            _buildSourceSelector(),
            const SizedBox(height: 40),
            _buildControls(),
            const SizedBox(height: 40),
            _buildSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDisplay() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        shape: BoxShape.circle,
        border: Border.all(color: _isRecording ? Colors.redAccent.withOpacity(0.3) : const Color(0xFF2C2C2C), width: 2),
      ),
      child: Column(
        children: [
          if (_isRecording) FadeIn(infinite: true, duration: const Duration(seconds: 1), child: const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16)),
          Text(_formatDuration(_duration), style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
          Text(_isRecording ? (_isPaused ? "PAUSED" : "RECORDING") : "READY", style: GoogleFonts.outfit(color: _isRecording ? Colors.redAccent : const Color(0xFF86868B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SOURCE", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildSourceBtn("fullscreen", "Full Screen", Icons.monitor_rounded),
            const SizedBox(width: 12),
            _buildSourceBtn("window", "Active App", Icons.window_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceBtn(String id, String label, IconData icon) {
    bool active = _source == id;
    return Expanded(
      child: GestureDetector(
        onTap: _isRecording ? null : () => setState(() => _source = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF6C63FF).withOpacity(0.1) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? const Color(0xFF6C63FF) : Colors.transparent),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? const Color(0xFF6C63FF) : const Color(0xFF86868B)),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.outfit(color: active ? Colors.white : const Color(0xFF86868B), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isRecording)
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              child: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 32),
            ),
          ),
        if (_isRecording) ...[
          _buildControlBtn(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, const Color(0xFF2C2C2C), _pauseResume),
          const SizedBox(width: 32),
          _buildControlBtn(Icons.stop_rounded, Colors.redAccent, _stopRecording),
        ],
      ],
    );
  }

  Widget _buildControlBtn(IconData icon, Color bg, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: 70, height: 70,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Auto-Transfer", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("Save a copy to phone gallery", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
              ],
            ),
          ),
          Switch(value: _saveToPhone, onChanged: (v) => setState(() => _saveToPhone = v), activeColor: const Color(0xFF6C63FF)),
        ],
      ),
    );
  }
}
