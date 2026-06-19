import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../services/update_service.dart';
import '../widgets/cypher_button.dart';
import '../widgets/cypher_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hapticEnabled = true;
  bool _batteryAlertEnabled = false;
  double _batteryThreshold = 20;
  UpdateResult? _updateResult;
  bool _isCheckingUpdate = false;
  bool _updateCheckFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _checkForUpdate();
    });
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final ip = context.read<ConnectionProvider>().ip ?? '';
    try {
      final data = await ApiService.getSettings(ip);
      if (mounted) {
        setState(() {
          _settings          = data;
          _batteryThreshold  = (data['battery_alert_threshold'] ?? 20).toDouble();
          _batteryAlertEnabled = data['battery_alert_enabled'] ?? false;
          _isLoading         = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final ip = context.read<ConnectionProvider>().ip ?? '';
    try {
      await ApiService.updateSettings(ip, {
        ..._settings,
        'battery_alert_threshold': _batteryThreshold.toInt(),
        'battery_alert_enabled': _batteryAlertEnabled,
      });
      _toast('Settings saved');
    } catch (_) {
      _toast('Could not save — check connection', err: true);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _forgetPC() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Forget this PC?'),
        content: const Text('You will need to re-pair to connect again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget', style: TextStyle(color: CypherColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await StorageService.clearPairing();
      context.read<ConnectionProvider>().disconnect();
      Navigator.pushNamedAndRemoveUntil(context, '/connection', (_) => false);
    }
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    setState(() { _isCheckingUpdate = true; _updateCheckFailed = false; });
    final result = await UpdateService.check();
    if (!mounted) return;
    setState(() {
      _updateResult = result;
      _isCheckingUpdate = false;
      _updateCheckFailed = result == null && !_isCheckingUpdate;
    });
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? CypherColors.error : CypherColors.accent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: CypherColors.accent))
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              const CypherSectionHeader(title: 'Connection'),
              const SizedBox(height: 8),
              CypherCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow('PC Address', cp.ip ?? '—'),
                    const SizedBox(height: 8),
                    _InfoRow('PC Name', cp.pcName ?? '—'),
                    const SizedBox(height: 8),
                    _InfoRow('Status', cp.isConnected ? 'Connected' : 'Disconnected'),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const CypherSectionHeader(title: 'Auto-Connect'),
              const SizedBox(height: 8),
              CypherCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _ToggleRow(
                  label: 'Smart Auto-Connect',
                  desc: 'Automatically reconnect to your PC when on home WiFi',
                  value: cp.autoConnectEnabled,
                  onChanged: (v) => cp.setAutoConnect(v),
                ),
              ),

              const SizedBox(height: 20),
              const CypherSectionHeader(title: 'Alerts'),
              const SizedBox(height: 8),
              CypherCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _ToggleRow(
                      label: 'Battery alert',
                      desc: 'Notify when PC battery is low',
                      value: _batteryAlertEnabled,
                      onChanged: (v) { HapticFeedback.lightImpact(); setState(() => _batteryAlertEnabled = v); },
                    ),
                    if (_batteryAlertEnabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _batteryThreshold,
                                min: 5, max: 50, divisions: 9,
                                onChanged: (v) => setState(() => _batteryThreshold = v),
                              ),
                            ),
                            Text('${_batteryThreshold.toInt()}%', style: AppTheme.caption(context)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const CypherSectionHeader(title: 'Preferences'),
              const SizedBox(height: 8),
              CypherCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _ToggleRow(
                  label: 'Haptic feedback',
                  desc: 'Vibrate on actions',
                  value: _hapticEnabled,
                  onChanged: (v) => setState(() => _hapticEnabled = v),
                ),
              ),

              const SizedBox(height: 20),
              const CypherSectionHeader(title: 'About'),
              const SizedBox(height: 8),
              CypherCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow('Version', UpdateService.currentVersion),
                    const SizedBox(height: 8),
                    const _InfoRow('Mode', '100% Local Network'),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Updates', style: AppTheme.body(context)),
                        if (_isCheckingUpdate)
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: CypherColors.accent),
                          )
                        else if (_updateResult != null)
                          GestureDetector(
                            onTap: () => UpdateService.openReleasePage(_updateResult!.downloadUrl),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: CypherColors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${_updateResult!.latestVersion} available',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Text(
                                _updateCheckFailed ? 'Check failed' : 'Up to date',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _updateCheckFailed ? CypherColors.textMuted : CypherColors.success,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _checkForUpdate,
                                child: const Icon(Icons.refresh_rounded, size: 16, color: CypherColors.textMuted),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const CypherSectionHeader(title: 'Danger Zone'),
              const SizedBox(height: 8),
              CypherCard(
                onTap: _forgetPC,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: const Row(
                  children: [
                    Icon(Icons.link_off_rounded, color: CypherColors.error, size: 18),
                    SizedBox(width: 12),
                    Text('Forget this PC & re-pair', style: TextStyle(color: CypherColors.error, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              CypherButton(label: 'Save Settings', onTap: _saveSettings, loading: _isSaving),
            ],
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.body(context)),
        Text(value, style: const TextStyle(fontSize: 13, color: CypherColors.textSecondary)),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.desc, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: CypherColors.textPrimary)),
                Text(desc, style: AppTheme.caption(context)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
