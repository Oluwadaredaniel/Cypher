import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'package:media_scanner/media_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'file_preview_screen.dart'; // IMPORTED FOR FLOW
import '../services/permission_service.dart';

class FileBrowserScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final String? initialPath;

  const FileBrowserScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
    this.initialPath,
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  // Navigation State
  List<dynamic> _items = [];
  List<dynamic> _filteredItems = [];

  // UI State
  bool _isLoading = true;
  bool _hasError = false;
  bool _isSearching = false;
  bool _isGridView = false;
  bool _isSelectionMode = false;
  Set<String> _selectedPaths = {};
  String _groupBy = "None"; // "None", "Date", "Type"
  final TextEditingController _searchController = TextEditingController();

  // Download State
  double _downloadProgress = 0.0;
  String _downloadSpeed = "0 KB/s";
  String _timeLeft = "";
  http.Client? _downloadClient;
  StreamSubscription? _downloadSubscription;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _downloadSubscription?.cancel();
    _downloadClient?.close();
    super.dispose();
  }

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {"X-Auth-Token": widget.authToken};

  // --- API LOGIC ---

  Future<void> _refresh() async {
    if (widget.initialPath != null) {
      await _fetchFolderContents(widget.initialPath!);
    } else {
      await _fetchRoots();
    }
  }

  Future<void> _fetchRoots() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final response = await http.get(Uri.parse("$_baseUrl/files"), headers: _headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _items = jsonDecode(response.body);
          _filteredItems = _items;
          _isLoading = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _fetchFolderContents(String path) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final encodedPath = Uri.encodeComponent(path);
      final response = await http.get(
          Uri.parse("$_baseUrl/files/browse?path=$encodedPath"),
          headers: _headers
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _items = jsonDecode(response.body);
          _filteredItems = _items;
          _isLoading = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // --- DELETE LOGIC ---
  Future<void> _handleDelete(String path, String name) async {
    if (_isSelectionMode) return;
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Item", style: GoogleFonts.outfit(color: Colors.white)),
        content: Text("Delete $name permanently from your PC?", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final url = Uri.parse("$_baseUrl/files/delete?path=${Uri.encodeComponent(path)}");
        final response = await http.delete(url, headers: _headers).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted successfully")));
          _refresh();
        }
      } catch (e) {
        debugPrint("Delete error: $e");
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filteredItems = _items
          .where((item) => item['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) _isSelectionMode = false;
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _enterSelectionMode(String path) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedPaths.add(path);
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedPaths.isEmpty) return;

    final List<String> filesToZip = [];
    for (var path in _selectedPaths) {
      final item = _items.firstWhere((i) => i['path'] == path, orElse: () => null);
      if (item != null && item['type'] != 'folder' && item['type'] != 'drive') {
        filesToZip.add(path);
      }
    }

    if (filesToZip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only files can be batch downloaded")));
      return;
    }

    // If only one file, use regular download
    if (filesToZip.length == 1) {
      final item = _items.firstWhere((i) => i['path'] == filesToZip.first);
      _startDownload(item);
      setState(() {
        _isSelectionMode = false;
        _selectedPaths.clear();
      });
      return;
    }

    // Start Batch Download (Zip)
    setState(() => _isDownloading = true);
    
    // We'll create a fake item for the ZIP progress UI
    final zipName = "cypher_batch_${DateFormat('HHmmss').format(DateTime.now())}.zip";
    final zipItem = {'name': zipName, 'path': 'batch_zip'};

    late StateSetter setProgressState;
    _showDownloadSheet(zipItem, (stateSetter) {
      setProgressState = stateSetter;
    });

    try {
      _downloadClient = http.Client();
      final request = http.Request('POST', Uri.parse("$_baseUrl/files/download/zip"));
      request.headers.addAll(_headers);
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({"paths": filesToZip});

      final response = await _downloadClient!.send(request);
      final total = response.contentLength ?? 0;
      int received = 0;
      
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final saveFile = File("${dir.path}/$zipName");
      final IOSink sink = saveFile.openWrite();
      final stopwatch = Stopwatch()..start();

      _downloadSubscription = response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
        final elapsed = stopwatch.elapsed.inSeconds;
        double progress = total > 0 ? (received / total) : 0;
        
        setProgressState(() {
          _downloadProgress = progress;
          if (elapsed > 0) {
            double mbps = (received / 1024 / 1024) / elapsed;
            _downloadSpeed = "${mbps.toStringAsFixed(1)} MB/s";
          }
        });
      }, onDone: () async {
        await sink.close();
        if (Platform.isAndroid) await MediaScanner.loadMedia(path: saveFile.path);
        if (mounted) {
          setProgressState(() { _downloadProgress = 1.0; _isDownloading = false; });
          setState(() {
            _isDownloading = false;
            _isSelectionMode = false;
            _selectedPaths.clear();
          });
        }
      }, onError: (e) {
        sink.close();
        if (mounted) {
          Navigator.pop(context);
          setState(() => _isDownloading = false);
        }
      });

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isDownloading = false);
      }
    }
  }

  String _getDateCategory(String? dateStr) {
    if (dateStr == null) return "Unknown";
    try {
      DateTime date = DateTime.parse(dateStr);
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime yesterday = today.subtract(const Duration(days: 1));
      DateTime thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      DateTime lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
      
      if (date.isAfter(today)) return "Today";
      if (date.isAfter(yesterday)) return "Yesterday";
      if (date.isAfter(thisWeekStart)) return "Earlier this week";
      if (date.isAfter(lastWeekStart)) return "Last week";
      if (date.year == now.year && date.month == now.month) return "Earlier this month";
      if (date.year == now.year && date.month == now.month - 1) return "Last month";
      if (date.year == now.year) return "Earlier this year";
      return "Long ago";
    } catch (e) {
      return "Unknown";
    }
  }

  Map<String, List<dynamic>> _getGroupedItems() {
    Map<String, List<dynamic>> groups = {};
    for (var item in _filteredItems) {
      String key = "Other";
      if (_groupBy == "Date") {
        key = _getDateCategory(item['modified']);
      } else if (_groupBy == "Type") {
        key = item['type'] == 'folder' ? "Folders" : (item['extension']?.toString().toUpperCase() ?? "Files");
      }
      
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(item);
    }
    return groups;
  }

  // --- NAVIGATION ---

  void _navigateToFolder(Map item) {
    // FLOW: Folder tap -> FileBrowserScreen (new path)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileBrowserScreen(
          pcIpAddress: widget.pcIpAddress,
          authToken: widget.authToken,
          initialPath: item['path'],
        ),
      ),
    );
  }

  void _navigateToFile(Map item) {
    // FLOW: File tap -> FilePreviewScreen
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => FilePreviewScreen(
        pcIpAddress: widget.pcIpAddress,
        authToken: widget.authToken,
        filePath: item['path'] ?? '',
        fileName: item['name'] ?? '',
        fileSize: (item['size'] ?? 0) as int,
        fileExtension: item['extension'] ?? (item['name'].toString().contains('.') ? ".${item['name'].toString().split('.').last}" : ""),
      ),
    ));
  }

  // --- DOWNLOAD LOGIC (Fallback) ---

  Future<void> _startDownload(Map file) async {
    Navigator.pop(context); // Close options sheet

    // Request Storage Permission
    if (Platform.isAndroid) {
      await PermissionService.requestAllPermissions();
    }

    late StateSetter setProgressState;
    setState(() => _isDownloading = true);

    _showDownloadSheet(file, (stateSetter) {
      setProgressState = stateSetter;
    });

    try {
      _downloadClient = http.Client();
      final request = http.Request('GET', Uri.parse("$_baseUrl/files/download/chunked?path=${Uri.encodeComponent(file['path'])}"));
      request.headers.addAll(_headers);

      final response = await _downloadClient!.send(request);
      final total = response.contentLength ?? 0;
      int received = 0;
      
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final saveFile = File("${dir.path}/${file['name']}");
      final IOSink sink = saveFile.openWrite();

      final stopwatch = Stopwatch()..start();

      _downloadSubscription = response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);

        final elapsed = stopwatch.elapsed.inSeconds;

        double progress = total > 0 ? (received / total) : 0;
        String speed = "0 KB/s";
        String time = "";

        if (elapsed > 0) {
          double mbps = (received / 1024 / 1024) / elapsed;
          speed = "${mbps.toStringAsFixed(1)} MB/s";
          if (mbps > 0) {
            int secondsLeft = ((total - received) / 1024 / 1024 / mbps).round();
            time = "About $secondsLeft seconds left";
          }
        }

        setProgressState(() {
          _downloadProgress = progress;
          _downloadSpeed = speed;
          _timeLeft = time;
        });

      }, onDone: () async {
        await sink.close();
        
        if (!_isDownloading) {
          if (await saveFile.exists()) await saveFile.delete();
          return;
        }

        // Notify Media Scanner
        if (Platform.isAndroid) {
          await MediaScanner.loadMedia(path: saveFile.path);
        }

        if (mounted) {
          setProgressState(() { _downloadProgress = 1.0; _isDownloading = false; });
          setState(() => _isDownloading = false);
        }
        _downloadClient?.close();
      }, onError: (e) async {
        await sink.close();
        if (await saveFile.exists()) await saveFile.delete();
        _downloadClient?.close();
        if (mounted) {
          Navigator.pop(context);
          setState(() => _isDownloading = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download Failed")));
      }, cancelOnError: true);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download Failed")));
      }
    }
  }

  void _cancelBrowserDownload() async {
    await _downloadSubscription?.cancel();
    _downloadClient?.close();
    try {
      http.post(Uri.parse("$_baseUrl/files/download/cancel"), headers: _headers);
    } catch (_) {}
    if (mounted) {
      setState(() => _isDownloading = false);
      Navigator.pop(context);
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildBreadcrumbs(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF6C63FF),
              child: _hasError
                  ? _buildErrorState()
                  : (_isLoading ? _buildShimmer() : (_isGridView ? _buildGrid() : _buildList())),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => setState(() {
            _isSelectionMode = false;
            _selectedPaths.clear();
          }),
        ),
        title: Text("${_selectedPaths.length} selected", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline, color: Color(0xFF6C63FF)),
            onPressed: _downloadSelected,
          ),
        ],
      );
    }
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context), // FLOW: Back arrow
      ),
      title: Text(widget.initialPath == null ? "Browser" : widget.initialPath!.split(Platform.pathSeparator).last, 
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white, size: 20),
          onPressed: () => setState(() => _isGridView = !_isGridView),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
          onSelected: (val) {
            setState(() {
              if (val.startsWith("group:")) {
                _groupBy = val.split(":").last;
              }
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: "group:None", child: Text("Don't Group")),
            const PopupMenuItem(value: "group:Date", child: Text("Group by Date")),
            const PopupMenuItem(value: "group:Type", child: Text("Group by Type")),
          ],
        ),
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) {
              _searchController.clear();
              _filteredItems = _items;
            }
          }),
        )
      ],
    );
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isSearching ? 70 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: _isSearching
          ? FadeInDown(
        duration: const Duration(milliseconds: 200),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearch,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Search files...",
            hintStyle: const TextStyle(color: Color(0xFF444444)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
          ),
        ),
      )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildBreadcrumbs() {
    List<String> parts = [];
    if (widget.initialPath != null) {
      parts = widget.initialPath!.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).toList();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.computer, size: 16, color: Color(0xFF6C63FF)),
            const SizedBox(width: 8),
            GestureDetector(
                onTap: () {
                  // FLOW: Breadcrumb tap (Root)
                  if(widget.initialPath != null) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: Text("PC", style: GoogleFonts.outfit(color: parts.isEmpty ? Colors.white : const Color(0xFF86868B)))
            ),
            if (parts.isNotEmpty)
              for (var i = 0; i < parts.length; i++) ...[
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFF2C2C2C)),
                GestureDetector(
                  onTap: () {
                    // FLOW: Breadcrumb level tap
                    int backSteps = parts.length - 1 - i;
                    for(int j = 0; j < backSteps; j++) Navigator.pop(context);
                  },
                  child: Text(
                    parts[i],
                    style: GoogleFonts.outfit(
                      color: i == parts.length - 1 ? Colors.white : const Color(0xFF86868B),
                      fontWeight: i == parts.length - 1 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_filteredItems.isEmpty) return _buildEmptyState();

    if (_groupBy != "None") {
      final groups = _getGroupedItems();
      final List<dynamic> flattenedItems = [];
      groups.forEach((key, items) {
        flattenedItems.add({'isHeader': true, 'headerName': key});
        flattenedItems.addAll(items);
      });

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        itemCount: flattenedItems.length,
        itemBuilder: (context, index) {
          final item = flattenedItems[index];
          if (item is Map && item['isHeader'] == true) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(item['headerName'], style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 13)),
            );
          }
          return _buildListItem(item);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return _buildListItem(_filteredItems[index]);
      },
    );
  }

  Widget _buildListItem(dynamic item) {
    bool isFolder = item['type'] == 'folder' || item['type'] == 'directory';
    bool isSelected = _selectedPaths.contains(item['path']);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          tileColor: isSelected ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.transparent,
          leading: _buildFileIcon(item['type'], item['name'], item['path']),
          title: Text(item['name'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
          subtitle: Text("${_formatSize(item['size'])} • ${item['modified'] ?? ''}", style: const TextStyle(color: Color(0xFF86868B), fontSize: 11)),
          trailing: _isSelectionMode 
            ? Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF2C2C2C))
            : IconButton(
                icon: Icon(isFolder ? Icons.chevron_right : Icons.more_vert, color: const Color(0xFF444444)),
                onPressed: isFolder ? null : () => _showOptionsSheet(item),
              ),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(item['path']);
            } else {
              isFolder ? _navigateToFolder(item) : _navigateToFile(item);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _enterSelectionMode(item['path']);
            } else {
              _handleDelete(item['path'], item['name']);
            }
          },
        ),
        const Divider(color: Color(0xFF1A1A1A), height: 1),
      ],
    );
  }

  Widget _buildGrid() {
    if (_filteredItems.isEmpty) return _buildEmptyState();

    if (_groupBy != "None") {
      final groups = _getGroupedItems();
      final sortedKeys = groups.keys.toList();
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sortedKeys.length,
        itemBuilder: (context, gIdx) {
          String key = sortedKeys[gIdx];
          List items = groups[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(key, style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.8,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => _buildGridItem(items[i]),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.8,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return _buildGridItem(_filteredItems[index]);
      },
    );
  }

  Widget _buildGridItem(dynamic item) {
    bool isFolder = item['type'] == 'folder' || item['type'] == 'directory';
    bool isSelected = _selectedPaths.contains(item['path']);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(item['path']);
        } else {
          isFolder ? _navigateToFolder(item) : _navigateToFile(item);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _enterSelectionMode(item['path']);
        } else {
          _handleDelete(item['path'], item['name']);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent, width: 2),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _buildFileIcon(item['type'], item['name'], item['path'], large: true),
                ),
                const SizedBox(height: 8),
                Text(
                  item['name'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (_isSelectionMode)
              Positioned(
                top: 8, right: 8,
                child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, 
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.white24, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  String _formatSize(dynamic size) {
    if (size == null || size == 0) return "";
    int bytes = (size is int) ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes == 0) return "";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  Widget _buildFileIcon(String type, String name, String path, {bool large = false}) {
    Color color = const Color(0xFF86868B);
    IconData icon = Icons.insert_drive_file;
    String ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    bool isImage = ['jpg', 'png', 'jpeg', 'gif', 'bmp'].contains(ext);
    bool isFolder = type == 'folder' || type == 'directory' || type == 'drive';

    if (isFolder) {
      color = const Color(0xFF6C63FF);
      icon = type == 'drive' ? Icons.storage_rounded : Icons.folder;
    } else {
      if (isImage) { color = Colors.greenAccent; icon = Icons.image; }
      else if (['mp4', 'mkv', 'mov'].contains(ext)) { color = Colors.blueAccent; icon = Icons.movie; }
      else if (['pdf'].contains(ext)) { color = Colors.redAccent; icon = Icons.picture_as_pdf; }
      else if (['zip', 'rar'].contains(ext)) { color = Colors.amberAccent; icon = Icons.archive; }
      else if (['exe', 'msi', 'apk'].contains(ext)) { color = Colors.orangeAccent; icon = Icons.terminal; }
      else if (['doc', 'docx', 'xlsx', 'xls', 'ppt', 'pptx'].contains(ext)) { color = Colors.lightBlueAccent; icon = Icons.description; }
    }

    // Windows Style Folder Peek
    if (isFolder && large) {
      return Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.1))),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 15, child: Icon(icon, color: color.withOpacity(0.2), size: 64)),
            Positioned(bottom: 25, child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSmallPeek(Colors.white24),
                const SizedBox(width: 4),
                _buildSmallPeek(Colors.white24),
              ],
            )),
          ],
        ),
      );
    }

    Widget iconWidget = Icon(icon, color: color, size: large ? 32 : 20);

    if (isImage) {
      iconWidget = Image.network(
        "$_baseUrl/files/thumbnail?path=${Uri.encodeComponent(path)}",
        headers: _headers,
        width: large ? double.infinity : 40,
        height: large ? double.infinity : 40,
        cacheWidth: large ? 300 : 120, // Optimization for memory
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(icon, color: color, size: large ? 32 : 20),
      );
      
      if (large) {
        iconWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: iconWidget,
        );
      } else {
        iconWidget = ClipOval(child: iconWidget);
      }
    }

    return Container(
      width: large ? double.infinity : 40,
      height: large ? double.infinity : 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: large ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: large ? BorderRadius.circular(12) : null,
      ),
      child: Center(child: iconWidget),
    );
  }

  Widget _buildSmallPeek(Color color) {
    return Container(width: 14, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)));
  }

  void _showOptionsSheet(Map item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(item['name'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 25),
            ListTile(
              leading: const Icon(Icons.file_download, color: Color(0xFF6C63FF)),
              title: const Text("Download to Phone", style: TextStyle(color: Colors.white)),
              onTap: () => _startDownload(item),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text("Delete from PC", style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _handleDelete(item['path'], item['name']);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showDownloadSheet(Map item, Function(StateSetter) onStateReady) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) {
            onStateReady(setSheetState);
            return Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_downloadProgress < 1.0) ...[
                    Text("Downloading File", style: GoogleFonts.outfit(color: Colors.white)),
                    const SizedBox(height: 15),
                    Text("${(_downloadProgress * 100).toInt()}%", style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 40, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(value: _downloadProgress, backgroundColor: Colors.white12, color: const Color(0xFF6C63FF), minHeight: 10),
                    ),
                    const SizedBox(height: 20),
                    if (_downloadProgress < 1.0)
                      TextButton(
                        onPressed: _cancelBrowserDownload,
                        child: const Text("Cancel Download", style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.bold)),
                      ),
                  ] else ...[
                    ZoomIn(child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 70)),
                    const SizedBox(height: 15),
                    const Text("Download Complete", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() { _downloadProgress = 0.0; }); // Reset for next
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: const StadiumBorder()),
                        child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2C2C2C),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 10,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.white, radius: 20),
              const SizedBox(width: 15),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 180, height: 12, color: Colors.white, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: 100, height: 8, color: Colors.white, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4))),
              ])
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("📂", style: TextStyle(fontSize: 50)),
          const SizedBox(height: 15),
          const Text("Folder is empty", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Go Back", style: TextStyle(color: Color(0xFF6C63FF)))
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 50),
            const SizedBox(height: 15),
            const Text("Connection Failed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Ensure the PC server is running", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 25),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                onPressed: _refresh,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: const StadiumBorder()
                ),
                child: const Text("Retry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}