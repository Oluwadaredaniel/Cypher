import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class DisconnectedScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final VoidCallback onReconnected;

  const DisconnectedScreen({super.key, required this.pcIpAddress, required this.authToken, required this.onReconnected});

  @override
  State<DisconnectedScreen> createState() => _DisconnectedScreenState();
}

class _DisconnectedScreenState extends State<DisconnectedScreen> with SingleTickerProviderStateMixin {
  bool _isRetrying = false;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    HapticFeedback.mediumImpact();
    setState(() => _isRetrying = true);
    try {
      final res = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/ping'),
        headers: {'X-Auth-Token': widget.authToken},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false, arguments: {
            'pcIpAddress': widget.pcIpAddress,
            'authToken': widget.authToken,
          });
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Computer found but refused connection."), backgroundColor: Colors.orange));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Still unable to reach computer."), backgroundColor: Colors.redAccent));
    }
    if (mounted) setState(() => _isRetrying = false);
  }

  void _showManualIpEntry() {
    final controller = TextEditingController(text: widget.pcIpAddress);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Update IP Address", style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g. 192.168.1.10",
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: GoogleFonts.roboto(color: Colors.white24))),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('pc_ip_address', controller.text);
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false, arguments: {
                  'pcIpAddress': controller.text,
                  'authToken': widget.authToken,
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text("UPDATE & RETRY"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        const SizedBox(height: 16),
                        _buildHeroCard(accent),
                        const SizedBox(height: 24),
                        _buildDiagnosticLog(),
                        const SizedBox(height: 24),
                        _buildQuickFixCard(),
                        const SizedBox(height: 24),
                        _buildTopologyCard(accent),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFloatingHeader(accent),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
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
                const Icon(Icons.shield_moon_outlined, color: Color(0xFF6C63FF), size: 24),
                const SizedBox(width: 12),
                Text("CYPHER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            const Icon(Icons.sensors_off_rounded, color: Colors.redAccent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent) => const SizedBox(height: 64);

  Widget _buildHeroCard(Color accent) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) {
              return Positioned(
                top: _scanController.value * 400,
                left: 0, right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, accent.withOpacity(0.5), Colors.transparent],
                    ),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Pulse(
                      infinite: true,
                      child: Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 4),
                        ),
                      ),
                    ),
                    const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                        child: Text("OFFLINE", style: GoogleFonts.roboto(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text("Connection Lost", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.roboto(fontSize: 14, color: Colors.white38),
                    children: [
                      const TextSpan(text: "We can't reach your computer "),
                      TextSpan(text: "right now", style: GoogleFonts.roboto(color: accent, fontWeight: FontWeight.bold)),
                      const TextSpan(text: ". Please check your connection."),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRetrying ? null : _handleRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 10,
                      shadowColor: accent.withOpacity(0.3),
                    ),
                    child: _isRetrying
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sync_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            Text("Try Again", style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _showManualIpEntry,
                  child: Text("Update IP Address", style: GoogleFonts.roboto(fontSize: 14, color: accent.withOpacity(0.6), fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text("Network Diagnostics", style: GoogleFonts.roboto(fontSize: 14, color: Colors.white24, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticLog() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded, color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 12),
              Text("What happened?", style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          _logEntry("14:22:09", "Connection timed out", "The computer didn't respond in time.", Colors.redAccent),
          const SizedBox(height: 16),
          _logEntry("14:21:55", "Address changed", "The computer address has changed.", const Color(0xFFFFB786)),
        ],
      ),
    );
  }

  Widget _logEntry(String time, String error, String detail, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TIME: $time", style: GoogleFonts.roboto(fontSize: 9, color: Colors.white12)),
          const SizedBox(height: 4),
          Text(error, style: GoogleFonts.roboto(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(detail, style: GoogleFonts.roboto(fontSize: 12, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildQuickFixCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB786), size: 20),
              const SizedBox(width: 12),
              Text("Quick Fix", style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _fixItem("Ensure Cypher PC App is running."),
          _fixItem("Check if PC and Phone are on same WiFi."),
          _fixItem("Verify IP address hasn't changed."),
        ],
      ),
    );
  }

  Widget _fixItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white10, size: 14),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.roboto(fontSize: 13, color: Colors.white38))),
        ],
      ),
    );
  }

  Widget _buildTopologyCard(Color accent) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuB5ZYn4z2wn8iXgWvaa-ZysOP8XmOkvNB3DQLquGIN5VsLOOCEGR90ZMiY_yTtnddWF3Kpw5XPGCZyrdfwC3x1WTpX5kBMi027PuSlCnXewrT2ObbD49W7tnzusJrGf6bZ3IDii9wMz2KIXanzEtW4fqVvSIWYRkWBXwjNiMwA_q0EEogVbY3pypm1ffQ2zF9PxYBG2zkQZE5GCnvw0LLeNb_KOwBY56nb7Fi8mgGLuGHCX2x4rQRSMCegQVh88FN4BYCWHVEQ8_eU"),
          fit: BoxFit.cover,
          opacity: 0.2,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [const Color(0xFF080F17), Colors.transparent]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("COMPUTER OFFLINE", style: GoogleFonts.roboto(fontSize: 8, color: accent, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text("Computer is disconnected", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ],
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
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context)),
          _navItem(Icons.folder_copy_rounded, "Files", false, () {}),
          _navItem(Icons.settings_input_component_rounded, "Controls", false, () {}),
          _navItem(Icons.tune_rounded, "Settings", false, () {}),
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
