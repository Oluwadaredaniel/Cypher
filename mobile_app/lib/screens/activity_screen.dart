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

  String _getCategory(Map item) {
    final category = item['category']?.toString().toLowerCase() ?? 'other';
    if (category.contains('file') || category == 'transfers') return 'Files';
    if (category.contains('command') || category.contains('control') || category.contains('media')) return 'Controls';
    if (category.contains('connection') || category.contains('security') || category.contains('pairing')) return 'Connections';
    return 'Other';
  }

  String _filterCategory(Map item) {
    return _getCategory(item);
  }

  String _formatTimestamp(Map item) {
    try {
      final date = item['date']?.toString() ?? '';
      final time = item['time']?.toString() ?? '';
      return '$date at $time';
    } catch (_) {
      return 'Just now';
    }
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
                        final title = item['title']?.toString() ?? 'Action';
                        final desc = item['desc']?.toString() ?? '';
                        final ts = _formatTimestamp(item);
                        final isUrgent = item['is_urgent'] as bool? ?? false;

                        return CypherCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: isUrgent ? CypherColors.error : CypherColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CypherColors.textPrimary)),
                                    if (desc.isNotEmpty)
                                      Text(desc, style: const TextStyle(fontSize: 12, color: CypherColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(ts, style: AppTheme.caption(context)),
                                  ],
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
