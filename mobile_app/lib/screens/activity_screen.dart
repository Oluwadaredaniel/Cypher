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

class ActivityScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ActivityScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
  List<dynamic> _activity = [];
  String _activeFilter = "ALL";
  final List<String> _filters = ["ALL", "FILES", "SYSTEM", "SECURITY"];

  @override
  void initState() {
    super.initState();
    _fetchActivity();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchActivity() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/system/activity'),
        headers: {'X-Auth-Token': widget.authToken},
      );
      if (res.statusCode == 200) {
        setState(() => _activity = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
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
                        _buildHeader(isDark),
                        const SizedBox(height: 24),
                        _buildFilterRow(isDark, accent),
                        const SizedBox(height: 24),
                        _isLoading
                          ? Center(child: Padding(padding: const EdgeInsets.all(60), child: CircularProgressIndicator(color: accent)))
                          : _buildActivityList(isDark, accent),
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
                Text("LOGS", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Icon(Icons.history_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent, bool isDark) => const SizedBox(height: 64);

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Activity History", style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 8),
        Text("Track all interactions between your phone and PC.", style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
      ],
    );
  }

  Widget _buildFilterRow(bool isDark, Color accent) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((f) {
          bool isSelected = _activeFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? accent : (isDark ? Colors.white : Colors.black).withOpacity(0.03),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: isSelected ? accent : (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
              ),
              child: Text(f, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityList(bool isDark, Color accent) {
    final filtered = _activeFilter == "ALL" ? _activity : _activity.where((a) => a['type'].toString().toUpperCase() == _activeFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text("No entries found for this category.", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final a = filtered[index];
        return _activityItem(a, isDark, accent);
      },
    );
  }

  Widget _activityItem(dynamic a, bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Icon(_getIconForType(a['type']), color: accent, size: 18)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['title'] ?? "Event", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 4),
                  Text(a['timestamp'] ?? "Just now", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 16),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(dynamic type) {
    switch (type.toString().toUpperCase()) {
      case "FILES": return Icons.folder_copy_rounded;
      case "SYSTEM": return Icons.computer_rounded;
      case "SECURITY": return Icons.shield_rounded;
      default: return Icons.info_rounded;
    }
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
