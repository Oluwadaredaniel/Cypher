import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class GuestScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const GuestScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  bool _isLoading = true;
  List<String> _availableFolders = [];
  final Set<String> _selectedFolders = {};
  int _selectedDuration = 60;
  List<dynamic> _activeSessions = [];

  // Real-time simulated stats for UI fidelity
  double _bandwidth = 1.2;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final headers = {'X-Auth-Token': widget.authToken};
      final baseUrl = 'http://${widget.pcIpAddress}:5000';

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/settings'), headers: headers),
        http.get(Uri.parse('$baseUrl/guest/sessions'), headers: headers),
      ]);

      if (results[0].statusCode == 200) {
        final settings = jsonDecode(results[0].body);
        _availableFolders = (settings['shared_folders'] as List).cast<String>();
      }

      if (results[1].statusCode == 200) {
        setState(() => _activeSessions = jsonDecode(results[1].body)['sessions']);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _generateLink() async {
    if (_selectedFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one folder")));
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/guest/create'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'folders': _selectedFolders.toList(),
          'duration_minutes': _selectedDuration,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        Navigator.pop(context); // Close config sheet
        _showSuccessDialog(data['url']);
        _fetchData();
      }
    } catch (_) {}
  }

  Future<void> _endSession(String token) async {
    HapticFeedback.mediumImpact();
    try {
      await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/guest/end'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'guest_token': token}),
      );
      _fetchData();
    } catch (_) {}
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
            child: Column(
              children: [
                _buildTopBar(accent, isDark),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(accent, isDark),
                        const SizedBox(height: 24),
                        _buildStatsSummary(accent, isDark),
                        const SizedBox(height: 32),
                        _buildActiveFeedHeader(isDark),
                        const SizedBox(height: 16),
                        _isLoading
                          ? Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: accent)))
                          : _buildActiveFeed(accent, isDark),
                        const SizedBox(height: 32),
                        _buildAccessMap(isDark),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
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
                Text("CYPHER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.sensors_rounded, color: accent, size: 18),
                const SizedBox(width: 8),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF10B981), blurRadius: 4)])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent, bool isDark) => const SizedBox(height: 64);

  Widget _buildPageHeader(Color accent, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SECURITY PROTOCOL 8-BETA", style: GoogleFonts.roboto(fontSize: 9, color: accent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Session Manager", style: GoogleFonts.roboto(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
            GestureDetector(
              onTap: () => _showInviteSheet(isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 10)]),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text("INVITE", style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSummary(Color accent, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("TOTAL ACTIVE", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold)),
                    Icon(Icons.group_rounded, color: accent, size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_activeSessions.length.toString().padLeft(2, '0'), style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                Text("Concurrent instances", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("BANDWIDTH", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold)),
                    const Icon(Icons.speed_rounded, color: Color(0xFFFFB786), size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_bandwidth.toString(), style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    Text(" GB/s", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: 0.65, minHeight: 2, backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05), valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB786))),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFeedHeader(bool isDark) {
    return Row(
      children: [
        Text("ACTIVE USER FEED", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2))),
          child: Text("LIVE", style: GoogleFonts.roboto(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
        )
      ],
    );
  }

  Widget _buildActiveFeed(Color accent, bool isDark) {
    if (_activeSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(60),
          child: Text("No active sessions monitored", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.12), fontSize: 13)),
        ),
      );
    }

    return Column(
      children: _activeSessions.map((session) {
        final bool isLive = session['is_active'];
        final int mins = session['time_remaining_seconds'] ~/ 60;

        return FadeInUp(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      child: Icon(Icons.person_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), size: 24),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(color: isLive ? const Color(0xFF10B981) : Colors.amber, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)),
                      ),
                    )
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("Guest Session", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(width: 8),
                          Text("ID: ${session['token'].toString().substring(0, 4)}", style: GoogleFonts.roboto(fontSize: 8, color: accent.withOpacity(0.5))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24)),
                          const SizedBox(width: 4),
                          Text("Remote Access", style: GoogleFonts.roboto(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                          const SizedBox(width: 12),
                          Icon(Icons.timer_rounded, size: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24)),
                          const SizedBox(width: 4),
                          Text("${mins}m left", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _endSession(session['token']),
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccessMap(bool isDark) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuCs-75RH_qj4bmXODt-AScnPZQfd_kpwFWBda9uLgfsJsnUPGAwLbi6JEtKqYL5CQ2-CpdeYAS2SLAosj13Z97kUQ3Z8XMnIRb9WL-S8VYfnHTlpXZftu_QNWXr2nFiWg7qwj9udaK13CHONAHBk9H-KAb_dW81ZCViOhgNyym2N2QwtBJEOewH8qqRhOJpwUL4YHuHzndq31XJslvly-Qs5fp42BD821KdI3SO6QQ7vUpNOgyhevWD9NxsyJqcyRmkdT4owW-MOCg"),
          fit: BoxFit.cover,
          opacity: 0.4,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Theme.of(context).scaffoldBackgroundColor, Colors.transparent]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Global Access Map", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                Text("Real-time geographical tracking.", style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
                const Spacer(),
                Wrap(
                  spacing: 12,
                  children: [
                    _mapChip("USER A", const Color(0xFF6C63FF), isDark),
                    _mapChip("USER B", const Color(0xFFFFB786), isDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapChip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: (isDark ? Colors.black : Colors.white).withOpacity(0.4), borderRadius: BorderRadius.circular(10), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 4)])),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.roboto(fontSize: 8, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showInviteSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("INVITE GUEST", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 24),
              Text("SELECT FOLDERS", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 1)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _availableFolders.map((f) {
                  bool sel = _selectedFolders.contains(f);
                  return GestureDetector(
                    onTap: () => setSheetState(() => sel ? _selectedFolders.remove(f) : _selectedFolders.add(f)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: sel ? const Color(0xFF6C63FF).withOpacity(0.1) : (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? const Color(0xFF6C63FF).withOpacity(0.3) : (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
                      child: Text(f.split('/').last.split('\\').last, style: GoogleFonts.roboto(fontSize: 12, color: sel ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(onPressed: _generateLink, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text("GENERATE LINK", style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.white))),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String url) {
    final isDark = Provider.of<ThemeService>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: QrImageView(data: url, size: 180)),
            const SizedBox(height: 24),
            Text("LINK GENERATED", style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () { Clipboard.setData(ClipboardData(text: url)); Navigator.pop(ctx); },
              child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: Text("Tap to copy link", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.38)))), const Icon(Icons.copy_rounded, color: Color(0xFF6C63FF), size: 16)])),
            ),
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
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context)),
          _navItem(Icons.folder_copy_rounded, "Files", false, () => Navigator.pushReplacementNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken})),
          _navItem(Icons.settings_input_component_rounded, "Controls", false, () => Navigator.pushReplacementNamed(context, '/controls', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken})),
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
