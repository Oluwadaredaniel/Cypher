import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/file_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/file_icon.dart';
import '../widgets/shimmer_box.dart';

class FileBrowserScreen extends StatefulWidget {
  final String? initialPath;
  const FileBrowserScreen({super.key, this.initialPath});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  bool _isGridView = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ip = context.read<ConnectionProvider>().ip ?? '';
      if (widget.initialPath != null) {
        context.read<FileProvider>().browse(ip, widget.initialPath!);
      } else {
        context.read<FileProvider>().loadRoot(ip);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _ip => context.read<ConnectionProvider>().ip ?? '';

  String _titleFor(String? path) {
    if (path == null) return 'Files';
    final parts = path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Files' : parts.last;
  }

  String _fmtSize(dynamic size) {
    if (size == null || size == 0) return '';
    final b = (size is int) ? size : int.tryParse(size.toString()) ?? 0;
    if (b < 1024)           return '$b B';
    if (b < 1048576)        return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1073741824)     return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(1)} GB';
  }

  List _visibleItems(FileProvider fp) {
    final items = fp.items;
    if (_searchQuery.isEmpty) return items;
    final q = _searchQuery.toLowerCase();
    return items.where((i) => (i['name']?.toString().toLowerCase() ?? '').contains(q)).toList();
  }

  void _openFile(Map item) {
    Navigator.pushNamed(context, '/preview', arguments: {
      'filePath':      item['path'] ?? '',
      'fileName':      item['name'] ?? '',
      'fileSize':      (item['size'] ?? 0) as int,
      'fileExtension': item['extension'] ?? (item['name']?.toString().contains('.') == true ? '.${item['name'].toString().split('.').last}' : ''),
    });
  }

  void _openFolder(Map item) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FileBrowserScreen(initialPath: item['path']),
    ));
  }

  Future<void> _download(Map item) async {
    Navigator.pop(context);
    final fp = context.read<FileProvider>();
    await fp.download(_ip, item['path'] ?? '', item['name'] ?? 'file');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download started — check Active Tasks')));
    }
  }

  Future<void> _delete(Map item) async {
    Navigator.pop(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Remove ${item['name']} permanently from your PC?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: CypherColors.error))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<FileProvider>().delete(_ip, item['path'] ?? '');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  void _showOptions(Map item) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: CypherColors.textMuted, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(item['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CypherColors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.file_download_rounded, color: CypherColors.accent),
              title: const Text('Download to Phone'),
              onTap: () => _download(item),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: CypherColors.error),
              title: const Text('Delete from PC', style: TextStyle(color: CypherColors.error)),
              onTap: () => _delete(item),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FileProvider>();
    final items = _visibleItems(fp);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSearching ? '' : _titleFor(widget.initialPath)),
        actions: [
          if (_isSearching)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(hintText: 'Search files…', border: InputBorder.none),
                ),
              ),
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) { _searchCtrl.clear(); _searchQuery = ''; }
            }),
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: CypherColors.accent,
        onRefresh: () async {
          if (widget.initialPath != null) fp.browse(_ip, widget.initialPath!);
          else fp.loadRoot(_ip);
        },
        child: fp.isLoading
          ? const ShimmerList(count: 12)
          : items.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 100),
                  const Icon(Icons.folder_off_rounded, color: CypherColors.textMuted, size: 40),
                  const SizedBox(height: 12),
                  const Center(child: Text('Folder is empty', style: TextStyle(color: CypherColors.textMuted))),
                ],
              )
            : _isGridView
              ? _GridView(items: items, onTap: (item) {
                  final isFolder = item['type'] == 'folder' || item['type'] == 'directory' || item['type'] == 'drive';
                  isFolder ? _openFolder(item) : _openFile(item);
                }, onLongPress: (item) { final isFolder = item['type'] == 'folder' || item['type'] == 'directory'; if (!isFolder) _showOptions(item); }, ip: _ip)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                  itemBuilder: (_, i) {
                    final item = items[i] as Map;
                    final isFolder = item['type'] == 'folder' || item['type'] == 'directory' || item['type'] == 'drive';

                    return ListTile(
                      leading: FileIcon(
                        name:  item['name']?.toString() ?? '',
                        isDir: isFolder,
                      ),
                      title: Text(item['name']?.toString() ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: CypherColors.textPrimary), overflow: TextOverflow.ellipsis),
                      subtitle: Text('${_fmtSize(item['size'])}${item['modified'] != null ? '  •  ${item['modified']}' : ''}', style: AppTheme.caption(context)),
                      trailing: isFolder
                        ? const Icon(Icons.chevron_right_rounded, color: CypherColors.textMuted, size: 18)
                        : IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: CypherColors.textMuted, size: 18),
                            onPressed: () => _showOptions(item),
                          ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        isFolder ? _openFolder(item) : _openFile(item);
                      },
                    );
                  },
                ),
      ),
    );
  }
}

class _GridView extends StatelessWidget {
  final List items;
  final void Function(Map) onTap;
  final void Function(Map) onLongPress;
  final String ip;

  const _GridView({required this.items, required this.onTap, required this.onLongPress, required this.ip});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.85, mainAxisSpacing: 12, crossAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i] as Map;
        return GestureDetector(
          onTap:      () => onTap(item),
          onLongPress: () => onLongPress(item),
          child: Column(
            children: [
              Expanded(
                child: FileIcon(
                  name:  item['name']?.toString() ?? '',
                  isDir: item['type'] == 'folder' || item['type'] == 'directory' || item['type'] == 'drive',
                  size:  56,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['name']?.toString() ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: CypherColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}
