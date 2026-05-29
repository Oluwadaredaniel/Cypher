import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class SendToPCScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final dynamic preSelectedFile;
  final List<String>? sharedFiles;

  const SendToPCScreen({super.key, required this.pcIpAddress, required this.authToken, this.preSelectedFile, this.sharedFiles});

  @override
  State<SendToPCScreen> createState() => _SendToPCScreenState();
}

class _SendToPCScreenState extends State<SendToPCScreen> {
  List<PlatformFile> _selectedFiles = [];
  String _targetDirectory = "Downloads";
  bool _isUploading = false;
  String _pcName = "My Computer";

  @override
  void initState() {
    super.initState();
    _fetchPCInfo();
    if (widget.sharedFiles != null && widget.sharedFiles!.isNotEmpty) {
      // Handle files shared via intent
    }
  }

  Future<void> _fetchPCInfo() async {
    try {
      final res = await http.get(Uri.parse('http://${widget.pcIpAddress}:5000/status'), headers: {'X-Auth-Token': widget.authToken});
      if (res.statusCode == 200) {
        setState(() => _pcName = jsonDecode(res.body)['pc_name'] ?? "My Computer");
      }
    } catch (_) {}
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() => _selectedFiles = result.files);
    }
  }

  void _showDestinationPicker() {
    String currentPath = ""; // Root
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PCDirectoryPicker(
        pcIpAddress: widget.pcIpAddress,
        authToken: widget.authToken,
        onSelected: (path) {
          setState(() => _targetDirectory = path);
        },
      ),
    );
  }

  Future<void> _startUpload() async {
    if (_selectedFiles.isEmpty) return;
    setState(() => _isUploading = true);

    try {
      final baseUrl = 'http://${widget.pcIpAddress}:5000';

      // Upload files one by one or in a batch?
      // The current backend /files/upload supports multiple files in one request.
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/files/upload'));
      request.headers['X-Auth-Token'] = widget.authToken;
      request.fields['destination'] = _targetDirectory;

      for (var file in _selectedFiles) {
        if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath('file', file.path!));
        } else if (file.bytes != null) {
          // Handle web/bytes if necessary
          request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
        }
      }

      final response = await request.send().timeout(const Duration(minutes: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Successfully sent ${_selectedFiles.length} files to PC"),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.pushReplacementNamed(context, '/transfers', arguments: {
            'pcIpAddress': widget.pcIpAddress,
            'authToken': widget.authToken,
          });
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed. Check PC storage."), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection error during upload"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: theme.isDarkMode ? const Color(0xFF080F17) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildConnectionBanner(),
                        const SizedBox(height: 24),
                        _buildUploadArea(),
                        const SizedBox(height: 24),
                        _buildTargetSelector(),
                        const SizedBox(height: 24),
                        _buildRecentLocations(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedFiles.isNotEmpty)
            Positioned(
              bottom: 110, right: 24,
              child: FadeInRight(
                child: FloatingActionButton.extended(
                  onPressed: _startUpload,
                  backgroundColor: accent,
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text("Send ${_selectedFiles.length} Files", style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                ),
              ),
            ),

          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav(theme.isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF6C63FF), size: 20), onPressed: () => Navigator.pop(context)),
              Text("SEND TO PC", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF6C63FF), letterSpacing: -1)),
            ],
          ),
          const Icon(Icons.sensors_rounded, color: Color(0xFF6C63FF)),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text("CONNECTED TO: $_pcName", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white38, letterSpacing: 1)),
          const Spacer(),
          Text("FAST SYNC", style: GoogleFonts.roboto(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    final accent = const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: _pickFiles,
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.upload_file_rounded, color: accent, size: 40),
            ),
            const SizedBox(height: 24),
            Text("Select files to send", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Tap to browse your device storage", style: GoogleFonts.roboto(fontSize: 13, color: Colors.white24)),

            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              ..._selectedFiles.take(3).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded, size: 16, color: Colors.white24),
                    const SizedBox(width: 12),
                    Expanded(child: Text(f.name, style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis)),
                    Text("${(f.size / 1024 / 1024).toStringAsFixed(1)} MB", style: GoogleFonts.roboto(fontSize: 9, color: Colors.white10)),
                  ],
                ),
              )),
              if (_selectedFiles.length > 3)
                Text("+ ${_selectedFiles.length - 3} more files", style: GoogleFonts.roboto(fontSize: 11, color: accent.withOpacity(0.5))),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelector() {
    return GestureDetector(
      onTap: _showDestinationPicker,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFB786).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.folder_open_rounded, color: Color(0xFFFFB786), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SEND TO", style: GoogleFonts.roboto(fontSize: 8, color: Colors.white24, letterSpacing: 1)),
                  Text(_targetDirectory, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLocations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text("RECENT LOCATIONS", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white24, letterSpacing: 1)),
        ),
        _recentItem("Desktop/Downloads", "2m ago"),
        const SizedBox(height: 12),
        _recentItem("Projects/Alpha/Renders", "System default"),
      ],
    );
  }

  Widget _recentItem(String path, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Colors.white10, size: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(path, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(label, style: GoogleFonts.roboto(fontSize: 11, color: Colors.white10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", true, null, isDark),
          _navItem(Icons.folder_copy_rounded, "Files", false, () => Navigator.pushReplacementNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
          _navItem(Icons.grid_view_rounded, "Tools", false, () => Navigator.pushReplacementNamed(context, '/controls', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
          _navItem(Icons.tune_rounded, "Settings", false, () => Navigator.pushReplacementNamed(context, '/settings', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, [VoidCallback? tap, bool isDark = true]) {
    final accent = const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: tap,
      child: Opacity(
        opacity: active ? 1.0 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? accent : (isDark ? Colors.white : Colors.black), size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: active ? accent : (isDark ? Colors.white : Colors.black))),
          ],
        ),
      ),
    );
  }
}

class _PCDirectoryPicker extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final Function(String) onSelected;

  const _PCDirectoryPicker({required this.pcIpAddress, required this.authToken, required this.onSelected});

  @override
  State<_PCDirectoryPicker> createState() => _PCDirectoryPickerState();
}

class _PCDirectoryPickerState extends State<_PCDirectoryPicker> {
  List<dynamic> _contents = [];
  String _currentPath = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDir(_currentPath);
  }

  Future<void> _fetchDir(String path) async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/files/list?path=${Uri.encodeComponent(path)}'),
        headers: {'X-Auth-Token': widget.authToken},
      );
      if (res.statusCode == 200) {
        setState(() {
          _contents = jsonDecode(res.body)['contents'];
          _currentPath = path;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("PICK DESTINATION", style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white24)),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentPath.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981)),
              title: Text("Select this folder", style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text(_currentPath, style: const TextStyle(fontSize: 10, color: Colors.white24)),
              onTap: () {
                widget.onSelected(_currentPath);
                Navigator.pop(context);
              },
            ),
          if (_currentPath.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF6C63FF)),
              title: const Text("..", style: TextStyle(color: Colors.white)),
              onTap: () {
                final parts = _currentPath.split(Platform.isWindows ? '\\' : '/');
                parts.removeLast();
                _fetchDir(parts.join(Platform.isWindows ? '\\' : '/'));
              },
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _contents.length,
                  itemBuilder: (ctx, i) {
                    final item = _contents[i];
                    return ListTile(
                      leading: Icon(item['is_dir'] ? Icons.folder_rounded : Icons.description_rounded, color: item['is_dir'] ? const Color(0xFFFFB786) : Colors.white24),
                      title: Text(item['name'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      onTap: () {
                        if (item['is_dir']) {
                          _fetchDir(item['path']);
                        }
                      },
                      trailing: item['is_dir'] ? TextButton(
                        onPressed: () {
                          widget.onSelected(item['path']);
                          Navigator.pop(context);
                        },
                        child: const Text("SELECT", style: TextStyle(fontWeight: FontWeight.bold)),
                      ) : null,
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
