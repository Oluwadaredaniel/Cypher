import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/glass_container.dart';
import '../../services/theme_service.dart';

class SettingsTab extends StatelessWidget {
  final Map<String, dynamic> settings;
  final bool isDark;
  final Color accent;
  final ThemeService themeService;
  final Function(String, dynamic) onUpdateSetting;

  const SettingsTab({
    super.key,
    required this.settings,
    required this.isDark,
    required this.accent,
    required this.themeService,
    required this.onUpdateSetting,
  });

  @override
  Widget build(BuildContext context) {
    final pcNameController = TextEditingController(text: settings['device_name'] ?? "WORKSYSTEM-01");
    final portController = TextEditingController(text: (settings['server_port'] ?? 5000).toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("System Preferences", "Configure your security and behavior."),
          const SizedBox(height: 32),
          _buildBentoSection(
            icon: Icons.computer_rounded,
            title: "General Identity",
            sub: "Configure how this PC appears on the network.",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PC NAME", style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: pcNameController,
                  onSubmitted: (v) => onUpdateSetting('device_name', v),
                  style: GoogleFonts.roboto(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildBentoSection(
                  icon: Icons.power_settings_new_rounded,
                  title: "Startup Behavior",
                  sub: "Background services.",
                  child: _settingsToggle(
                      "Launch on Start",
                      settings['launch_on_startup'] ?? true,
                      (v) => onUpdateSetting('launch_on_startup', v)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBentoSection(
                  icon: Icons.dark_mode_rounded,
                  title: "Appearance",
                  sub: "UI theme elements.",
                  child: _settingsToggle(
                      "Night Protocol",
                      themeService.isDarkMode,
                      (v) => themeService.toggleTheme()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildBentoSection(
            icon: Icons.router_rounded,
            title: "Network Connectivity",
            sub: "Manage visibility on your local network.",
            child: Row(
              children: [
                Expanded(
                  child: _settingsToggle(
                      "Discovery Mode",
                      settings['ip_discovery'] ?? true,
                      (v) => onUpdateSetting('ip_discovery', v),
                      desc: "Allow other devices to find this SYSTEM"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text("LIVE CONNECTION", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        Text(sub, style: GoogleFonts.roboto(fontSize: 14, color: isDark ? Colors.white24 : Colors.black38)),
      ],
    );
  }

  Widget _buildBentoSection({required IconData icon, required String title, required String sub, required Widget child}) {
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  Text(sub, style: GoogleFonts.roboto(fontSize: 12, color: isDark ? Colors.white24 : Colors.black38)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _settingsToggle(String title, bool val, Function(bool) tap, {String? desc}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
              if (desc != null)
                Text(desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(fontSize: 11, color: isDark ? Colors.white24 : Colors.black38)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(value: val, onChanged: tap, activeColor: accent),
      ],
    );
  }
}
