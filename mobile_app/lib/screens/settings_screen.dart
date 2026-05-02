import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  const SettingsScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hapticEnabled = true;
  bool _batteryAlertEnabled = false;
  bool _connectionAlertsEnabled = true;
  double _batteryThreshold = 20;

  String get _baseUrl => 'http://${widget.pcIpAddress}:5000';
  Map<String, String> get _headers => {
    'X-Auth-Token': widget.authToken,
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/settings'), headers: _headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body);
        setState(() {
          _settings = data;
          _batteryThreshold = (data['battery_alert_threshold'] ?? 20).toDouble();
          _batteryAlertEnabled = data['battery_alert_enabled'] ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await http.post(
        Uri.parse('$_baseUrl/settings'),
        headers: _headers,
        body: jsonEncode({
          ..._settings,
          'battery_alert_threshold': _batteryThreshold.toInt(),
          'battery_alert_enabled': _batteryAlertEnabled,
        }),
      ).timeout(const Duration(seconds: 8));
      _showToast('Settings saved ✓');
    } catch (_) {
      _showToast('Could not save. Check connection.', success: false);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _forgetPC() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text('Forget this PC?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Text('You will need to enter the PC address and connect code again.', style: GoogleFonts.outfit(color: const Color(0xFF86868B))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF86868B)))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Forget', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    ));
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SetupScreen()), (_) => false);
    }
  }

  void _showToast(String msg, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
      backgroundColor: success ? const Color(0xFF6C63FF) : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildSection(String title) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 10),
    child: Text(title, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
  );

  Widget _buildRow(String label, String? value, {VoidCallback? onTap, bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(color: danger ? Colors.redAccent : Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            if (value != null) Text(value, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
            if (onTap != null && value == null) const Icon(Icons.arrow_forward_ios, color: Color(0xFF444444), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(String label, String desc, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              Text(desc, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
            ],
          )),
          Switch(value: value, onChanged: (v) { if (_hapticEnabled) HapticFeedback.lightImpact(); onChanged(v); }, activeColor: const Color(0xFF6C63FF)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
        : ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            FadeInUp(duration: const Duration(milliseconds: 300), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('YOUR CONNECTION'),
                _buildRow('PC Address', widget.pcIpAddress),
                _buildRow('PC Name', _settings['device_name'] ?? 'My PC'),
                _buildSection('ALERTS'),
                _buildToggleRow('Battery alert', 'Get notified when PC battery is low', _batteryAlertEnabled, (v) => setState(() => _batteryAlertEnabled = v)),
                if (_batteryAlertEnabled) Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alert when battery reaches ${_batteryThreshold.toInt()}%', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
                      Slider(value: _batteryThreshold, min: 5, max: 50, divisions: 9, activeColor: const Color(0xFF6C63FF),
                        onChanged: (v) => setState(() => _batteryThreshold = v)),
                    ],
                  ),
                ),
                _buildToggleRow('Connection alerts', 'Notify when PC connects or disconnects', _connectionAlertsEnabled, (v) => setState(() => _connectionAlertsEnabled = v)),
                _buildSection('APPEARANCE'),
                _buildToggleRow('Haptic feedback', 'Vibrate on actions', _hapticEnabled, (v) => setState(() => _hapticEnabled = v)),
                _buildSection('ABOUT CYPHER'),
                _buildRow('Version', '1.0.0'),
                _buildSection('DANGER ZONE'),
                _buildRow('Forget this PC', null, onTap: _forgetPC, danger: true),
              ],
            )),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _saveSettings,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(100)),
                child: Center(child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Changes', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              ),
            ),
          ],
        ),
    );
  }
}
