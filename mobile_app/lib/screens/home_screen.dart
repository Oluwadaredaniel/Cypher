import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/central_service.dart';

class HomeScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const HomeScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _activeTab = 0;
  bool _isLoading = true;
  bool _isError = false;

  // Dynamic Data
  String _pcName = "My PC";
  Map<String, dynamic> _systemStats = {};
  List<dynamic> _recentActivity = [];
  List<dynamic> _pcFolders = [];
  int _notificationCount = 0;
  Map<String, dynamic>? _broadcast;

  // Controllers
  late AnimationController _storageRingController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _storageRingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initFetch();
    _startConnectionMonitor();
    _fetchBroadcast();
    _checkMobileUpdate();
  }

  Future<void> _checkMobileUpdate() async {
    final update = await CentralService.checkForUpdates();
    if (mounted && update != null && update['update_available'] == true) {
      _showUpdateBanner(update['version'], update['url']);
    }
  }

  void _showUpdateBanner(String version, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✨ New Version v$version available!", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6C63FF),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: "GET APK",
          textColor: Colors.white,
          onPressed: () => launchUrlString(url),
        ),
      ),
    );
  }

  Future<void> _fetchBroadcast() async {
    final data = await CentralService.getBroadcast();
    if (mounted && data != null && data['active'] == true) {
      setState(() => _broadcast = data);
    }
  }

  void _startConnectionMonitor() {
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) { timer.cancel(); return; }
      try {
        final response = await http.get(
          Uri.parse('http://${widget.pcIpAddress}:5000/ping'),
          headers: {'X-Auth-Token': widget.authToken},
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200 && mounted) {
          timer.cancel();
          _handleConnectionLoss();
        }
      } catch (e) {
        if (mounted) {
          timer.cancel();
          _handleConnectionLoss();
        }
      }
    });
  }

  @override
  void dispose() {
    _storageRingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initFetch() async {
    setState(() { _isLoading = true; _isError = false; });
    try {
      final headers = {'X-Auth-Token': widget.authToken};
      final baseUrl = 'http://${widget.pcIpAddress}:5000';

      // Run all 4 fetches in parallel
      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/status'), headers: headers),
        http.get(Uri.parse('$baseUrl/system-stats'), headers: headers),
        http.get(Uri.parse('$baseUrl/files'), headers: headers),
        http.get(Uri.parse('$baseUrl/history'), headers: headers),
      ]).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      // Parse status
      if (results[0].statusCode == 200) {
        final data = json.decode(results[0].body);
        _pcName = data['pc_name'] ?? 'My PC';
      }

      // Parse system stats
      if (results[1].statusCode == 200) {
        final stats = json.decode(results[1].body);
        _systemStats = {
          'storage_used_percent': stats['disk_percent'] ?? 0,
          'storage_available': '${stats['disk_used']?.toStringAsFixed(1) ?? '?'} GB used of ${stats['disk_total']?.toStringAsFixed(1) ?? '?'} GB',
          'storage_total': '${stats['disk_total']?.toStringAsFixed(1) ?? '?'} GB',
          'cpu_percent': stats['cpu_percent'] ?? 0,
          'ram_percent': stats['ram_percent'] ?? 0,
        };
      }

      // Parse folders
      if (results[2].statusCode == 200) {
        _pcFolders = json.decode(results[2].body);
      }

      // Parse recent activity — translate endpoints to friendly text
      if (results[3].statusCode == 200) {
        final history = json.decode(results[3].body) as List;
        _recentActivity = history.reversed.take(5).map((item) {
          final ep = item['endpoint'] ?? '';
          String action = 'Performed an action';
          if (ep.contains('/files/download')) action = 'Downloaded a file';
          else if (ep.contains('/files/browse')) action = 'Browsed files';
          else if (ep.contains('/files/upload')) action = 'Sent a file to PC';
          else if (ep.contains('/files/delete')) action = 'Deleted a file';
          else if (ep.contains('/power')) action = 'Used power controls';
          else if (ep.contains('/screenshot')) action = 'Took a screenshot';
          else if (ep.contains('/clipboard')) action = 'Used clipboard';
          return {
            'name': action,
            'size': item['timestamp'] ?? '',
            'path': '',
            'success': item['success'] ?? true,
          };
        }).toList();
      }

      setState(() { _isLoading = false; });
      _storageRingController.forward(from: 0.0);

    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _isError = true; });
    }
  }

  void _handleConnectionLoss() {
    Navigator.pushNamed(context, '/disconnected', arguments: {
      'pcIpAddress': widget.pcIpAddress,
      'authToken': widget.authToken,
    });
  }

  // --- NAVIGATION WRAPPERS (CENTRALIZED LOGIC) ---

  void _navigateToBrowser([String? path]) {
    Navigator.pushNamed(context, '/browser', arguments: {
      'pcIpAddress': widget.pcIpAddress,
      'authToken': widget.authToken,
      'initialPath': path,
    });
  }

  void _navigateToSettings() {
    // Check if the user is Emerald (Master Mode)
    // You can change this to your actual device ID or a special token
    if (widget.authToken.contains("master-emerald-key")) {
      _showMasterMenu();
      return;
    }

    Navigator.pushNamed(context, '/settings', arguments: {
      'pcIpAddress': widget.pcIpAddress,
      'authToken': widget.authToken,
    });
  }

  void _showMasterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("MASTER COMMAND", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 30),
            _buildMasterAction(Icons.analytics_rounded, "View Live Installs", () => launchUrlString("https://cypher-3ctq.onrender.com/master")),
            _buildMasterAction(Icons.campaign_rounded, "Push Global Broadcast", () => launchUrlString("https://cypher-3ctq.onrender.com/master")),
            _buildMasterAction(Icons.settings_suggest_rounded, "System Settings", () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken});
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF)),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFF333333)),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyMasterLogin(String input, BuildContext ctx) async {
    try {
      final response = await http.get(Uri.parse('https://cypher-3ctq.onrender.com/api/metadata'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final correctPass = data['master_password'] ?? "emerald-admin";
        
        if (input == correctPass) {
          Navigator.pop(ctx);
          Navigator.pushNamed(context, '/master_control');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid Master Key"), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      // Offline fallback
      if (input == "emerald-admin") {
        Navigator.pop(ctx);
        Navigator.pushNamed(context, '/master_control');
      }
    }
  }

  void _showMasterLogin() {
    HapticFeedback.heavyImpact();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("MASTER LOGIN", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Enter Master Key", hintStyle: TextStyle(color: Colors.white24)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => _verifyMasterLogin(controller.text, ctx),
            child: const Text("LOGIN", style: TextStyle(color: Color(0xFF6C63FF)))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isError 
                      ? _buildErrorState() 
                      : (_isLoading ? _buildShimmerLoading() : _buildCurrentTab()),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onLongPress: _showMasterLogin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CYPHER",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF6C63FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _pcName,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF30D158),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _navigateToSettings,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                  if (_notificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_activeTab) {
      case 0: return _buildFilesTab();
      case 3: return _buildMoreTab();
      default: return _buildFilesTab();
    }
  }

  Widget _buildFilesTab() {
    return ListView(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      children: [
        if (_broadcast != null) ...[
          FadeInDown(
            child: _buildBroadcastBanner(),
          ),
          const SizedBox(height: 20),
        ],
        FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: _buildStorageCard(),
        ),
        const SizedBox(height: 25),
        
        FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: _buildQuickActionCard(
            "Get from PC",
            "Browse and download any file from your computer",
            Icons.folder_open_rounded,
            () => _navigateToBrowser(),
          ),
        ),
        const SizedBox(height: 25),

        FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: _buildSectionHeader("Folders", () => _navigateToBrowser()),
        ),
        const SizedBox(height: 15),
        
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.4,
          children: _pcFolders.isEmpty
            ? _buildDefaultFolderTiles()
            : _pcFolders.take(6).map<Widget>((folder) {
                final name = folder['name'] ?? 'Folder';
                final path = folder['path'] ?? '';
                return _buildFolderTile(
                  name, '',
                  _getFolderIcon(name),
                  _getFolderColor(name),
                  () => _navigateToBrowser(path),
                );
              }).toList(),
        ),
        const SizedBox(height: 25),
        _buildDesignerCredit(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildDesignerCredit() {
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Designed by ", style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
            GestureDetector(
              onTap: () => launchUrlString("https://www.tiktok.com/@emerald_dev1"),
              child: Text("Emerald", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDefaultFolderTiles() {
    return [
      _buildFolderTile("Downloads", "", Icons.download_rounded, const Color(0xFF6C63FF), () => _navigateToBrowser()),
      _buildFolderTile("Documents", "", Icons.description_rounded, Colors.orange, () => _navigateToBrowser()),
      _buildFolderTile("Pictures", "", Icons.image_rounded, Colors.pink, () => _navigateToBrowser()),
      _buildFolderTile("Videos", "", Icons.videocam_rounded, Colors.redAccent, () => _navigateToBrowser()),
    ];
  }

  IconData _getFolderIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('download')) return Icons.download_rounded;
    if (n.contains('document')) return Icons.description_rounded;
    if (n.contains('picture') || n.contains('photo') || n.contains('image')) return Icons.image_rounded;
    if (n.contains('video') || n.contains('movie')) return Icons.videocam_rounded;
    if (n.contains('music') || n.contains('audio')) return Icons.music_note_rounded;
    if (n.contains('desktop')) return Icons.desktop_windows_rounded;
    return Icons.folder_rounded;
  }

  Color _getFolderColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('download')) return const Color(0xFF6C63FF);
    if (n.contains('document')) return Colors.orange;
    if (n.contains('picture') || n.contains('photo')) return Colors.pink;
    if (n.contains('video')) return Colors.redAccent;
    if (n.contains('music')) return Colors.greenAccent;
    if (n.contains('desktop')) return Colors.blueAccent;
    return Colors.grey;
  }

  Widget _buildRecentActivityItem(Map<String, dynamic> item) {
    final bool success = item['success'] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Row(
        children: [
          Container(
            width: 45, height: 45,
            decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(12)),
            child: Icon(
              success ? Icons.history_rounded : Icons.error_outline_rounded, 
              color: success ? const Color(0xFF6C63FF) : Colors.redAccent, 
              size: 22
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Action',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)
                ),
                Text(item['size'] ?? '', style: GoogleFonts.outfit(color: const Color(0xFF4C4C4C), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTab() {
    return ListView(
      key: const ValueKey(3),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      children: [
        _buildMoreSection("SECURITY"),
        _buildMoreItem("Guest Access", "Share temporary access codes", Icons.people_outline, () => Navigator.pushNamed(context, '/guest', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken})),
        _buildMoreItem("Encryption Keys", "Manage your end-to-end security", Icons.vpn_key_outlined, () {}),
        
        const SizedBox(height: 25),
        _buildMoreSection("ACTIVITY"),
        _buildMoreItem("Activity Log", "View your recent transfer history", Icons.history_rounded, () => Navigator.pushNamed(context, '/activity', arguments: {
          'pcIpAddress': widget.pcIpAddress,
          'authToken': widget.authToken,
        })),
        _buildMoreItem("Notifications", "Manage alerts and status updates", Icons.notifications_none_rounded, () => Navigator.pushNamed(context, '/notifications', arguments: {
          'pcIpAddress': widget.pcIpAddress,
          'authToken': widget.authToken,
        })),
        
        const SizedBox(height: 25),
        _buildMoreSection("SYSTEM"),
        _buildMoreItem("User Guide", "How to get the most out of CYPHER", Icons.help_outline_rounded, () => Navigator.pushNamed(context, '/guide')),
        _buildMoreItem("Settings", "App preferences and PC connection", Icons.settings_applications_outlined, _navigateToSettings),
        _buildMoreItem("About CYPHER", "Version 1.0.0 • Made with love", Icons.info_outline_rounded, _navigateToSettings),
        
        const SizedBox(height: 40),
        Center(
          child: Text(
            "Device ID: ${widget.authToken.substring(0, min(8, widget.authToken.length)).toUpperCase()}",
            style: GoogleFonts.outfit(color: const Color(0xFF2C2C2C), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 25,
      left: 20,
      right: 20,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.folder_rounded, "Files"),
            _buildNavItem(1, Icons.send_rounded, "Send", isSpecial: true, onTap: () {
              Navigator.pushNamed(context, '/send', arguments: {
                'pcIpAddress': widget.pcIpAddress,
                'authToken': widget.authToken,
              });
            }),
            _buildNavItem(2, Icons.shutter_speed_rounded, "Controls", isSpecial: true, onTap: () {
               Navigator.pushNamed(context, '/controls', arguments: {
                'pcIpAddress': widget.pcIpAddress,
                'authToken': widget.authToken,
              });
            }),
            _buildNavItem(3, Icons.more_horiz_rounded, "More"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool isSpecial = false, VoidCallback? onTap}) {
    bool isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap();
        } else {
          setState(() => _activeTab = index);
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF86868B),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isActive ? Colors.white : const Color(0xFF86868B),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text("📢", style: TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _broadcast?['title'] ?? "Announcement",
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  _broadcast?['message'] ?? "",
                  style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12),
                ),
              ],
            ),
          ),
          if (_broadcast?['link'] != null)
            GestureDetector(
              onTap: () => launchUrlString(_broadcast!['link']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _broadcast?['link_text'] ?? "Join",
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStorageCard() {
    double usedPercent = (_systemStats['storage_used_percent'] ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: _storageRingController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _storageRingController.value * (usedPercent / 100),
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFF0D0D0D),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                    ),
                    Text(
                      "${usedPercent.toInt()}%",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PC Storage",
                  style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14),
                ),
                Text(
                  _systemStats['storage_total'] != null ? "Active" : "Calculating...",
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Total: ${_systemStats['storage_total'] ?? '...'}",
                  style: GoogleFonts.outfit(color: const Color(0xFF4C4C4C), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, String desc, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF4B45B2)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(desc, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: onSeeAll,
          child: Text("See all", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildFolderTile(String name, String count, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                Text(count, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: GoogleFonts.outfit(color: const Color(0xFF4C4C4C), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildMoreItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2C2C2C), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF262626),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(height: 120, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 25),
          Container(height: 80, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(child: Container(height: 110, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)))),
              const SizedBox(width: 15),
              Expanded(child: Container(height: 110, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)))),
            ],
          ),
          const SizedBox(height: 15),
          Container(height: 200, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20))),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF453A), size: 60),
            const SizedBox(height: 20),
            Text("Connection Lost", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("We couldn't reach your PC. Please ensure it's on and connected to the same network.", textAlign: TextAlign.center, style: GoogleFonts.outfit(color: const Color(0xFF86868B))),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _initFetch,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: const StadiumBorder()),
                child: Text("Try Again", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}