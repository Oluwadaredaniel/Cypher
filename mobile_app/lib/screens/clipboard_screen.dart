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
  String _activeContent = "No content shared yet.";
  bool _isLoading = false;
  String _pcName = "Computer";

  @override
  void initState() {
    super.initState();
    _fetchPCInfo();
  }

  Future<void> _fetchPCInfo() async {
    try {
      final res = await http.get(Uri.parse('http://${widget.pcIpAddress}:5000/status'), headers: {'X-Auth-Token': widget.authToken});
      if (res.statusCode == 200) {
        setState(() => _pcName = jsonDecode(res.body)['pc_name'] ?? "Computer");
      }
    } catch (_) {}
  }

  Future<void> _pullFromPC() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/clipboard'),
        headers: {'X-Auth-Token': widget.authToken},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final content = jsonDecode(res.body)['content'] ?? "";
        setState(() => _activeContent = content.isEmpty ? "PC Clipboard is empty" : content);
        if (content.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: content));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Synced from computer to phone"), backgroundColor: Color(0xFF10B981)),
            );
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unauthorized or PC busy"), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unable to reach computer"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pushToPC() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone clipboard is empty")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/clipboard'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'text': data.text}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        setState(() => _activeContent = data.text!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sent phone clipboard to computer"), backgroundColor: Color(0xFF6C63FF)),
          );
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send content"), backgroundColor: Colors.orange));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unable to reach computer"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  _buildStatusCard(isDark),
                  const SizedBox(height: 24),
                  _buildActionGrid(accent, isDark),
                  const SizedBox(height: 40),
                  _buildSectionHeader("RECENT CONTENT", isDark),
                  const SizedBox(height: 16),
                  _buildActiveStage(accent, isDark),
                  const SizedBox(height: 40),
                  _buildSectionHeader("SYNC HISTORY", isDark),
                  const SizedBox(height: 16),
                  _buildHistoryBento(isDark),
                ],
              ),
            ),
          ),
          _buildFloatingHeader(accent, isDark),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav(isDark)),
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
                Text("CLIPBOARD", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            if (_isLoading)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
            else
              Icon(Icons.sensors_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF10B981), blurRadius: 10)]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sync Channel Active", style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                Text("Linked to $_pcName", style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.laptop_windows_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 18),
              const SizedBox(width: 4),
              const Icon(Icons.sync_rounded, color: Color(0xFF6C63FF), size: 14),
              const SizedBox(width: 4),
              Icon(Icons.phone_android_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 18),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionGrid(Color accent, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            "Send to PC", "Push local text", Icons.arrow_upward_rounded, accent, _pushToPC
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _actionButton(
            "Get from PC", "Pull remote text", Icons.arrow_downward_rounded, (isDark ? const Color(0xFF192029) : Colors.white), _pullFromPC, isDark: isDark
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String title, String sub, IconData icon, Color bg, VoidCallback tap, {bool isDark = true}) {
    bool isCustomBg = bg != const Color(0xFF192029) && bg != Colors.white;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        tap();
      },
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: isCustomBg ? [BoxShadow(color: bg.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))] : null,
          border: !isCustomBg ? Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isCustomBg ? Colors.white : (isDark ? Colors.white : Colors.black), size: 32),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold, color: isCustomBg ? Colors.white : (isDark ? Colors.white : Colors.black))),
            Text(sub, style: GoogleFonts.roboto(fontSize: 10, color: (isCustomBg ? Colors.white : (isDark ? Colors.white : Colors.black)).withOpacity(0.5))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(title, style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2));
  }

  Widget _buildActiveStage(Color accent, bool isDark) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.article_rounded, color: accent, size: 16),
                    const SizedBox(width: 10),
                    Text("SHARED TEXT", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _activeContent,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(fontSize: 16, color: isDark ? Colors.white : Colors.black, height: 1.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Last updated: Just now", style: GoogleFonts.roboto(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _activeContent));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to device")));
                  },
                  child: Row(
                    children: [
                      Icon(Icons.copy_all_rounded, color: accent, size: 16),
                      const SizedBox(width: 8),
                      Text("Copy Locally", style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryBento(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _historySmall("github.com/cypher", Icons.link_rounded, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _historySmall("#6C63FF", Icons.palette_rounded, isDark)),
          ],
        ),
        const SizedBox(height: 12),
        _historyWide("Finalize document formatting and encryption schema...", Icons.notes_rounded, isDark),
      ],
    );
  }

  Widget _historySmall(String title, IconData icon, bool isDark) {
    return GlassContainer(
      height: 100,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          Text(title, style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _historyWide(String title, IconData icon, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: GoogleFonts.roboto(fontSize: 13, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7)), overflow: TextOverflow.ellipsis)),
          Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 18),
        ],
      ),
    );
  }
}
