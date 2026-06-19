import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/system_provider.dart';
import '../services/api_service.dart';
import '../services/clipboard_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';
import '../widgets/cypher_card.dart';

class ClipboardScreen extends StatefulWidget {
  const ClipboardScreen({super.key});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Sync tab
  String _phoneContent = '';
  bool _sending = false;
  Timer? _refreshTimer;
  final _quickSendCtrl = TextEditingController();

  // History tab
  late Future<List<ClipboardEntry>> _historyFuture;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _historyFuture = ClipboardService.getHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ip = context.read<ConnectionProvider>().ip ?? '';
      if (ip.isNotEmpty) {
        context.read<SystemProvider>().fetchClipboard(ip);
        _loadPhoneClipboard();
        _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
          if (mounted) context.read<SystemProvider>().fetchClipboard(ip);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _refreshTimer?.cancel();
    _quickSendCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reloadHistory() => setState(() => _historyFuture = ClipboardService.getHistory());

  Future<void> _loadPhoneClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted) setState(() => _phoneContent = data?.text ?? '');
  }

  Future<void> _copyToPhone(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    await ClipboardService.addToHistory(text, source: 'pc');
    HapticFeedback.mediumImpact();
    _toast('Copied to phone');
    setState(() => _phoneContent = text);
    _reloadHistory();
  }

  Future<void> _sendToPC(String text) async {
    if (text.trim().isEmpty) return;
    final ip = context.read<ConnectionProvider>().ip ?? '';
    setState(() => _sending = true);
    try {
      await ApiService.setPcClipboard(ip, text.trim());
      await ClipboardService.addToHistory(text.trim(), source: 'phone');
      HapticFeedback.mediumImpact();
      _toast('Sent to PC');
      _quickSendCtrl.clear();
      FocusScope.of(context).unfocus();
      context.read<SystemProvider>().fetchClipboard(ip);
      _reloadHistory();
    } catch (_) {
      _toast("Couldn't send — check connection", err: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pasteOnPC() async {
    final ip = context.read<ConnectionProvider>().ip ?? '';
    try {
      await ApiService.pasteFromPhone(ip);
      _toast('Pasted on PC');
    } catch (_) {
      _toast('Paste failed', err: true);
    }
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? CypherColors.error : CypherColors.accent,
    ));
  }

  // ── History helpers ────────────────────────────────────────────

  List<ClipboardEntry> _filter(List<ClipboardEntry> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((e) => e.text.toLowerCase().contains(q)).toList();
  }

  Future<void> _copyEntry(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast('Copied');
  }

  Future<void> _pasteEntry(String text) async {
    final ip = context.read<ConnectionProvider>().ip ?? '';
    try {
      await ApiService.pasteClipboard(ip, text);
      _toast('Pasted to PC');
    } catch (_) {
      _toast('Failed to paste', err: true);
    }
  }

  Future<void> _deleteEntry(ClipboardEntry entry) async {
    await ClipboardService.removeEntry(entry.text);
    _reloadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CypherColors.bgCard,
        title: const Text('Clear All?', style: TextStyle(color: CypherColors.textPrimary)),
        content: const Text('Deletes all clipboard history permanently.', style: TextStyle(color: CypherColors.textSecondary)),
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
      _reloadHistory();
      if (mounted) _toast('History cleared');
    }
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SystemProvider>();
    final pcText = sp.pcClipboard ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clipboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              final ip = context.read<ConnectionProvider>().ip ?? '';
              context.read<SystemProvider>().fetchClipboard(ip);
              _loadPhoneClipboard();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Sync'),
            Tab(text: 'History'),
          ],
          indicatorColor: CypherColors.accent,
          labelColor: CypherColors.accent,
          unselectedLabelColor: CypherColors.textMuted,
          dividerColor: CypherColors.border,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSyncTab(pcText),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildSyncTab(String pcText) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const CypherSectionHeader(title: 'PC Clipboard'),
        const SizedBox(height: 8),
        CypherCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pcText.isEmpty)
                const Text('Nothing in PC clipboard', style: TextStyle(color: CypherColors.textMuted, fontSize: 14))
              else
                Text(pcText, maxLines: 6, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: CypherColors.textPrimary, height: 1.5)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: CypherButton(label: 'Copy to Phone', onTap: () => _copyToPhone(pcText))),
                  if (pcText.startsWith('http')) ...[
                    const SizedBox(width: 8),
                    CypherButton(
                      label: 'Open Link',
                      variant: CypherButtonVariant.secondary,
                      onTap: () => ApiService.openLink(context.read<ConnectionProvider>().ip ?? '', pcText),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const CypherSectionHeader(title: 'Phone Clipboard'),
        const SizedBox(height: 8),
        CypherCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_phoneContent.isEmpty)
                const Text('Nothing in phone clipboard', style: TextStyle(color: CypherColors.textMuted, fontSize: 14))
              else
                Text(_phoneContent, maxLines: 6, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: CypherColors.textPrimary, height: 1.5)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: CypherButton(label: 'Send to PC', onTap: () => _sendToPC(_phoneContent), loading: _sending)),
                  const SizedBox(width: 8),
                  CypherButton(label: 'Paste on PC', variant: CypherButtonVariant.secondary, onTap: _pasteOnPC),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const CypherSectionHeader(title: 'Quick Send'),
        const SizedBox(height: 8),
        CypherCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _quickSendCtrl,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Type text or paste a link to send to PC...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),
              CypherButton(label: 'Send to PC', onTap: () => _sendToPC(_quickSendCtrl.text), loading: _sending),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search history...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: CypherColors.textMuted),
                onPressed: _clearAll,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ClipboardEntry>>(
            future: _historyFuture,
            builder: (_, snap) {
              final filtered = _filter(snap.data ?? []);
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.content_paste_off_rounded, size: 48, color: CypherColors.textMuted),
                      const SizedBox(height: 16),
                      Text('No clipboard history', style: AppTheme.subtitle(context)),
                      const SizedBox(height: 8),
                      Text('Items you copy or send appear here', style: AppTheme.body(context)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final e = filtered[i];
                  final preview = e.text.length > 100 ? '${e.text.substring(0, 100)}...' : e.text;
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
                                  Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CypherColors.textPrimary)),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    Icon(
                                      e.source == 'pc' ? Icons.desktop_windows_rounded : Icons.smartphone_rounded,
                                      size: 12, color: CypherColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(_ago(e.timestamp), style: AppTheme.caption(context)),
                                  ]),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: CypherColors.textMuted),
                              onPressed: () => _deleteEntry(e),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _copyEntry(e.text),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(color: CypherColors.accentDim, borderRadius: BorderRadius.circular(8)),
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.content_copy_rounded, size: 14, color: CypherColors.accent),
                                  SizedBox(width: 6),
                                  Text('Copy', style: TextStyle(fontSize: 12, color: CypherColors.accent, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pasteEntry(e.text),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: CypherColors.bgOverlay,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: CypherColors.border),
                                ),
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.paste_rounded, size: 14, color: CypherColors.textSecondary),
                                  SizedBox(width: 6),
                                  Text('Paste to PC', style: TextStyle(fontSize: 12, color: CypherColors.textSecondary, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
