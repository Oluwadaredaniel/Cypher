import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class SettingsScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const SettingsScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoClipboard = false;
  double _batteryAlert = 20;
  List<String> _availableFolders = [];

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
    _fetchFolders();
  }

  Future<void> _fetchFolders() async {
    try {
      final res = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/settings'),
        headers: {'X-Auth-Token': widget.authToken},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _availableFolders = List<String>.from(data['shared_folders'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoClipboard = prefs.getBool('auto_clipboard') ?? false;
      _batteryAlert = prefs.getDouble('battery_threshold') ?? 20;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  Future<void> _syncToPC() async {
    try {
      await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/settings'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'auto_clipboard_sync': _autoClipboard,
          'battery_alert_threshold': _batteryAlert.toInt(),
        }),
      );
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
                const SizedBox(height: 64),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDark),
                        const SizedBox(height: 32),
                        _buildCoreControls(theme, accent, isDark),
                        const SizedBox(height: 24),
                        _buildBatteryThreshold(accent, isDark),
                        const SizedBox(height: 24),
                        _buildSharedFolders(accent, isDark),
                        const SizedBox(height: 48),
                        _buildFooterActions(accent, isDark),
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
                Text("SETTINGS", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Icon(Icons.sensors_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("System Settings", style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 8),
        Text("Configure your system preferences.", style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
      ],
    );
  }

  Widget _buildCoreControls(ThemeService theme, Color accent, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _bentoToggle(
            "Night Mode",
            "UI Appearance",
            Icons.dark_mode_rounded,
            theme.isDarkMode,
            (v) => theme.toggleTheme(),
            accent,
            isDark
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _bentoToggle(
            "Auto-Sync",
            "Clipboard Sync",
            Icons.sync_rounded,
            _autoClipboard,
            (v) {
              setState(() => _autoClipboard = v);
              _savePreference('auto_clipboard', v);
              _syncToPC();
            },
            const Color(0xFFFFB786),
            isDark
          ),
        ),
      ],
    );
  }

  Widget _bentoToggle(String title, String sub, IconData icon, bool val, Function(bool) tap, Color color, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      height: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              Switch.adaptive(value: val, onChanged: tap, activeColor: color),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              Text(sub, style: GoogleFonts.roboto(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSharedFolders(Color accent, bool isDark) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_copy_rounded, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Text("Shared Locations", style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), height: 1),
          if (_availableFolders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text("No folders configured on PC.", style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.12))),
            )
          else
            ..._availableFolders.map((f) => ListTile(
              leading: Icon(Icons.folder_open_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), size: 18),
              title: Text(f.split('/').last.split('\\').last, style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
              subtitle: Text(f, style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
            )),
        ],
      ),
    );
  }

  Widget _buildBatteryThreshold(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("BATTERY ALERT", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text("${_batteryAlert.toInt()}%", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFFFB786))),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: const Color(0xFFFFB786),
              inactiveTrackColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              thumbColor: isDark ? Colors.white : const Color(0xFFFFB786),
              overlayColor: const Color(0xFFFFB786).withOpacity(0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _batteryAlert,
              min: 5, max: 50,
              onChanged: (v) {
                setState(() => _batteryAlert = v);
                _savePreference('battery_threshold', v);
              },
              onChangeEnd: (v) => _syncToPC(),
            ),
          ),
          const SizedBox(height: 8),
          Text("Notify when PC battery drops below this level.", style: GoogleFonts.roboto(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.12))),
        ],
      ),
    );
  }

  Widget _footerBtn(String label, Color color, VoidCallback tap, {bool outline = false, required bool isDark}) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(16),
          border: outline ? Border.all(color: color.withOpacity(0.2)) : null,
          boxShadow: !outline ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))] : null,
        ),
        child: Center(
          child: Text(label, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: outline ? color : Colors.white)),
        ),
      ),
    );
  }

  Widget _buildFooterActions(Color accent, bool isDark) {
    return Column(
      children: [
        _footerBtn("Disconnect & Factory Reset", Colors.redAccent, () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (mounted) Navigator.pushReplacementNamed(context, '/setup');
        }, outline: true, isDark: isDark),
      ],
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
          _navItem(Icons.tune_rounded, "Settings", true, null, isDark),
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
