import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/system_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_card.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'Files', 'Controls', 'Connections'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ip = context.read<ConnectionProvider>().ip ?? '';
      if (ip.isNotEmpty) context.read<SystemProvider>().fetchActivity(ip);
    });
  }

  String _translateAction(String endpoint) {
    if (endpoint.contains('/files/browse'))    return 'Browsed files';
    if (endpoint.contains('/files/download'))  return 'Downloaded a file';
    if (endpoint.contains('/files/upload'))    return 'Sent a file to PC';
    if (endpoint.contains('/files/delete'))    return 'Deleted a file';
    if (endpoint.contains('/power/shutdown'))  return 'Shut down PC';
    if (endpoint.contains('/power/restart'))   return 'Restarted PC';
    if (endpoint.contains('/power/sleep'))     return 'Put PC to sleep';
    if (endpoint.contains('/power/lock'))      return 'Locked PC';
    if (endpoint.contains('/screenshot'))      return 'Took a screenshot';
    if (endpoint.contains('/clipboard'))       return 'Used clipboard';
    if (endpoint.contains('/media'))           return 'Controlled media';
    if (endpoint.contains('/type'))            return 'Typed on PC';
    if (endpoint.contains('/apps/launch'))     return 'Opened an app';
    return 'Performed an action';
  }

  String _filterCategory(Map item) {
    final ep = item['endpoint']?.toString() ?? '';
    if (ep.contains('/files')) return 'Files';
    if (ep.contains('/power') || ep.contains('/media') || ep.contains('/screenshot') || ep.contains('/type') || ep.contains('/clipboard')) return 'Controls';
    if (ep.contains('/pair') || ep.contains('/events') || item['type'] == 'event') return 'Connections';
    return 'Other';
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final today     = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final itemDay   = DateTime(dt.year, dt.month, dt.day);
      final timeStr   = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      if (itemDay == today)     return 'Today at $timeStr';
      if (itemDay == yesterday) return 'Yesterday at $timeStr';
      return '${dt.day}/${dt.month} at $timeStr';
    } catch (_) { return ts; }
  }

  List<Map> _getFiltered(List rawList) {
    final items = rawList.cast<Map>();
    if (_activeFilter == 'All') return items;
    return items.where((i) => _filterCategory(i) == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sp  = context.watch<SystemProvider>();
    final ip  = context.read<ConnectionProvider>().ip ?? '';
    final filtered = _getFiltered(sp.activity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          if (sp.activity.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => sp.activity.clear()),
              child: const Text('Clear', style: TextStyle(color: CypherColors.textMuted)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final active = _activeFilter == f;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activeFilter = f);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: active ? CypherColors.accent : CypherColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? CypherColors.accent : CypherColors.border),
                    ),
                    child: Center(
                      child: Text(f, style: TextStyle(
                        fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? Colors.white : CypherColors.textSecondary,
                      )),
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: CypherColors.accent,
              onRefresh: () async => context.read<SystemProvider>().fetchActivity(ip),
              child: sp.isLoading
                ? const Center(child: CircularProgressIndicator(color: CypherColors.accent))
                : filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        const Icon(Icons.history_toggle_off_rounded, color: CypherColors.textMuted, size: 40),
                        const SizedBox(height: 12),
                        const Center(child: Text('No activity yet', style: TextStyle(color: CypherColors.textMuted, fontSize: 15))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        final action = item['details']?.toString().isNotEmpty == true
                            ? item['details'].toString()
                            : _translateAction(item['endpoint']?.toString() ?? '');
                        final success = item['success'] as bool? ?? true;
                        final ts = _formatTimestamp(item['timestamp']?.toString() ?? '');

                        return CypherCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: success ? CypherColors.success : CypherColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(action, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CypherColors.textPrimary)),
                                    Text(ts, style: AppTheme.caption(context)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (success ? CypherColors.success : CypherColors.error).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  success ? 'Done' : 'Failed',
                                  style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w600,
                                    color: success ? CypherColors.success : CypherColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
