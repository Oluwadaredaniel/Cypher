import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/file_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_card.dart';
import '../widgets/shimmer_box.dart';

class ActiveTasksScreen extends StatefulWidget {
  const ActiveTasksScreen({super.key});

  @override
  State<ActiveTasksScreen> createState() => _ActiveTasksScreenState();
}

class _ActiveTasksScreenState extends State<ActiveTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _windows = [];
  bool _loadingWindows = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchWindows());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _ip => context.read<ConnectionProvider>().ip ?? '';

  Future<void> _fetchWindows() async {
    setState(() => _loadingWindows = true);
    try {
      final data = await ApiService.getActiveWindows(_ip);
      final wins = data['windows'] as List? ?? (data['data'] as List? ?? []);
      setState(() => _windows = wins);
    } catch (_) {}
    if (mounted) setState(() => _loadingWindows = false);
  }

  Future<void> _closeWindow(int id, String title) async {
    HapticFeedback.heavyImpact();
    await ApiService.closeApp(_ip, windowId: id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Closed $title')));
    _fetchWindows();
  }

  IconData _winIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('chrome') || t.contains('edge') || t.contains('firefox')) return Icons.language_rounded;
    if (t.contains('spotify') || t.contains('music')) return Icons.music_note_rounded;
    if (t.contains('vlc') || t.contains('video') || t.contains('media')) return Icons.play_circle_rounded;
    if (t.contains('code') || t.contains('studio')) return Icons.code_rounded;
    if (t.contains('word') || t.contains('docs')) return Icons.description_rounded;
    if (t.contains('folder') || t.contains('explorer')) return Icons.folder_open_rounded;
    return Icons.window_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Tasks'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Transfers'),
            Tab(text: 'Windows'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchWindows,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TransfersTab(),
          _buildWindowsTab(),
        ],
      ),
    );
  }

  Widget _buildWindowsTab() {
    if (_loadingWindows) return const ShimmerList(count: 6);

    if (_windows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.desktop_windows_rounded, color: CypherColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text('No active windows', style: TextStyle(color: CypherColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: CypherColors.accent,
      onRefresh: _fetchWindows,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        itemCount: _windows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final win   = _windows[i] as Map;
          final title = win['title']?.toString() ?? 'Window';
          final id    = win['id'] as int? ?? 0;
          final minimized = win['is_minimized'] as bool? ?? false;
          final tabs      = (win['tab_hint'] as int?) ?? 0;

          return CypherCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: CypherColors.accentDim, borderRadius: BorderRadius.circular(10)),
                  child: Icon(_winIcon(title), color: CypherColors.accentLight, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CypherColors.textPrimary), overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          if (tabs > 1) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(color: CypherColors.accentDim, borderRadius: BorderRadius.circular(4)),
                              child: Text('$tabs tabs', style: const TextStyle(fontSize: 9, color: CypherColors.accentLight, fontWeight: FontWeight.w600)),
                            ),
                          ],
                          Text(
                            minimized ? 'Minimized' : 'Active',
                            style: TextStyle(fontSize: 11, color: minimized ? CypherColors.textMuted : CypherColors.success),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: CypherColors.error, size: 18),
                  onPressed: () => _closeWindow(id, title),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TransfersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FileProvider>();
    final transfers = fp.transfers;

    if (transfers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz_rounded, color: CypherColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text('No transfers', style: TextStyle(color: CypherColors.textMuted)),
            SizedBox(height: 4),
            Text('Downloads and uploads appear here', style: TextStyle(color: CypherColors.textDisabled, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (transfers.any((t) => t.status == TransferStatus.done || t.status == TransferStatus.error))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: fp.clearTransfers,
                child: const Text('Clear Done', style: TextStyle(color: CypherColors.accent, fontSize: 12)),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: transfers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _TransferRow(task: transfers[i]),
          ),
        ),
      ],
    );
  }
}

class _TransferRow extends StatelessWidget {
  final TransferTask task;
  const _TransferRow({required this.task});

  String _fmt(int b) {
    if (b < 1024)       return '$b B';
    if (b < 1048576)    return '${(b/1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB';
    return '${(b/1073741824).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isDone   = task.status == TransferStatus.done;
    final isError  = task.status == TransferStatus.error;
    final isActive = task.status == TransferStatus.downloading || task.status == TransferStatus.uploading;
    final color    = isError ? CypherColors.error : isDone ? CypherColors.success : CypherColors.accent;

    return CypherCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                task.isUpload ? Icons.upload_rounded : Icons.download_rounded,
                color: color, size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(task.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CypherColors.textPrimary), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isDone ? 'Done' : isError ? 'Error' : task.isUpload ? 'Uploading' : 'Downloading',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          if (isActive || task.total > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: task.progress.clamp(0.0, 1.0), color: color, backgroundColor: CypherColors.bgOverlay, minHeight: 2),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(task.total > 0 ? '${_fmt(task.received)} / ${_fmt(task.total)}' : _fmt(task.received), style: AppTheme.caption(context)),
                Text('${(task.progress * 100).clamp(0, 100).toInt()}%', style: const TextStyle(fontSize: 11, color: CypherColors.accentLight)),
              ],
            ),
          ],
          if (isError && task.error != null) ...[
            const SizedBox(height: 4),
            Text(task.error!, style: const TextStyle(fontSize: 10, color: CypherColors.error)),
          ],
        ],
      ),
    );
  }
}
