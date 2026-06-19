import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/api_service.dart';
import '../services/clipboard_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_card.dart';

class ClipboardHistoryScreen extends StatefulWidget {
  const ClipboardHistoryScreen({super.key});

  @override
  State<ClipboardHistoryScreen> createState() => _ClipboardHistoryScreenState();
}

class _ClipboardHistoryScreenState extends State<ClipboardHistoryScreen> {
  late Future<List<ClipboardEntry>> _historyFuture;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _historyFuture = ClipboardService.getHistory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ClipboardEntry> _filterHistory(List<ClipboardEntry> history) {
    if (_searchQuery.isEmpty) return history;
    final q = _searchQuery.toLowerCase();
    return history.where((e) => e.text.toLowerCase().contains(q)).toList();
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          backgroundColor: CypherColors.accent,
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _pasteToPC(String text) async {
    final ip = context.read<ConnectionProvider>().ip ?? '';
    try {
      await ApiService.pasteClipboard(ip, text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted to PC clipboard'),
            backgroundColor: CypherColors.accent,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to paste'),
            backgroundColor: CypherColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteEntry(ClipboardEntry entry) async {
    await ClipboardService.removeEntry(entry.text);
    setState(() {
      _historyFuture = ClipboardService.getHistory();
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All?'),
        content: const Text('This will delete all clipboard history permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: CypherColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ClipboardService.clearHistory();
      if (mounted) {
        setState(() {
          _historyFuture = ClipboardService.getHistory();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared'), backgroundColor: CypherColors.accent),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clipboard History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: FutureBuilder<List<ClipboardEntry>>(
        future: _historyFuture,
        builder: (_, snap) {
          final history = snap.data ?? [];
          final filtered = _filterHistory(history);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search history...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.content_paste_off_rounded, size: 48, color: CypherColors.textMuted),
                            const SizedBox(height: 16),
                            Text('No clipboard history', style: AppTheme.subtitle(context)),
                            const SizedBox(height: 8),
                            Text(
                              'Items you copy will appear here',
                              style: AppTheme.body(context),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final entry = filtered[i];
                          final preview = entry.text.length > 100
                              ? '${entry.text.substring(0, 100)}...'
                              : entry.text;

                          return CypherCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            preview,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: CypherColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                entry.source == 'pc'
                                                    ? Icons.desktop_windows_rounded
                                                    : Icons.smartphone_rounded,
                                                size: 12,
                                                color: CypherColors.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatTime(entry.timestamp),
                                                style: AppTheme.caption(context),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18, color: CypherColors.textMuted),
                                      onPressed: () => _deleteEntry(entry),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _copyToClipboard(entry.text),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: CypherColors.accentDim,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.content_copy_rounded, size: 14, color: CypherColors.accent),
                                              SizedBox(width: 6),
                                              Text('Copy', style: TextStyle(fontSize: 12, color: CypherColors.accent, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _pasteToPC(entry.text),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: CypherColors.bgOverlay,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: CypherColors.border),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.paste_rounded, size: 14, color: CypherColors.textSecondary),
                                              SizedBox(width: 6),
                                              Text('Paste to PC', style: TextStyle(fontSize: 12, color: CypherColors.textSecondary, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
