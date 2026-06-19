import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/theme_service.dart';
import '../../services/update_service.dart';
import '../../widgets/glass_container.dart';

class SettingsTab extends StatefulWidget {
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
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late TextEditingController _pcNameController;
  late int _batteryThreshold;
  bool _isLoading = false;
  UpdateResult? _updateResult;
  bool _isCheckingUpdate = false;
  bool _updateCheckFailed = false;

  @override
  void initState() {
    super.initState();
    _pcNameController = TextEditingController(
      text: widget.settings['device_name'] ?? "WORKSYSTEM-01",
    );
    _batteryThreshold = widget.settings['battery_alert_threshold'] ?? 20;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    setState(() { _isCheckingUpdate = true; _updateCheckFailed = false; });
    final result = await UpdateService.check();
    if (!mounted) return;
    setState(() {
      _updateResult = result;
      _isCheckingUpdate = false;
      _updateCheckFailed = result == null;
    });
  }

  @override
  void didUpdateWidget(SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller if the setting changed externally and we aren't typing
    if (widget.settings['device_name'] != oldWidget.settings['device_name'] &&
        widget.settings['device_name'] != _pcNameController.text) {
      _pcNameController.text = widget.settings['device_name'] ?? "";
    }
    if (widget.settings['battery_alert_threshold'] != oldWidget.settings['battery_alert_threshold']) {
      _batteryThreshold = widget.settings['battery_alert_threshold'] ?? 20;
    }
  }

  @override
  void dispose() {
    _pcNameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _isLoading = true);
    await widget.onUpdateSetting('device_name', _pcNameController.text);
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PC name updated successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text("PC NAME", style: GoogleFonts.inter(fontSize: 9, color: widget.isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pcNameController,
                        style: GoogleFonts.inter(color: widget.isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          hintText: "Enter PC Name",
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildBentoSection(
            icon: Icons.battery_alert_rounded,
            title: "Battery Alerts",
            sub: "Threshold for mobile notifications.",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ALERT AT $_batteryThreshold%", style: GoogleFonts.inter(fontSize: 9, color: widget.isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold)),
                    Text("Range: 10% - 50%", style: GoogleFonts.inter(fontSize: 9, color: widget.isDark ? Colors.white24 : Colors.black26)),
                  ],
                ),
                Slider(
                  value: _batteryThreshold.toDouble(),
                  min: 10, max: 50,
                  divisions: 8,
                  activeColor: widget.accent,
                  onChanged: (v) => setState(() => _batteryThreshold = v.toInt()),
                  onChangeEnd: (v) => widget.onUpdateSetting('battery_alert_threshold', v.toInt()),
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
                  title: "Startup",
                  sub: "Auto-launch.",
                  child: _settingsToggle(
                    "Launch on Start",
                    widget.settings['launch_on_startup'] ?? true,
                    (v) => widget.onUpdateSetting('launch_on_startup', v)
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBentoSection(
                  icon: Icons.dark_mode_rounded,
                  title: "Theme",
                  sub: "UI Appearance.",
                  child: _settingsToggle(
                    "Night Protocol",
                    widget.themeService.isDarkMode,
                    (v) => widget.themeService.toggleTheme()
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildBentoSection(
            icon: Icons.info_outline_rounded,
            title: "About CYPHER",
            sub: "Version & update info.",
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Current Version", style: GoogleFonts.inter(fontSize: 13, color: widget.isDark ? Colors.white38 : Colors.black45)),
                    Text("v${UpdateService.currentVersion}", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Updates", style: GoogleFonts.inter(fontSize: 13, color: widget.isDark ? Colors.white38 : Colors.black45)),
                    if (_isCheckingUpdate)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                    else if (_updateResult != null)
                      GestureDetector(
                        onTap: () => UpdateService.openReleasePage(_updateResult!.downloadUrl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(8)),
                          child: Text('v${_updateResult!.latestVersion} — Download', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            _updateCheckFailed ? 'Check failed' : 'Up to date',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _updateCheckFailed
                                ? (widget.isDark ? Colors.white24 : Colors.black26)
                                : const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _checkForUpdate,
                            child: Icon(Icons.refresh_rounded, size: 14, color: widget.isDark ? Colors.white24 : Colors.black26),
                          ),
                        ],
                      ),
                  ],
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
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF10B981), letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 6),
        Text(title, style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : Colors.black, height: 1.1)),
        Text(sub, style: GoogleFonts.inter(fontSize: 12, color: widget.isDark ? Colors.white30 : Colors.black38)),
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
              Icon(icon, color: widget.accent, size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
                  Text(sub, style: GoogleFonts.inter(fontSize: 12, color: widget.isDark ? Colors.white24 : Colors.black38)),
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

  Widget _settingsToggle(String title, bool val, Function(bool) tap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black)),
        Switch.adaptive(value: val, onChanged: tap, activeColor: widget.accent),
      ],
    );
  }
}
