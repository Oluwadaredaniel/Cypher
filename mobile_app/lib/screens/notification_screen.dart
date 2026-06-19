import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/system_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_card.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'System', 'Files', 'Guest'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ip = context.read<ConnectionProvider>().ip ?? '';
      if (ip.isNotEmpty) context.read<SystemProvider>().fetchNotifications(ip);
    });
  }

  List _getFiltered(List raw) {
    if (_activeFilter == 'All') return raw;
    return raw.where((n) {
      final app = n['app_name']?.toString().toLowerCase() ?? '';
      final f   = _activeFilter.toLowerCase();
      if (f == 'files')  return app.contains('file') || app.contains('explorer');
      if (f == 'system') return app.contains('system') || app.contains('battery') || app.contains('windows');
      if (f == 'guest')  return app.contains('guest') || app.contains('user');
      return false;
    }).toList();
  }

  IconData _iconFor(String app) {
    final n = app.toLowerCase();
    if (n.contains('system') || n.contains('battery') || n.contains('power')) return Icons.bolt_rounded;
    if (n.contains('file') || n.contains('explorer') || n.contains('download')) return Icons.description_rounded;
    if (n.contains('guest') || n.contains('user') || n.contains('security')) return Icons.shield_outlined;
    if (n.contains('spotify') || n.contains('media')) return Icons.play_circle_fill_rounded;
    return Icons.notifications_active_rounded;
  }

  Color _colorFor(String app) {
    final n = app.toLowerCase();
    if (n.contains('system') || n.contains('battery')) return CypherColors.warning;
    if (n.contains('file') || n.contains('explorer'))  return CypherColors.accent;
    if (n.contains('guest') || n.contains('security')) return CypherColors.info;
    if (n.contains('spotify') || n.contains('media'))  return CypherColors.success;
    return CypherColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final sp       = context.watch<SystemProvider>();
    final ip       = context.read<ConnectionProvider>().ip ?? '';
    final filtered = _getFiltered(sp.notifications);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (sp.notifications.isNotEmpty)
            TextButton(
              onPressed: () { setState(() => sp.notifications.clear()); },
              child: const Text('Clear all', style: TextStyle(color: CypherColors.accentLight)),
            ),
        ],
      ),
      body: Column(
        children: [
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
              onRefresh: () async => context.read<SystemProvider>().fetchNotifications(ip),
              child: sp.isLoading
                ? const Center(child: CircularProgressIndicator(color: CypherColors.accent))
                : filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 100),
                        const Icon(Icons.notifications_none_rounded, color: CypherColors.textMuted, size: 40),
                        const SizedBox(height: 12),
                        const Center(child: Text('No notifications', style: TextStyle(color: CypherColors.textMuted, fontSize: 15))),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            _activeFilter == 'All'
                              ? 'PC notifications will appear here'
                              : "None in '$_activeFilter'",
                            style: AppTheme.caption(context),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final item  = filtered[i] as Map;
                        final app   = item['app_name']?.toString() ?? 'Alert';
                        final color = _colorFor(app);

                        return Dismissible(
                          key: Key(item['id']?.toString() ?? '$i'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: CypherColors.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_sweep_rounded, color: CypherColors.error),
                          ),
                          onDismissed: (_) {
                            final removed = filtered[i];
                            setState(() => sp.notifications.remove(removed));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Notification dismissed'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => setState(() => sp.notifications.insert(i, removed)),
                              ),
                            ));
                          },
                          child: CypherCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_iconFor(app), color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(app.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 1)),
                                          Text(item['timestamp']?.toString().substring(0, 5) ?? '', style: AppTheme.caption(context)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(item['title']?.toString() ?? 'Notification', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CypherColors.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(item['message']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(context)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
