import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/system_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_card.dart';
import '../widgets/shimmer_box.dart';

class ProcessManagerScreen extends StatefulWidget {
  const ProcessManagerScreen({super.key});

  @override
  State<ProcessManagerScreen> createState() => _ProcessManagerScreenState();
}

class _ProcessManagerScreenState extends State<ProcessManagerScreen> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ip = context.read<ConnectionProvider>().ip ?? '';
      if (ip.isNotEmpty) {
        context.read<SystemProvider>().fetchProcesses(ip);
        _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          if (mounted && _searchQuery.isEmpty) context.read<SystemProvider>().fetchProcesses(ip);
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List _filtered(List processes) {
    if (_searchQuery.isEmpty) return processes;
    final q = _searchQuery.toLowerCase();
    return processes.where((p) =>
      (p['name']?.toString().toLowerCase() ?? '').contains(q) ||
      (p['pid']?.toString() ?? '').contains(q)
    ).toList();
  }

  Future<void> _killProcess(Map p) async {
    HapticFeedback.heavyImpact();
    final name = p['name']?.toString() ?? 'Unknown';
    final pid  = p['pid'] as int;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kill Process?'),
        content: Text('Terminate $name (PID $pid)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Task', style: TextStyle(color: CypherColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ip = context.read<ConnectionProvider>().ip ?? '';
      final ok = await context.read<SystemProvider>().killProcess(ip, pid);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Process terminated' : 'Failed (Access Denied)'),
        backgroundColor: ok ? CypherColors.accent : CypherColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp       = context.watch<SystemProvider>();
    final ip       = context.read<ConnectionProvider>().ip ?? '';
    final list     = _filtered(sp.processes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => sp.fetchProcesses(ip),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search processes...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sp.isLoading
              ? const ShimmerList(count: 10)
              : list.isEmpty
                ? const Center(child: Text('No processes found', style: TextStyle(color: CypherColors.textMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final p   = list[i] as Map;
                      final cpu = (p['cpu_percent'] ?? 0.0).toDouble();
                      final mem = (p['memory_mb']   ?? 0.0).toDouble();
                      final name = p['name']?.toString() ?? '?';

                      return CypherCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: CypherColors.bgOverlay,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: CypherColors.accentLight, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CypherColors.textPrimary), overflow: TextOverflow.ellipsis),
                                  Text('PID ${p['pid']}  •  ${mem.toStringAsFixed(1)} MB', style: AppTheme.caption(context)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${cpu.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: cpu > 20 ? CypherColors.error : cpu > 5 ? CypherColors.warning : CypherColors.success,
                                  ),
                                ),
                                const Text('CPU', style: TextStyle(fontSize: 9, color: CypherColors.textMuted)),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: CypherColors.error, size: 18),
                              onPressed: () => _killProcess(p),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
