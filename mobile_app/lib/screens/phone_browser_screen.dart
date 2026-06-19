import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/connection_provider.dart';
import '../providers/file_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';

class PhoneBrowserScreen extends StatefulWidget {
  const PhoneBrowserScreen({super.key});

  @override
  State<PhoneBrowserScreen> createState() => _PhoneBrowserScreenState();
}

class _PhoneBrowserScreenState extends State<PhoneBrowserScreen> {
  Directory? _dir;
  List<FileSystemEntity> _items = [];
  bool _loading = true;
  bool _showHidden = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestAndLoad();
  }

  String get _ip => context.read<ConnectionProvider>().ip ?? '';

  Future<void> _requestAndLoad() async {
    bool granted = false;
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        final s2 = await Permission.storage.request();
        granted = s2.isGranted;
      } else {
        granted = true;
      }
      if (granted) {
        _loadDir(Directory('/storage/emulated/0'));
        return;
      }
    } else {
      granted = true;
    }

    if (!granted && mounted) {
      setState(() { _error = 'Storage permission is required.'; _loading = false; });
    }
  }

  Future<void> _loadDir(Directory dir) async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      var items = await dir.list().toList();
      if (!_showHidden) {
        items = items.where((e) => !p.basename(e.path).startsWith('.')).toList();
      }
      items.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir && !bDir) return -1;
        if (!aDir && bDir) return 1;
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });
      if (mounted) setState(() { _dir = dir; _items = items; });
    } catch (e) {
      if (mounted) setState(() => _error = 'Cannot read this folder.');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onTap(FileSystemEntity entity) {
    if (entity is Directory) {
      _loadDir(entity);
    } else if (entity is File) {
      _offerUpload(entity);
    }
  }

  void _offerUpload(File file) {
    final name     = p.basename(file.path);
    final fp       = context.read<FileProvider>();
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: CypherColors.textMuted, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.insert_drive_file_rounded, color: CypherColors.accentLight, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CypherColors.textPrimary), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 16),
            CypherButton(
              label: 'Send to PC',
              icon: const Icon(Icons.upload_rounded),
              onTap: () {
                Navigator.pop(context);
                fp.upload(_ip, file.path, 'Desktop', name);
                Navigator.pushNamed(context, '/active_tasks');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      ('Downloads', '/storage/emulated/0/Download', Icons.download_rounded),
      ('Camera', '/storage/emulated/0/DCIM/Camera', Icons.camera_alt_rounded),
      ('WhatsApp', '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images', Icons.message_rounded),
      ('Documents', '/storage/emulated/0/Documents', Icons.description_rounded),
    ];

    final isRoot = _dir?.path == '/storage/emulated/0';
    final dirName = _dir == null ? 'Phone Storage' : p.basename(_dir!.path);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dirName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (_dir != null)
              Text(_dir!.path, style: const TextStyle(fontSize: 10, color: CypherColors.textMuted), overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off_outlined, size: 20),
            tooltip: _showHidden ? 'Hide hidden files' : 'Show hidden files',
            onPressed: () { setState(() => _showHidden = !_showHidden); if (_dir != null) _loadDir(_dir!); },
          ),
        ],
      ),
      body: _error != null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_off_rounded, color: CypherColors.textMuted, size: 48),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: CypherColors.textMuted)),
                const SizedBox(height: 12),
                TextButton(onPressed: _requestAndLoad, child: const Text('Retry', style: TextStyle(color: CypherColors.accent))),
              ],
            ),
          )
        : _loading
          ? const Center(child: CircularProgressIndicator(color: CypherColors.accent))
          : Column(
              children: [
                // Quick access chips
                if (isRoot) SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: shortcuts.length,
                    itemBuilder: (_, i) {
                      final (label, path, icon) = shortcuts[i];
                      return GestureDetector(
                        onTap: () {
                          final d = Directory(path);
                          if (d.existsSync()) _loadDir(d);
                          else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label folder not found')));
                        },
                        child: Container(
                          width: 88, margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: CypherColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: CypherColors.border),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: CypherColors.accentLight, size: 22),
                              const SizedBox(height: 6),
                              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: CypherColors.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Up arrow if not root
                if (!isRoot && _dir?.parent != null)
                  ListTile(
                    leading: const Icon(Icons.arrow_upward_rounded, color: CypherColors.accent, size: 20),
                    title: const Text('..', style: TextStyle(color: CypherColors.textSecondary, fontSize: 13)),
                    onTap: () => _loadDir(_dir!.parent),
                    dense: true,
                  ),

                // File list
                Expanded(
                  child: _items.isEmpty
                    ? const Center(child: Text('Empty folder', style: TextStyle(color: CypherColors.textMuted)))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
                        itemBuilder: (_, i) {
                          final item   = _items[i];
                          final isDir  = item is Directory;
                          final name   = p.basename(item.path);
                          final size   = isDir ? null : (item as File).lengthSync();

                          return ListTile(
                            leading: Icon(
                              isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                              color: isDir ? CypherColors.warning : CypherColors.accentLight,
                              size: 22,
                            ),
                            title: Text(name, style: const TextStyle(fontSize: 13, color: CypherColors.textPrimary), overflow: TextOverflow.ellipsis),
                            subtitle: size != null ? Text(_fmtSize(size), style: AppTheme.caption(context)) : null,
                            trailing: isDir ? const Icon(Icons.chevron_right_rounded, color: CypherColors.textMuted, size: 18) : null,
                            onTap: () { HapticFeedback.selectionClick(); _onTap(item); },
                          );
                        },
                      ),
                ),
              ],
            ),
    );
  }

  String _fmtSize(int b) {
    if (b < 1024)       return '$b B';
    if (b < 1048576)    return '${(b/1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB';
    return '${(b/1073741824).toStringAsFixed(1)} GB';
  }
}
