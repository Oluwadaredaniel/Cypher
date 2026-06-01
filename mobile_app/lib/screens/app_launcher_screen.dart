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

class AppLauncherScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const AppLauncherScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  bool _isLoading = true;
  bool _isGridView = true;
  List<dynamic> _apps = [];
  List<dynamic> _filteredApps = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/apps'),
        headers: {'X-Auth-Token': widget.authToken},
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        data.sort((a, b) => (a['name'] as String).toLowerCase().compareTo(b['name'].toLowerCase()));
        setState(() {
          _apps = data;
          _filteredApps = data;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _filterApps(String query) {
    setState(() {
      _filteredApps = _apps.where((app) => (app['name'] as String).toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  Future<void> _launchApp(String path) async {
    HapticFeedback.lightImpact();
    try {
      await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/apps/launch'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Launching...")));
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
                        const SizedBox(height: 8),
                        _buildSearchBox(isDark),
                        const SizedBox(height: 32),
                        _buildSectionHeader("INSTALLED APPLICATIONS", _buildViewToggle(isDark), isDark),
                        const SizedBox(height: 16),
                        _isLoading
                          ? Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: accent)))
                          : (_isGridView ? _buildAppsGrid(accent, isDark) : _buildAppsList(accent, isDark)),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color accent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
              Text("APP LAUNCHER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
            ],
          ),
          IconButton(icon: Icon(Icons.refresh_rounded, color: accent.withOpacity(0.5)), onPressed: _fetchApps),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _filterApps,
              style: GoogleFonts.roboto(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Search your computer...",
                hintStyle: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Widget? trailing, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2, fontWeight: FontWeight.bold)),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildViewToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          _toggleBtn(Icons.grid_view_rounded, _isGridView, () => setState(() => _isGridView = true)),
          const SizedBox(width: 4),
          _toggleBtn(Icons.list_alt_rounded, !_isGridView, () => setState(() => _isGridView = false)),
        ],
      ),
    );
  }

  Widget _toggleBtn(IconData icon, bool active, VoidCallback tap) {
    final isDark = Provider.of<ThemeService>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: active ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: active ? const Color(0xFF6C63FF) : (isDark ? Colors.white24 : Colors.black26), size: 16),
      ),
    );
  }

  Widget _buildAppsGrid(Color accent, bool isDark) {
    if (_filteredApps.isEmpty) return _buildNoApps(isDark);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredApps.length,
      itemBuilder: (context, index) {
        final app = _filteredApps[index];
        final iconUrl = 'http://${widget.pcIpAddress}:5000/system/window-icon?path=${Uri.encodeComponent(app['path'])}&token=${widget.authToken}';

        return FadeInUp(
          delay: Duration(milliseconds: index * 20),
          child: GestureDetector(
            onTap: () => _launchApp(app['path']),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: GlassContainer(
                    width: double.infinity,
                    child: Center(
                      child: Image.network(
                        iconUrl,
                        width: 32, height: 32,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.rocket_launch_rounded, color: accent.withOpacity(0.5), size: 32),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  app['name'],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppsList(Color accent, bool isDark) {
    if (_filteredApps.isEmpty) return _buildNoApps(isDark);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredApps.length,
      itemBuilder: (context, index) {
        final app = _filteredApps[index];
        final iconUrl = 'http://${widget.pcIpAddress}:5000/system/window-icon?path=${Uri.encodeComponent(app['path'])}&token=${widget.authToken}';

        return FadeInUp(
          delay: Duration(milliseconds: index * 10),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _launchApp(app['path']),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Image.network(
                      iconUrl,
                      width: 24, height: 24,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.rocket_launch_rounded, color: accent.withOpacity(0.5), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(app['name'], style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
                    ),
                    Icon(Icons.rocket_launch_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoApps(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text("No applications found", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
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
          _navItem(Icons.grid_view_rounded, "Tools", true, null, isDark),
          _navItem(Icons.tune_rounded, "Settings", false, () => Navigator.pushReplacementNamed(context, '/settings', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
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
