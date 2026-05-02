import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'file_preview_screen.dart'; // IMPORTED FOR FLOW

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
  final TextEditingController _searchController = TextEditingController();

  // Download State
  double _downloadProgress = 0.0;
  String _downloadSpeed = "0 KB/s";
  String _timeLeft = "";

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      final response = await http.get(Uri.parse("$_baseUrl/files"), headers: _headers);
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
      );
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
        final url = Uri.parse("$_baseUrl/files?path=${Uri.encodeComponent(path)}");
        final response = await http.delete(url, headers: _headers);
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

    late StateSetter setProgressState;

    _showDownloadSheet(file, (stateSetter) {
      setProgressState = stateSetter;
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse("$_baseUrl/files/download?path=${Uri.encodeComponent(file['path'])}"));
      request.headers.addAll(_headers);

      final response = await client.send(request);
      final total = response.contentLength ?? 0;
      int received = 0;
      List<int> bytes = [];

      final stopwatch = Stopwatch()..start();

      response.stream.listen((chunk) {
        received += chunk.length;
        bytes.addAll(chunk);

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
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        final saveFile = File("${dir.path}/${file['name']}");
        await saveFile.writeAsBytes(bytes);

        if (mounted) {
          setProgressState(() { _downloadProgress = 1.0; });
        }
        client.close();
      }, onError: (e) {
        client.close();
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download Failed")));
      }, cancelOnError: true);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download Failed")));
      }
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
                  : (_isLoading ? _buildShimmer() : _buildList()),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredItems.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFF1A1A1A), height: 1),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        bool isFolder = item['type'] == 'folder' || item['type'] == 'directory';
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index * 10),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _buildFileIcon(item['type'], item['name']),
            title: Text(item['name'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
            subtitle: Text("${item['size'] ?? ''} • ${item['modified'] ?? ''}", style: const TextStyle(color: Color(0xFF86868B), fontSize: 11)),
            trailing: IconButton(
              icon: Icon(isFolder ? Icons.chevron_right : Icons.more_vert, color: const Color(0xFF444444)),
              onPressed: isFolder ? null : () => _showOptionsSheet(item),
            ),
            onTap: () => isFolder ? _navigateToFolder(item) : _navigateToFile(item),
            onLongPress: () => _handleDelete(item['path'], item['name']),
          ),
        );
      },
    );
  }

  Widget _buildFileIcon(String type, String name) {
    Color color = const Color(0xFF86868B);
    IconData icon = Icons.insert_drive_file;
    String ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

    if (type == 'folder' || type == 'directory') {
      color = const Color(0xFF6C63FF);
      icon = Icons.folder;
    } else {
      if (['jpg', 'png', 'jpeg', 'gif'].contains(ext)) { color = Colors.greenAccent; icon = Icons.image; }
      else if (['mp4', 'mkv', 'mov'].contains(ext)) { color = Colors.blueAccent; icon = Icons.movie; }
      else if (['pdf'].contains(ext)) { color = Colors.redAccent; icon = Icons.picture_as_pdf; }
      else if (['zip', 'rar'].contains(ext)) { color = Colors.amberAccent; icon = Icons.archive; }
    }

    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_downloadSpeed, style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
                        Text(_timeLeft, style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
                      ],
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