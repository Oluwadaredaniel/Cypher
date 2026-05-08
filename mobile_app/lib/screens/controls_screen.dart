import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ControlsScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ControlsScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  Timer? _statusTimer;
  String _activeWindow = "Nothing open";
  String _pcClipboard = "PC clipboard is empty";
  double _currentVolume = 50;
  Uint8List? _screenshotBytes;
  String? _screenshotTime;
  bool _isTakingScreenshot = false;
  bool _isDisconnected = false;

  final TextEditingController _typeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStatusUpdates();
    // Background polling for window title and clipboard
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchStatusUpdates();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _typeController.dispose();
    super.dispose();
  }

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {
        "X-Auth-Token": widget.authToken,
        "Content-Type": "application/json",
      };

  // --- API LOGIC ---

  Future<void> _fetchStatusUpdates() async {
    try {
      final windowResp = await http.get(Uri.parse('$_baseUrl/activewindow'), headers: _headers).timeout(const Duration(seconds: 3));
      final clipboardResp = await http.get(Uri.parse('$_baseUrl/clipboard'), headers: _headers).timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _isDisconnected = false;
          if (windowResp.statusCode == 200) {
            final data = jsonDecode(windowResp.body);
            _activeWindow = data['window_title']?.toString().isNotEmpty == true ? data['window_title'] : "Nothing open";
          }
          if (clipboardResp.statusCode == 200) {
            final data = jsonDecode(clipboardResp.body);
            _pcClipboard = data['content']?.toString().isNotEmpty == true ? data['content'] : "PC clipboard is empty";
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isDisconnected = true);
    }
  }

  Future<void> _executeAction(String endpoint, {Map? body, bool isGet = false}) async {
    HapticFeedback.mediumImpact();
    try {
      final url = Uri.parse('$_baseUrl$endpoint');
      final response = isGet 
          ? await http.get(url, headers: _headers).timeout(const Duration(seconds: 8))
          : await http.post(url, headers: _headers, body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) throw Exception();
    } catch (e) {
      _showToast("Couldn't complete action. Try again.", isError: true);
    }
  }

  Future<void> _takeScreenshot() async {
    HapticFeedback.mediumImpact();
    setState(() => _isTakingScreenshot = true);
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/screenshot'), headers: _headers).timeout(const Duration(seconds: 15));
      
      if (resp.statusCode == 200) {
        setState(() {
          _screenshotBytes = resp.bodyBytes;
          _screenshotTime = DateFormat('h:mm a').format(DateTime.now());
          _isTakingScreenshot = false;
        });
        _showToast("Screenshot captured");
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) setState(() => _isTakingScreenshot = false);
      _showToast("Failed to capture screen.", isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isDisconnected) _buildDisconnectBanner(),
              _buildSectionLabel("POWER"),
              _buildPowerGrid(),
              _buildSectionLabel("MEDIA"),
              _buildMediaCard(),
              _buildSectionLabel("CLIPBOARD"),
              _buildClipboardCard(),
              _buildSectionLabel("KEYBOARD"),
              _buildKeyboardCard(),
              _buildSectionLabel("SCREENSHOT"),
              _buildScreenshotSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text("Controls", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: SizedBox(
              width: 100,
              child: Text(
                _activeWindow,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 11),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildDisconnectBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_wifi_off, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Text("PC Unreachable", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(label, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildPowerGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.9,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildPowerCard("Shut Down", "🔴", const Color(0xFF1A0A0A), const Color(0xFFFF453A), "/power/shutdown", "Shut down your PC entirely?"),
        _buildPowerCard("Restart", "🔄", const Color(0xFF1A1400), const Color(0xFFFF9F0A), "/power/restart", "Reboot your system now?"),
        _buildPowerCard("Sleep", "😴", const Color(0xFF001020), const Color(0xFF0A84FF), "/power/sleep", "Put the PC into low-power sleep mode?"),
        _buildPowerCard("Hibernate", "🌙", const Color(0xFF0D0A1A), const Color(0xFF6C63FF), "/power/hibernate", "Save state and power down?"),
        _buildPowerCard("Lock Screen", "🔒", const Color(0xFF1A1A1A), Colors.white, "/power/lock", "Lock the Windows session?"),
      ],
    );
  }

  Widget _buildPowerCard(String label, String emoji, Color bg, Color iconColor, String route, String desc) {
    return ScaleTap(
      onPressed: () => _showConfirmSheet(label, desc, iconColor, () => _executeAction(route)),
      onLongPress: () => _executeAction(route),
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: iconColor.withOpacity(0.1))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard() {
    bool isMedia = ["Spotify", "VLC", "Chrome", "YouTube", "Netflix"].any((e) => _activeWindow.toLowerCase().contains(e.toLowerCase()));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isMedia ? Colors.greenAccent.withOpacity(0.1) : const Color(0xFF2C2C2C), shape: BoxShape.circle),
                child: Icon(Icons.music_note, color: isMedia ? Colors.greenAccent : Colors.white24, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMedia ? _activeWindow : "No media detected", 
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(color: isMedia ? Colors.white : const Color(0xFF86868B), fontSize: 14, fontWeight: FontWeight.bold)),
                    if (isMedia) Text("Active Session", style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMediaBtn(Icons.skip_previous, 50, const Color(0xFF2C2C2C), () => _executeAction("/media/previous")),
              const SizedBox(width: 20),
              _buildMediaBtn(Icons.play_arrow, 65, const Color(0xFF6C63FF), () => _executeAction("/media/playpause")),
              const SizedBox(width: 20),
              _buildMediaBtn(Icons.skip_next, 50, const Color(0xFF2C2C2C), () => _executeAction("/media/next")),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.volume_mute, color: Color(0xFF86868B), size: 16),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: const Color(0xFF6C63FF),
                    inactiveTrackColor: const Color(0xFF2C2C2C),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: _currentVolume,
                    min: 0,
                    max: 100,
                    onChanged: (v) => setState(() => _currentVolume = v),
                    onChangeEnd: (v) => _executeAction("/media/volume/set", body: {"level": v.toInt()}),
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: Color(0xFF86868B), size: 16),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 32),
              Text("${_currentVolume.toInt()}%", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12, fontWeight: FontWeight.bold)),
              _buildMutePill(),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMediaBtn(IconData icon, double size, Color color, VoidCallback tap) {
    return ScaleTap(
      onPressed: tap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, 
          boxShadow: color != const Color(0xFF2C2C2C) ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)] : null),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }

  Widget _buildMutePill() {
    return ScaleTap(
      onPressed: () => _executeAction("/media/mute"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(100), border: Border.all(color: Colors.white10)),
        child: Text("Mute PC", style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildClipboardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.paste_rounded, color: Color(0xFF86868B), size: 14),
              const SizedBox(width: 6),
              Text("PC CLIPBOARD", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _pcClipboard,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(color: _pcClipboard.contains("empty") ? const Color(0xFF3A3A3C) : Colors.white, fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildPillBtn("Copy to Phone", const Color(0xFF6C63FF), () {
                Clipboard.setData(ClipboardData(text: _pcClipboard));
                _showToast("Synced to phone");
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildPillBtn("Send Text", Colors.transparent, _showTextInputSheet, isGhost: true)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildKeyboardCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _typeController,
            style: GoogleFonts.outfit(color: Colors.white),
            cursorColor: const Color(0xFF6C63FF),
            decoration: InputDecoration(
              hintText: "Remote keyboard type...",
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF3A3A3C), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF0D0D0D),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF)),
                  onPressed: () {
                    if (_typeController.text.trim().isEmpty) return;
                    _executeAction("/type", body: {"text": _typeController.text});
                    _typeController.clear();
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPillBtn("Capture Screen", const Color(0xFF6C63FF), _takeScreenshot)),
            if (_screenshotBytes != null) ...[
              const SizedBox(width: 12),
              Expanded(child: _buildPillBtn("Save to Phone", Colors.transparent, _saveScreenshotToGallery, isGhost: true)),
            ]
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 210,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), 
            borderRadius: BorderRadius.circular(24), 
            border: Border.all(color: const Color(0xFF2C2C2C))
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _isTakingScreenshot
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2))
                : _screenshotBytes != null
                    ? InteractiveViewer(child: Image.memory(_screenshotBytes!, fit: BoxFit.contain))
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monitor_rounded, color: Color(0xFF2C2C2C), size: 40),
                            const SizedBox(height: 8),
                            Text("No Preview", style: GoogleFonts.outfit(color: const Color(0xFF3A3A3C), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
          ),
        ),
        if (_screenshotTime != null) 
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text("Last updated: $_screenshotTime", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 11)),
          ),
      ],
    );
  }

  Future<void> _saveScreenshotToGallery() async {
    if (_screenshotBytes == null) return;
    try {
      final dir = Directory('/storage/emulated/0/Download');
      final name = "CYPHER_Screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final file = File("${dir.path}/$name");
      await file.writeAsBytes(_screenshotBytes!);
      _showToast("Saved to Downloads");
    } catch (e) {
      _showToast("Failed to save", isError: true);
    }
  }

  Widget _buildPillBtn(String label, Color color, VoidCallback tap, {bool isGhost = false}) {
    return ScaleTap(
      onPressed: tap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: isGhost ? Border.all(color: const Color(0xFF2C2C2C), width: 1.5) : null,
        ),
        child: Center(child: Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
      ),
    );
  }

  // --- BOTTOM SHEETS ---

  void _showConfirmSheet(String title, String desc, Color color, VoidCallback onConfirm) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            Icon(Icons.power_settings_new_rounded, color: color, size: 48),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(desc, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _buildPillBtn("Cancel", const Color(0xFF2C2C2C), () => Navigator.pop(context))),
                const SizedBox(width: 12),
                Expanded(child: _buildPillBtn("Execute", color, () {
                  Navigator.pop(context);
                  onConfirm();
                })),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTextInputSheet() {
    final sheetController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Send to PC Clipboard", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: sheetController,
              maxLines: 4,
              autofocus: true,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                hintText: "Paste link or text here...",
                hintStyle: GoogleFonts.outfit(color: const Color(0xFF3A3A3C)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            _buildPillBtn("Push to PC", const Color(0xFF6C63FF), () {
              if (sheetController.text.isNotEmpty) {
                _executeAction("/clipboard", body: {"text": sheetController.text});
              }
              Navigator.pop(context);
              _showToast("Clipboard updated");
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// Custom Tap Component
class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  const ScaleTap({super.key, required this.child, required this.onPressed, this.onLongPress});

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}