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

class ClipboardScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ClipboardScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  String _currentClipboard = "";
  List<String> _history = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchClipboard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchClipboard(isSilent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchClipboard({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/clipboard'),
        headers: {'X-Auth-Token': widget.authToken},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newContent = data['content'] ?? "";
        if (newContent != _currentClipboard && newContent.isNotEmpty) {
          if (_currentClipboard.isNotEmpty) _history.insert(0, _currentClipboard);
          setState(() => _currentClipboard = newContent);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendToPC(String text) async {
    HapticFeedback.mediumImpact();
    try {
      await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/clipboard'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'content': text}),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sent to PC Clipboard")));
    } catch (_) {}
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),
                  _buildHeader(isDark),
                  const SizedBox(height: 32),
                  _buildLiveCard(accent, isDark),
                  const SizedBox(height: 24),
                  _buildHistoryBento(isDark),
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
          color: (isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7)).withOpacity(0.8),
          border: Border(bottom: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
                Text("CLIPBOARD", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Icon(Icons.sync_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Universal Bridge", style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 8),
        Text("Real-time clipboard synchronization.", style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
      ],
    );
  }

  Widget _buildLiveCard(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CURRENT ON PC", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold, letterSpacing: 2)),
              const Icon(Icons.computer_rounded, size: 14, color: Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
            child: Text(
              _currentClipboard.isEmpty ? "Clipboard is empty" : _currentClipboard,
              style: GoogleFonts.roboto(fontSize: 16, color: isDark ? Colors.white : Colors.black, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _actionBtn("Copy to Phone", Icons.copy_rounded, accent, () {
                  Clipboard.setData(ClipboardData(text: _currentClipboard));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to phone")));
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionBtn("Push from Phone", Icons.upload_rounded, const Color(0xFFFFB786), () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) _sendToPC(data!.text!);
                }),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryBento(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("HISTORY", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        if (_history.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40), child: Text("No previous entries", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)))))
        else
          ..._history.take(5).map((item) => _historyItem(item, isDark)).toList(),
      ],
    );
  }

  Widget _historyItem(String text, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 16, color: Colors.white10),
          const SizedBox(width: 16),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.roboto(fontSize: 13, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)))),
          IconButton(icon: const Icon(Icons.send_to_mobile_rounded, size: 18, color: Colors.white10), onPressed: () => _sendToPC(text)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final theme = Provider.of<ThemeService>(context, listen: false);
    final isDark = theme.isDarkMode;
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context), isDark),
          _navItem(Icons.folder_copy_rounded, "Files", false, () => Navigator.pushReplacementNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
          _navItem(Icons.grid_view_rounded, "Tools", false, () => Navigator.pushReplacementNamed(context, '/controls', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
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
