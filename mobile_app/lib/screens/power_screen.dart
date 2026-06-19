import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/system_provider.dart';
import '../theme/colors.dart';

class PowerScreen extends StatefulWidget {
  const PowerScreen({super.key});

  @override
  State<PowerScreen> createState() => _PowerScreenState();
}

class _PowerScreenState extends State<PowerScreen> {
  bool _loading = false;
  String? _loadingAction;

  String get _ip => context.read<ConnectionProvider>().ip ?? '';

  Future<void> _confirm(String title, String body, Color color, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CypherColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: CypherColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(body, style: const TextStyle(color: CypherColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: CypherColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: Text('Confirm', style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() { _loading = true; _loadingAction = title; });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Command failed — check PC connection'), backgroundColor: CypherColors.error),
        );
      }
    }
    if (mounted) setState(() { _loading = false; _loadingAction = null; });
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.read<SystemProvider>();

    return Scaffold(
      backgroundColor: CypherColors.bgDeep,
      appBar: AppBar(
        backgroundColor: CypherColors.bgDeep,
        title: const Text('Power'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          const Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CypherColors.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          _PowerTile(
            icon: Icons.lock_rounded,
            label: 'Lock Screen',
            subtitle: 'Lock your PC immediately',
            color: CypherColors.accent,
            loading: _loading && _loadingAction == 'Lock Screen',
            onTap: () async {
              setState(() { _loading = true; _loadingAction = 'Lock Screen'; });
              try { await sp.lock(_ip); } catch (_) {}
              if (mounted) setState(() { _loading = false; _loadingAction = null; });
            },
          ),
          const SizedBox(height: 8),
          _PowerTile(
            icon: Icons.bedtime_rounded,
            label: 'Sleep',
            subtitle: 'Put your PC to sleep',
            color: CypherColors.info,
            loading: _loading && _loadingAction == 'Sleep',
            onTap: () => _confirm(
              'Sleep',
              'Put your PC to sleep now?',
              CypherColors.info,
              () => sp.sleep(_ip),
            ),
          ),
          const SizedBox(height: 8),
          _PowerTile(
            icon: Icons.restart_alt_rounded,
            label: 'Restart',
            subtitle: 'Restart your PC',
            color: CypherColors.warning,
            loading: _loading && _loadingAction == 'Restart',
            onTap: () => _confirm(
              'Restart',
              'Your PC will restart. Unsaved work may be lost.',
              CypherColors.warning,
              () => sp.restart(_ip),
            ),
          ),
          const SizedBox(height: 8),
          _PowerTile(
            icon: Icons.power_settings_new_rounded,
            label: 'Shutdown',
            subtitle: 'Turn off your PC',
            color: CypherColors.error,
            loading: _loading && _loadingAction == 'Shutdown',
            onTap: () => _confirm(
              'Shutdown',
              'Your PC will shut down. Unsaved work may be lost.',
              CypherColors.error,
              () => sp.shutdown(_ip),
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _PowerTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_PowerTile> createState() => _PowerTileState();
}

class _PowerTileState extends State<_PowerTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); if (!widget.loading) widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _pressed ? CypherColors.bgHover : CypherColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CypherColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 20, color: widget.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CypherColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(widget.subtitle, style: const TextStyle(fontSize: 12, color: CypherColors.textMuted)),
                ],
              ),
            ),
            if (widget.loading)
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: widget.color, strokeWidth: 2))
            else
              Icon(Icons.chevron_right_rounded, size: 18, color: widget.color),
          ],
        ),
      ),
    );
  }
}
