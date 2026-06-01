import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/bridge_service.dart';
import '../services/theme_service.dart';

// Tab Modules
import 'tabs/home_tab.dart';
import 'tabs/health_tab.dart';
import 'tabs/transfers_tab.dart';
import 'tabs/files_tab.dart';
import 'tabs/security_tab.dart';
import 'tabs/activity_tab.dart';
import 'tabs/settings_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  String _activeTab = "Home";
  final BridgeService _bridge = BridgeService();
  Timer? _syncTimer;
  late AnimationController _waveController;

  // Live Data State
  String _pairingCode = "------";
  String _pcIp = "127.0.0.1";
  bool _isSystemActive = true;
  bool _isOptimizing = false;
  List<dynamic> _devices = [];
  List<dynamic> _sharedFolders = [];
  List<dynamic> _securitySessions = [];
  List<dynamic> _activityLog = [];
  Map<String, dynamic> _stats = {
    "cpu_percent": 0.0,
    "ram_percent": 0.0,
    "disk_percent": 0.0,
    "ram_used": 0.0,
    "ram_total": 0.0,
  };
  Map<String, dynamic> _activeTransfers = {};
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _startSync();
    _loadSettings();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _startSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) return;

      try {
        // Parallel fetching to avoid sequential bottlenecks
        final results = await Future.wait([
          _bridge.getConnectCode(),
          _bridge.getPairedDevices(),
          _bridge.getSystemStats(),
          _bridge.getTransfers(),
          _bridge.getSharedFolders(),
          _bridge.getSecuritySessions(),
          _bridge.getActivityLog(),
          _bridge.getNetworkInfo(),
        ]).timeout(const Duration(seconds: 5));

        if (mounted) {
          setState(() {
            _pairingCode = results[0] as String;
            _devices = results[1] as List<dynamic>;
            final stats = results[2] as Map<String, dynamic>;
            if (stats.isNotEmpty) _stats = stats;
            _activeTransfers = results[3] as Map<String, dynamic>;
            _sharedFolders = results[4] as List<dynamic>;
            _securitySessions = results[5] as List<dynamic>;
            _activityLog = results[6] as List<dynamic>;
            final netInfo = results[7] as Map<String, dynamic>;
            _pcIp = netInfo['pc_ip'] ?? "127.0.0.1";
            _isSystemActive = true;
          });
        }

        // Special case: Polling for settings changes every 10 ticks (20s)
        if (timer.tick % 10 == 0) {
          _loadSettings();
        }

      } catch (e) {
        // Only trigger disconnect state if multiple consecutive failures occur
        if (mounted && timer.tick > 5) {
           setState(() => _isSystemActive = false);
        }
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final s = await _bridge.getSettings();
      if (mounted) setState(() => _settings = s);
    } catch (_) {}
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      final success = await _bridge.saveSettings({key: value});
      if (success) {
        _loadSettings();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update system setting.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Setting Update Error: $e")));
    }
  }

  Future<void> _optimizeSystem() async {
    if (_isOptimizing) return;
    setState(() => _isOptimizing = true);
    try {
      await _bridge.optimizeSystem();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System Optimization Complete.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Optimization Failed: $e")));
    } finally {
      if (mounted) setState(() => _isOptimizing = false);
    }
  }

  Future<void> _refreshCode() async {
    try {
      final newCode = await _bridge.refreshConnectCode();
      if (mounted) {
        setState(() => _pairingCode = newCode);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pairing code rotated successfully.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to refresh code.")));
    }
  }

  Future<void> _addSharedFolder() async {
    try {
      String? result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        final currentPaths = _sharedFolders.map((f) => f['path'] as String).toList();
        if (!currentPaths.contains(result)) {
          currentPaths.add(result);
          final success = await _bridge.saveSettings({"shared_folders": currentPaths});
          if (success) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New folder shared.")));
            // Sync will pick it up naturally
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("File Picker Error: $e")));
    }
  }

  Future<void> _removeSharedFolder(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: const Text("Remove Shared Folder?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Stop sharing access to: $path", style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white24))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("REMOVE ACCESS"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final currentPaths = _sharedFolders.map((f) => f['path'] as String).toList();
      currentPaths.remove(path);
      final success = await _bridge.saveSettings({"shared_folders": currentPaths});
      if (success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Folder unshared.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error removing folder: $e")));
    }
  }

  Future<void> _revokeGuestSession(String token) async {
    try {
      final success = await _bridge.endGuestSession(token);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guest Access Revoked")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Revoke Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          _buildSidebar(accent, isDark, theme),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(accent, isDark),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _isSystemActive
                        ? IndexedStack(
                            key: const ValueKey("active_stack"),
                            index: _getTabIndex(_activeTab),
                            children: [
                              HomeTab(pairingCode: _pairingCode, devices: _devices, stats: _stats, isDark: isDark, accent: accent, onRefreshCode: _refreshCode),
                              TransfersTab(activeTransfers: _activeTransfers, activityLog: _activityLog, isDark: isDark, accent: accent),
                              HealthTab(stats: _stats, isDark: isDark, waveAnimation: _waveController, accent: accent, onOptimize: _optimizeSystem, isOptimizing: _isOptimizing),
                              FilesTab(
                                isDark: isDark,
                                accent: accent,
                                sharedFolders: _sharedFolders,
                                onAddFolder: _addSharedFolder,
                                onRemoveFolder: _removeSharedFolder,
                              ),
                              SecurityTab(isDark: isDark, accent: accent, sessions: _securitySessions, pcIp: _pcIp, onRevokeSession: _revokeGuestSession),
                              ActivityTab(isDark: isDark, accent: accent, logs: _activityLog),
                              SettingsTab(
                                  settings: _settings,
                                  isDark: isDark,
                                  accent: accent,
                                  themeService: theme,
                                  onUpdateSetting: _updateSetting),
                            ],
                          )
                        : _buildConnectionLostState(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getTabIndex(String tab) {
    switch (tab) {
      case "Home": return 0;
      case "Transfers": return 1;
      case "System Health": return 2;
      case "Shared Files": return 3;
      case "Security": return 4;
      case "Activity Log": return 5;
      case "Settings": return 6;
      default: return 0;
    }
  }

  Widget _buildSidebar(Color accent, bool isDark, ThemeService theme) {
    return Container(
      width: 260,
      color: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFE5E5EA),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.shield_moon_outlined, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Text("CYPHER",
                    style: GoogleFonts.roboto(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -1)),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _navItem("Home", Icons.home_filled, accent, isDark),
          _navItem("Transfers", Icons.sync_alt_rounded, accent, isDark),
          _navItem("System Health", Icons.analytics_rounded, accent, isDark),
          _navItem("Shared Files", Icons.folder_shared_rounded, accent, isDark),
          _navItem("Security", Icons.shield_rounded, accent, isDark),
          _navItem("Activity Log", Icons.list_alt_rounded, accent, isDark),
          const Spacer(),
          // Live System Status
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: _isSystemActive ? const Color(0xFF10B981) : Colors.amber.withOpacity(0.5),
                        shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Text(_isSystemActive ? "System Secure" : "Linking...",
                    style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white24 : Colors.black38)),
              ],
            ),
          ),
          _buildThemeToggle(theme, isDark, accent),
          const Divider(color: Colors.white10),
          _navItem("Settings", Icons.settings_rounded, accent, isDark),
        ],
      ),
    );
  }

  Widget _navItem(String title, IconData icon, Color accent, bool isDark) {
    bool active = _activeTab == title;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? accent : (isDark ? Colors.white30 : Colors.black26), size: 20),
            const SizedBox(width: 16),
            Text(title,
                style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white38 : Colors.black45))),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent, bool isDark) {
    return Container(
      height: 48,
      color: isDark ? const Color(0xFF08080A) : const Color(0xFFF2F2F7),
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("CYPHER", style: GoogleFonts.roboto(fontSize: 10, color: isDark ? Colors.white12 : Colors.black12)),
                Icon(Icons.chevron_right_rounded, size: 14, color: isDark ? Colors.white10 : Colors.black12),
                Flexible(
                  child: Text(_activeTab.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(fontSize: 10, color: accent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _windowBtn(Icons.remove_rounded, () => windowManager.minimize(), isDark),
              _windowBtn(Icons.check_box_outline_blank_rounded, () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              }, isDark),
              _windowBtn(Icons.close_rounded, () => windowManager.close(), isDark, isClose: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _windowBtn(IconData icon, VoidCallback tap, bool isDark, {bool isClose = false}) {
    return GestureDetector(
      onTap: tap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 48,
          height: 48,
          color: Colors.transparent,
          child: Icon(icon,
              size: 16, color: isClose ? Colors.redAccent.withOpacity(0.5) : (isDark ? Colors.white24 : Colors.black26)),
        ),
      ),
    );
  }

  Widget _buildConnectionLostState(Color accent) {
    return Container(
      color: const Color(0xFF08080A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.1), width: 1),
                ),
                child: Icon(Icons.shield_moon_outlined, color: accent, size: 64),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              "CONNECTION LOST",
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "CHECK IF MOBILE APP IS RUNNING ON THE SAME NETWORK",
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 10,
                color: Colors.white24,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 280,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.03),
                      valueColor: AlwaysStoppedAnimation(accent),
                      minHeight: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() => _isSystemActive = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("RETRY CONNECTION", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(ThemeService theme, bool isDark, Color accent) {
    return GestureDetector(
      onTap: theme.toggleTheme,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: accent.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: accent, size: 18),
            const SizedBox(width: 12),
            Text(isDark ? "Light Mode" : "Dark Mode",
                style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
          ],
        ),
      ),
    );
  }
}
