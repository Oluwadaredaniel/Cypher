import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';
import '../widgets/cypher_card.dart';

class WakeOnLanScreen extends StatefulWidget {
  const WakeOnLanScreen({super.key});

  @override
  State<WakeOnLanScreen> createState() => _WakeOnLanScreenState();
}

class _WakeOnLanScreenState extends State<WakeOnLanScreen> {
  final _macCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  List<Map<String, String>> _savedMacs = [];
  bool _isWaking = false;

  @override
  void initState() {
    super.initState();
    _loadSavedMacs();
  }

  @override
  void dispose() {
    _macCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedMacs() async {
    try {
      final data = await StorageService.getJson('wol_devices');
      if (data is List) {
        setState(() {
          _savedMacs = List<Map<String, String>>.from(
            data.map((x) => Map<String, String>.from(x as Map))
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMac() async {
    final mac = _macCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (mac.isEmpty) {
      _toast('Enter MAC address', err: true);
      return;
    }

    if (!_isValidMac(mac)) {
      _toast('Invalid MAC format (XX:XX:XX:XX:XX:XX)', err: true);
      return;
    }

    setState(() {
      _savedMacs.add({'mac': mac, 'name': name.isEmpty ? mac : name});
    });

    await StorageService.saveJson('wol_devices', _savedMacs);
    _macCtrl.clear();
    _nameCtrl.clear();
    _toast('MAC saved');
  }

  Future<void> _wakeDevice(String mac, String name) async {
    HapticFeedback.heavyImpact();
    setState(() => _isWaking = true);

    try {
      final success = await ApiService.sendWol(
        context.read<ConnectionProvider>().ip ?? '',
        mac,
      );

      if (mounted) {
        _toast(
          success ? '$name waking up…' : 'Failed to send WOL packet',
          err: !success,
        );
      }
    } catch (_) {
      if (mounted) _toast('Error sending WOL packet', err: true);
    } finally {
      if (mounted) setState(() => _isWaking = false);
    }
  }

  Future<void> _deleteMac(int index) async {
    final name = _savedMacs[index]['name'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Device?'),
        content: Text('Remove $name from saved devices?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: CypherColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _savedMacs.removeAt(index));
      await StorageService.saveJson('wol_devices', _savedMacs);
      _toast('Device removed');
    }
  }

  bool _isValidMac(String mac) {
    final cleaned = mac.replaceAll(RegExp(r'[:\-.]'), '');
    return cleaned.length == 12 && RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(cleaned);
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? CypherColors.error : CypherColors.accent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wake on LAN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add New Device
            Text('Add Device', style: AppTheme.subtitle(context)),
            const SizedBox(height: 12),
            CypherCard(
              child: Column(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Device name (optional)',
                      prefixIcon: Icon(Icons.devices_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _macCtrl,
                    decoration: const InputDecoration(
                      hintText: 'MAC address (XX:XX:XX:XX:XX:XX)',
                      prefixIcon: Icon(Icons.router_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CypherButton(
                    label: 'Save Device',
                    onTap: _saveMac,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Saved Devices
            if (_savedMacs.isNotEmpty) ...[
              Text('Saved Devices (${_savedMacs.length})', style: AppTheme.subtitle(context)),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _savedMacs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final device = _savedMacs[i];
                  final name = device['name'] ?? 'Unknown';
                  final mac = device['mac'] ?? '';

                  return CypherCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: AppTheme.subtitle(context)),
                              const SizedBox(height: 4),
                              Text(mac, style: AppTheme.caption(context)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _isWaking ? null : () => _wakeDevice(mac, name),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: CypherColors.accentDim,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _isWaking
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: CypherColors.accent),
                                      )
                                    : const Icon(Icons.power_settings_new_rounded, size: 16, color: CypherColors.accent),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _deleteMac(i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: CypherColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.delete_rounded, size: 16, color: CypherColors.error),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text('No saved devices', style: AppTheme.body(context)),
                ),
              ),

            const SizedBox(height: 24),

            // Info Card
            CypherCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How it works', style: AppTheme.label(context)),
                  const SizedBox(height: 8),
                  Text(
                    '1. Get your PC\'s MAC address (Run: getmac /all)\n'
                    '2. Enable Wake-on-LAN in BIOS\n'
                    '3. Save the MAC here\n'
                    '4. Tap the power icon to wake your PC',
                    style: AppTheme.caption(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
