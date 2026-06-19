import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/file_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';
import '../widgets/cypher_card.dart';

class SendToPCScreen extends StatefulWidget {
  final List<String>? sharedFiles;
  const SendToPCScreen({super.key, this.sharedFiles});

  @override
  State<SendToPCScreen> createState() => _SendToPCScreenState();
}

class _SendToPCScreenState extends State<SendToPCScreen> {
  List<String> _selectedPaths = [];
  String _destination = 'Desktop';
  String _destinationPath = ''; // Full path
  Map<String, String> _destinations = {}; // name -> path
  List<Map<String, dynamic>> _subfolders = [];
  String _currentBrowsePath = '';
  String _currentDisplayName = '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.sharedFiles != null && widget.sharedFiles!.isNotEmpty) {
      _selectedPaths = List<String>.from(widget.sharedFiles!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFolders());
  }

  String get _ip => context.read<ConnectionProvider>().ip ?? '';

  Future<void> _loadFolders() async {
    try {
      final dests = await ApiService.getUploadDestinations(_ip);
      Map<String, String> map = {};
      for (var dest in dests) {
        map[dest['name'] as String] = dest['path'] as String;
      }
      if (map.isNotEmpty) {
        setState(() {
          _destinations = map;
          _destination = map.keys.first;
          _destinationPath = map[_destination] ?? '';
        });
      }
    } catch (_) {
      setState(() {
        _destinations = {'Desktop': 'Desktop', 'Documents': 'Documents', 'Downloads': 'Downloads'};
        _destination = 'Desktop';
      });
    }
  }

  Future<void> _browseFolders(String? path) async {
    try {
      final result = await ApiService.browseFolders(_ip, path: path);
      if (result['success'] == true) {
        setState(() {
          _subfolders = List<Map<String, dynamic>>.from(result['folders'] ?? []);
          _currentBrowsePath = result['current_path'] ?? '';
          _currentDisplayName = result['display_name'] ?? 'Select Folder';
        });
      }
    } catch (_) {}
  }

  void _selectFolder(String folderPath, String folderName) {
    setState(() {
      _destination = folderName;
      _destinationPath = folderPath;
      _subfolders = [];
      _currentBrowsePath = '';
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && mounted) {
      setState(() {
        _selectedPaths.addAll(
          result.paths.whereType<String>().where((p) => !_selectedPaths.contains(p)),
        );
      });
    }
  }

  void _removeFile(String path) => setState(() => _selectedPaths.remove(path));

  Future<void> _upload() async {
    if (_selectedPaths.isEmpty) return;
    setState(() => _uploading = true);

    final fp = context.read<FileProvider>();
    // Use full path if available, otherwise use folder name
    final dest = _destinationPath.isNotEmpty ? _destinationPath : _destination;

    for (final path in _selectedPaths) {
      final name = path.split(RegExp(r'[/\\]')).last;
      await fp.upload(_ip, path, dest, name);
    }

    if (mounted) {
      setState(() => _uploading = false);
      Navigator.pushReplacementNamed(context, '/active_tasks');
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024)       return '$bytes B';
    if (bytes < 1048576)    return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  int _totalBytes() {
    int total = 0;
    for (final path in _selectedPaths) {
      try { total += File(path).lengthSync(); } catch (_) {}
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CypherColors.bgDeep,
      appBar: AppBar(
        backgroundColor: CypherColors.bgDeep,
        title: const Text('Send to PC'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File list card
                  CypherCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        if (_selectedPaths.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.upload_file_rounded, color: CypherColors.textMuted, size: 36),
                                SizedBox(height: 8),
                                Text('No files selected', style: TextStyle(color: CypherColors.textMuted)),
                              ],
                            ),
                          )
                        else
                          ...List.generate(_selectedPaths.length, (i) {
                            final path = _selectedPaths[i];
                            final name = path.split(RegExp(r'[/\\]')).last;
                            int size = 0;
                            try { size = File(path).lengthSync(); } catch (_) {}
                            return Column(
                              children: [
                                if (i > 0) const Divider(height: 1),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                  leading: const Icon(Icons.insert_drive_file_rounded, color: CypherColors.accentLight, size: 22),
                                  title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CypherColors.textPrimary), overflow: TextOverflow.ellipsis),
                                  subtitle: Text(_fmtSize(size), style: AppTheme.caption(context)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close_rounded, color: CypherColors.textMuted, size: 18),
                                    onPressed: () => _removeFile(path),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ],
                            );
                          }),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.add_rounded, color: CypherColors.accent, size: 22),
                          title: const Text('Add Files', style: TextStyle(color: CypherColors.accent, fontWeight: FontWeight.w500)),
                          onTap: _pickFiles,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Destination
                  const Text('DESTINATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CypherColors.textMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 10),

                  // Show folder browser if browsing, otherwise show quick selections
                  if (_subfolders.isNotEmpty)
                    CypherCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // Header with back button
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: CypherColors.border)),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () { HapticFeedback.selectionClick(); _browseFolders(null); },
                                  child: const Icon(Icons.arrow_back_rounded, color: CypherColors.accent, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _currentDisplayName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CypherColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _selectFolder(_currentBrowsePath, _currentDisplayName),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: CypherColors.accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Select', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Folders list
                          ..._subfolders.map((folder) => ListTile(
                            leading: const Icon(Icons.folder_rounded, color: CypherColors.accent, size: 20),
                            title: Text(folder['name'] ?? '', style: const TextStyle(fontSize: 13, color: CypherColors.textPrimary)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: CypherColors.textMuted),
                            onTap: () { HapticFeedback.selectionClick(); _browseFolders(folder['path']); },
                          )),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: _destinations.entries.map((entry) {
                        final sel = _destination == entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _destination = entry.key;
                                _destinationPath = entry.value;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: CypherColors.bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? CypherColors.accent : CypherColors.border,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.folder_rounded, size: 18, color: sel ? CypherColors.accent : CypherColors.textMuted),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                        color: sel ? CypherColors.textPrimary : CypherColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (sel)
                                    const Icon(Icons.check_circle_rounded, size: 18, color: CypherColors.accent)
                                  else
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _browseFolders(entry.value);
                                      },
                                      child: const Text('Browse', style: TextStyle(fontSize: 11, color: CypherColors.accent)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: CypherColors.bgCard,
              border: Border(top: BorderSide(color: CypherColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_selectedPaths.length} file${_selectedPaths.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CypherColors.textPrimary),
                      ),
                      if (_selectedPaths.isNotEmpty)
                        Text(_fmtSize(_totalBytes()), style: AppTheme.caption(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: CypherButton(
                    label: 'Upload',
                    icon: const Icon(Icons.cloud_upload_rounded),
                    onTap: (_selectedPaths.isEmpty || _uploading) ? null : _upload,
                    loading: _uploading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
