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
        setState(() {
          _availableFolders = (settings['shared_folders'] as List).cast<String>();
        });
      }

      if (results[1].statusCode == 200) {
        setState(() => _activeSessions = jsonDecode(results[1].body)['sessions'] ?? []);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _generateLink() async {
    if (_selectedFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one folder")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/guest/create'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'folders': _selectedFolders.toList(),
          'duration_minutes': _selectedDuration,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          Navigator.pop(context); // Close config sheet
          _showSuccessDialog(data['url']);
          _fetchData();
        }
      } else {
        throw Exception("Server rejected request");
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to generate link: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      backgroundColor: isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7),
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
                        _isLoading && _activeSessions.isEmpty
                          ? Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: accent)))
                          : _buildActiveFeed(accent, isDark),
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
          color: (isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7)).withOpacity(0.8),
          border: Border(bottom: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
                Text("GUEST MODE", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.lock_person_rounded, color: accent, size: 18),
                const SizedBox(width: 8),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
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
        Text("TEMPORARY ACCESS CONTROL", style: GoogleFonts.roboto(fontSize: 9, color: accent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Session Hub", style: GoogleFonts.roboto(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
            GestureDetector(
              onTap: () => _showInviteSheet(isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 10)]),
                child: Row(
                  children: [
                    const Icon(Icons.add_link_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text("CREATE", style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
                    Text("ACTIVE LINKS", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold)),
                    Icon(Icons.link_rounded, color: accent, size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_activeSessions.length.toString().padLeft(2, '0'), style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                Text("Temporary sessions", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
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
                    Text("DIRECTORIES", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold)),
                    const Icon(Icons.folder_shared_rounded, color: Color(0xFFFFB786), size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_availableFolders.length.toString().padLeft(2, '0'), style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                Text("Authorizable folders", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
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
        Text("ACTIVE GUEST SESSIONS", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
          child: Text("MONITORED", style: GoogleFonts.roboto(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
        )
      ],
    );
  }

  Widget _buildActiveFeed(Color accent, bool isDark) {
    if (_activeSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(60),
          child: Column(
            children: [
              Icon(Icons.person_off_outlined, size: 48, color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
              const SizedBox(height: 16),
              Text("No active guest sessions", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.12), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _activeSessions.map((session) {
        final int mins = (session['time_remaining_seconds'] ?? 0) ~/ 60;
        final token = session['token'].toString();

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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: accent.withOpacity(0.1),
                  child: Icon(Icons.person_pin_circle_rounded, color: accent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Guest - ${token.substring(0, 8)}", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.timer_rounded, size: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24)),
                          const SizedBox(width: 4),
                          Text("${mins}m remaining", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                          const SizedBox(width: 12),
                          Icon(Icons.touch_app_rounded, size: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24)),
                          const SizedBox(width: 4),
                          Text("${session['access_count'] ?? 0} hits", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _endSession(token),
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
              Text("GENERATE GUEST LINK", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 24),

              Text("AUTHORIZE DIRECTORIES", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 1, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_availableFolders.isEmpty)
                Text("No shared folders available on PC.", style: TextStyle(color: Colors.redAccent.withOpacity(0.5), fontSize: 12))
              else
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _availableFolders.map((f) {
                    bool sel = _selectedFolders.contains(f);
                    final name = f.split('/').last.split('\\').last;
                    return GestureDetector(
                      onTap: () => setSheetState(() => sel ? _selectedFolders.remove(f) : _selectedFolders.add(f)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFF6C63FF).withOpacity(0.1) : (isDark ? Colors.white : Colors.black).withOpacity(0.02),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? const Color(0xFF6C63FF).withOpacity(0.3) : (isDark ? Colors.white : Colors.black).withOpacity(0.05))
                        ),
                        child: Text(name, style: GoogleFonts.roboto(fontSize: 12, color: sel ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),
              Text("EXPIRATION TIME", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 1, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _durationOption(15, "15 MINS", setSheetState),
                  const SizedBox(width: 8),
                  _durationOption(60, "1 HOUR", setSheetState),
                  const SizedBox(width: 8),
                  _durationOption(1440, "1 DAY", setSheetState),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _generateLink,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text("GENERATE LINK", style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.white))
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationOption(int mins, String label, StateSetter setSheetState) {
    bool sel = _selectedDuration == mins;
    final isDark = Provider.of<ThemeService>(context, listen: false).isDarkMode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setSheetState(() => _selectedDuration = mins),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFFFB786).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? const Color(0xFFFFB786).withOpacity(0.3) : (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
          ),
          child: Center(child: Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: sel ? const Color(0xFFFFB786) : (isDark ? Colors.white24 : Colors.black26)))),
        ),
      ),
    );
  }

  void _showSuccessDialog(String url) {
    final isDark = Provider.of<ThemeService>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
              child: QrImageView(data: url, size: 180)
            ),
            const SizedBox(height: 32),
            Text("LINK GENERATED", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text("Anyone with this QR can access selected files.", textAlign: TextAlign.center, style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38))),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link copied to clipboard")));
                Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.copy_rounded, color: Color(0xFF6C63FF), size: 18),
                    const SizedBox(width: 12),
                    Text("Copy Link", style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
                  ],
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final theme = Provider.of<ThemeService>(context, listen: false).isDarkMode;
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context), theme),
          _navItem(Icons.folder_copy_rounded, "Files", false, () => Navigator.pushReplacementNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), theme),
          _navItem(Icons.grid_view_rounded, "Tools", false, () => Navigator.pushReplacementNamed(context, '/controls', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), theme),
          _navItem(Icons.tune_rounded, "Settings", true, null, theme),
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
