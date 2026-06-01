import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class FileBrowserScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final String? initialPath;

  const FileBrowserScreen({super.key, required this.pcIpAddress, required this.authToken, this.initialPath});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  List<dynamic> _filteredItems = [];
  List<dynamic> _drives = [];
  String? _currentPath;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Selection Mode Logic
  final Set<String> _selectedPaths = {};
  bool _isBatchDownloading = false;
  double _batchProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _fetchFiles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFiles() async {
    setState(() { _isLoading = true; _selectedPaths.clear(); });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    final headers = {'X-Auth-Token': widget.authToken};
    final baseUrl = 'http://${widget.pcIpAddress}:5000';

    try {
      if (_currentPath == null) {
        final res = await http.get(Uri.parse('$baseUrl/files'), headers: headers).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          _drives = data.where((i) => i['type'] == 'drive').toList();
          _items = data.where((i) => i['type'] != 'drive').toList();
          _filteredItems = _items;
        }
      } else {
        final res = await http.get(Uri.parse('$baseUrl/files/browse?path=${Uri.encodeComponent(_currentPath!)}'), headers: headers).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          _items = jsonDecode(res.body) as List;
          _filteredItems = _items;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _onSearch(String query) {
    setState(() {
      _filteredItems = _items.where((i) => i['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(accent),
                _buildSearchSection(isDark),
                Expanded(
                  child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _buildContent(accent, isDark),
                ),
              ],
            ),
          ),

          if (_selectedPaths.isNotEmpty) _buildSelectionBar(isDark),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20),
                onPressed: () {
                  if (_currentPath != null) {
                    setState(() { _currentPath = null; });
                    _fetchFiles();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              Text("FILE BROWSER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
            ],
          ),
          Icon(Icons.sensors_rounded, color: accent),
        ],
      ),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3)),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: GoogleFonts.roboto(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _currentPath == null ? "Search drives..." : "Search folder...",
                  hintStyle: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Color accent, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      controller: _scrollController,
      slivers: [
        if (_currentPath == null && _drives.isNotEmpty)
          _buildSectionTitle("Locations", isDark),
        if (_currentPath == null && _drives.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid.count(
              crossAxisCount: 1,
              mainAxisSpacing: 12,
              childAspectRatio: 3.5,
              children: _drives.map((d) => _buildDriveCard(d, accent, isDark)).toList(),
            ),
          ),

        _buildSectionTitle(_currentPath == null ? "Folders" : "Files", isDark),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _filteredItems[index];
                return _buildFileRow(item, isDark);
              },
              childCount: _filteredItems.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 150)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 24, 16),
        child: Text(title.toUpperCase(), style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 2)),
      ),
    );
  }

  Widget _buildDriveCard(dynamic drive, Color accent, bool isDark) {
    final double percent = ((drive['percent'] ?? 0) as num).toDouble() / 100;
    return GestureDetector(
      onTap: () {
        setState(() { _currentPath = drive['path']; });
        _fetchFiles();
      },
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.storage_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(drive['name'], style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      Text("${(percent * 100).toInt()}%", style: GoogleFonts.roboto(fontSize: 10, color: accent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(value: percent, minHeight: 2, backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05), valueColor: AlwaysStoppedAnimation(accent)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileRow(dynamic item, bool isDark) {
    final isFolder = item['type'] == 'folder';
    final path = item['path'];
    final isSelected = _selectedPaths.contains(path);
    final accent = const Color(0xFF6C63FF);

    return GestureDetector(
      onTap: () {
        if (_selectedPaths.isNotEmpty) {
          _toggleSelect(path);
          return;
        }
        if (isFolder) {
          setState(() { _currentPath = item['path']; });
          _fetchFiles();
        } else {
          Navigator.pushNamed(context, '/preview', arguments: {
            'pcIpAddress': widget.pcIpAddress,
            'authToken': widget.authToken,
            'filePath': item['path'],
            'fileName': item['name'],
            'fileSize': item['size'],
            'fileExtension': item['extension'],
          });
        }
      },
      onLongPress: () => _toggleSelect(path),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border(bottom: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03))),
        ),
        child: Row(
          children: [
            Icon(
              isFolder ? Icons.folder_rounded : Icons.description_rounded,
              color: isFolder ? const Color(0xFFFFB786) : accent,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'], style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w500, color: isSelected ? accent : (isDark ? Colors.white : Colors.black)), overflow: TextOverflow.ellipsis),
                  if (!isFolder)
                    Text(_formatSize(item['size']), style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF6C63FF), size: 18)
            else Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadSelectedFiles() async {
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.request().isGranted &&
          !await Permission.storage.request().isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Storage permission required")));
        return;
      }
    }

    setState(() {
      _isBatchDownloading = true;
      _batchProgress = 0.0;
    });

    int successCount = 0;
    final List<String> paths = _selectedPaths.toList();
    final client = http.Client();

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      try {
        final fileName = path.split(Platform.isWindows ? '\\' : '/').last;
        final url = 'http://${widget.pcIpAddress}:5000/files/download?path=${Uri.encodeComponent(path)}';

        final request = http.Request('GET', Uri.parse(url));
        request.headers['X-Auth-Token'] = widget.authToken;

        final response = await client.send(request).timeout(const Duration(minutes: 5));

        if (response.statusCode == 200) {
          Directory? dir = Platform.isAndroid ? Directory('/storage/emulated/0/Download') : await getDownloadsDirectory();
          if (dir == null || !await dir.exists()) dir = await getApplicationDocumentsDirectory();

          final file = File('${dir.path}/$fileName');
          final IOSink sink = file.openWrite();
          await response.stream.forEach((chunk) => sink.add(chunk));
          await sink.close();
          successCount++;
        }
      } catch (_) {}
      if (mounted) setState(() => _batchProgress = (i + 1) / paths.length);
    }
    client.close();

    setState(() {
      _isBatchDownloading = false;
      _selectedPaths.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Synced $successCount files to Downloads"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _deleteSelectedFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Items?", style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Permanently delete ${_selectedPaths.length} items from PC?", style: GoogleFonts.roboto(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white24))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    int successCount = 0;
    for (var path in _selectedPaths) {
      try {
        final res = await http.delete(
          Uri.parse('http://${widget.pcIpAddress}:5000/files/delete?path=${Uri.encodeComponent(path)}'),
          headers: {'X-Auth-Token': widget.authToken},
        ).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) successCount++;
      } catch (_) {}
    }

    setState(() {
      _isLoading = false;
      _selectedPaths.clear();
    });
    _fetchFiles();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deleted $successCount items"), backgroundColor: Colors.redAccent));
  }

  Widget _buildSelectionBar(bool isDark) {
    return Positioned(
      bottom: 110, left: 20, right: 20,
      child: FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          borderRadius: BorderRadius.circular(24),
          color: isDark ? Colors.black : Colors.white,
          opacity: 0.9,
          child: Row(
            children: [
              if (_isBatchDownloading)
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
                      const SizedBox(width: 12),
                      Text("SYNCING ${(_batchProgress * 100).toInt()}%", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
                    ],
                  ),
                )
              else ...[
                Text("${_selectedPaths.length} SELECTED", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
                const Spacer(),
                _selectionAction(Icons.download_rounded, "Sync", isDark, onTap: _downloadSelectedFiles),
                const SizedBox(width: 16),
                _selectionAction(Icons.delete_outline_rounded, "Delete", isDark, color: Colors.redAccent, onTap: _deleteSelectedFiles),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionAction(IconData icon, String label, bool isDark, {Color? color, VoidCallback? onTap}) {
    final c = color ?? (isDark ? Colors.white : Colors.black);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c.withOpacity(0.8), size: 20),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.roboto(fontSize: 8, color: c.withOpacity(0.4))),
        ],
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  Widget _buildBottomNav() {
    final theme = Provider.of<ThemeService>(context, listen: false).isDarkMode;
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context), theme),
          _navItem(Icons.folder_copy_rounded, "Files", true, null, theme),
          _navItem(Icons.grid_view_rounded, "Tools", false, () => Navigator.pushReplacementNamed(context, '/controls', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), theme),
          _navItem(Icons.tune_rounded, "Settings", false, () => Navigator.pushReplacementNamed(context, '/settings', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), theme),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, [VoidCallback? tap, bool isDark = true]) {
    final accent = const Color(0xFF6C63FF);
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;
    return GestureDetector(
      onTap: tap,
      child: Opacity(
        opacity: 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? accent : inactiveColor, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: active ? accent : inactiveColor)),
          ],
        ),
      ),
    );
  }
}
