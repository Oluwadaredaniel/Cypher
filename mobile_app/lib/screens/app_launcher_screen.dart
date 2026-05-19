import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;

class AppLauncherScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const AppLauncherScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  List<dynamic> _apps = [];
  List<dynamic> _filteredApps = [];
  bool _isLoading = true;
  bool _isError = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {"X-Auth-Token": widget.authToken, "Content-Type": "application/json"};

  Future<void> _fetchApps() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/apps'), headers: _headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is! List) throw Exception("Invalid data format");

        final List<dynamic> data = decoded;
        // Remove duplicates based on name, handling nulls
        final seen = <String>{};
        final unique = data.where((a) {
          final name = a['name']?.toString() ?? "";
          return name.isNotEmpty && seen.add(name);
        }).toList();
        
        unique.sort((a, b) {
          final nameA = a['name']?.toString().toLowerCase() ?? "";
          final nameB = b['name']?.toString().toLowerCase() ?? "";
          return nameA.compareTo(nameB);
        });
        
        if (mounted) {
          setState(() {
            _apps = unique;
            _applyFilter();
            _isLoading = false;
            _isError = false;
          });
        }
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _isError = true; });
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredApps = _apps;
    } else {
      _filteredApps = _apps.where((a) => 
        a['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
  }

  Future<void> _launchApp(String path, String name) async {
    HapticFeedback.mediumImpact();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/apps/launch'),
        headers: _headers,
        body: jsonEncode({"path": path}),
      );
      if (response.statusCode == 200) {
        _showToast("Launching $name...");
      } else {
        _showToast("Failed to launch app", isError: true);
      }
    } catch (e) {
      _showToast("Network error", isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF6C63FF),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : _isError 
                ? _buildErrorState()
                : _buildAppsGrid(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text("App Launcher", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(onPressed: _fetchApps, icon: const Icon(Icons.refresh, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() { _searchQuery = v; _applyFilter(); }),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search apps...",
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.search, color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildAppsGrid() {
    if (_filteredApps.isEmpty) {
      return Center(child: Text("No apps found", style: GoogleFonts.outfit(color: Colors.white24)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
      ),
      itemCount: _filteredApps.length,
      itemBuilder: (context, index) {
        final app = _filteredApps[index];
        return FadeIn(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index < 15 ? index * 30 : 0),
          child: GestureDetector(
            onTap: () => _launchApp(app['path'], app['name']),
            child: Column(
              children: [
                Container(
                  width: 65, height: 65,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: Icon(_getIcon(app['name']), color: const Color(0xFF6C63FF), size: 30),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  app['name'],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('chrome')) return Icons.browser_updated_rounded;
    if (n.contains('spotify')) return Icons.music_note_rounded;
    if (n.contains('vlc')) return Icons.video_library_rounded;
    if (n.contains('word')) return Icons.description_rounded;
    if (n.contains('excel')) return Icons.table_chart_rounded;
    if (n.contains('discord')) return Icons.chat_bubble_rounded;
    if (n.contains('code')) return Icons.code_rounded;
    if (n.contains('steam')) return Icons.videogame_asset_rounded;
    return Icons.apps_rounded;
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text("Failed to load apps", style: GoogleFonts.outfit(color: Colors.white)),
          TextButton(onPressed: _fetchApps, child: const Text("Try Again")),
        ],
      ),
    );
  }
}
