import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class FilePreviewScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String fileExtension;

  const FilePreviewScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.fileExtension,
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  bool _isDownloading = false;
  String? _textContent;
  bool _isLoadingContent = false;

  @override
  void initState() {
    super.initState();
    _loadSpecialContent();
  }

  Future<void> _loadSpecialContent() async {
    final ext = widget.fileExtension.toLowerCase();
    if (['.txt', '.py', '.dart', '.js', '.json', '.css', '.html', '.md', '.yaml'].contains(ext)) {
      setState(() => _isLoadingContent = true);
      try {
        final url = 'http://${widget.pcIpAddress}:5000/files/preview?path=${Uri.encodeComponent(widget.filePath)}';
        final res = await http.get(Uri.parse(url), headers: {'X-Auth-Token': widget.authToken}).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          setState(() => _textContent = res.body);
        }
      } catch (_) {}
      setState(() => _isLoadingContent = false);
    }
  }

  Future<void> _downloadFile() async {
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.request().isGranted &&
          !await Permission.storage.request().isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Storage permission required")));
        return;
      }
    }

    setState(() => _isDownloading = true);
    try {
      final url = 'http://${widget.pcIpAddress}:5000/files/download?path=${Uri.encodeComponent(widget.filePath)}';
      final res = await http.get(Uri.parse(url), headers: {'X-Auth-Token': widget.authToken}).timeout(const Duration(minutes: 5));

      if (res.statusCode == 200) {
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
        } else {
          dir = await getDownloadsDirectory();
        }

        if (dir == null || !await dir.exists()) {
          dir = await getApplicationDocumentsDirectory();
        }

        final file = File('${dir.path}/${widget.fileName}');
        await file.writeAsBytes(res.bodyBytes);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved to Downloads"), backgroundColor: Color(0xFF10B981)));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download failed. PC rejected request."), backgroundColor: Colors.orange));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection lost during download"), backgroundColor: Colors.redAccent));
    }
    if (mounted) setState(() => _isDownloading = false);
  }

  Future<void> _shareFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${widget.fileName}');
    final url = 'http://${widget.pcIpAddress}:5000/files/download?path=${Uri.encodeComponent(widget.filePath)}';

    try {
      final res = await http.get(Uri.parse(url), headers: {'X-Auth-Token': widget.authToken}).timeout(const Duration(minutes: 5));
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
        await Share.shareXFiles([XFile(file.path)]);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unable to fetch file for sharing"), backgroundColor: Colors.orange));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection error"), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D141D) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        _buildPreviewCanvas(),
                        const SizedBox(height: 24),
                        _buildMetadataPanel(),
                        const SizedBox(height: 16),
                        _buildCollaboratorsPanel(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav(isDark)),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final accent = const Color(0xFF6C63FF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: Icon(Icons.arrow_back_rounded, color: accent), onPressed: () => Navigator.pop(context)),
              Text("CYPHER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
            ],
          ),
          const Icon(Icons.sensors_rounded, color: Color(0xFF6C63FF)),
        ],
      ),
    );
  }

  Widget _buildPreviewCanvas() {
    final accent = const Color(0xFF6C63FF);
    final imageUrl = 'http://${widget.pcIpAddress}:5000/files/preview?path=${Uri.encodeComponent(widget.filePath)}&token=${widget.authToken}';
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(widget.fileExtension.toLowerCase());

    return Container(
      height: 350, width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF192029).withOpacity(0.4), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: _isLoadingContent
              ? const CircularProgressIndicator()
              : (isImage
                  ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                      headers: {'X-Auth-Token': widget.authToken},
                      errorBuilder: (_, __, ___) => Icon(Icons.description_rounded, size: 80, color: accent.withOpacity(0.2)),
                    )
                  : (_textContent != null
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Text(_textContent!, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.white70)),
                        )
                      : Icon(Icons.description_rounded, size: 80, color: accent.withOpacity(0.2)))),
          ),
          Positioned(
            bottom: 20, left: 20,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Icon(isImage ? Icons.image_rounded : Icons.description_rounded, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Text(widget.fileName.toUpperCase(), style: GoogleFonts.roboto(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataPanel() {
    final accent = const Color(0xFF6C63FF);
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(widget.fileExtension.toLowerCase());

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("METADATA", style: GoogleFonts.roboto(fontSize: 10, color: accent, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(widget.fileName, style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildMetaItem("File Size", _formatSize(widget.fileSize)),
              _buildMetaItem("Type", widget.fileExtension.toUpperCase().replaceAll('.', '')),
              _buildMetaItem("Status", "Synced", isStatus: true),
              _buildMetaItem("Encryption", "AES-256"),
            ],
          ),
          
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Colors.white10)),
          
          if (isImage) ...[
            GestureDetector(
              onTap: () {
                final url = 'http://${widget.pcIpAddress}:5000/files/preview?path=${Uri.encodeComponent(widget.filePath)}&token=${widget.authToken}';
                Navigator.pushNamed(context, '/image_editor', arguments: {
                  'imageFile': url,
                  'pcIpAddress': widget.pcIpAddress,
                  'authToken': widget.authToken,
                });
              },
              child: _buildActionBtn("Edit Image", Icons.edit_rounded, Colors.orangeAccent, Colors.white, true),
            ),
            const SizedBox(height: 12),
          ],

          GestureDetector(
            onTap: _isDownloading ? null : _downloadFile,
            child: _buildActionBtn(_isDownloading ? "Syncing..." : "Save to Device", Icons.download_rounded, accent, Colors.white, !isImage),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: GestureDetector(onTap: _shareFile, child: _buildActionBtn("Share", Icons.share_rounded, const Color(0xFF404758), Colors.white, false))),
              const SizedBox(width: 12),
              Expanded(child: _buildActionBtn("Delete", Icons.delete_outline_rounded, Colors.redAccent.withOpacity(0.1), Colors.redAccent, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.roboto(fontSize: 8, color: Colors.white38)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (isStatus) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              Text(value, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color bg, Color text, bool shadow) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadow ? [BoxShadow(color: bg.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: text)),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsPanel() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("SHARED WITH", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 16),
          _buildUserRow("JD", "John Dorsey", "Lead Architect", const Color(0xFFDF7412)),
          _buildUserRow("AS", "Anna Sterling", "Security Ops", const Color(0xFF6C63FF)),
          const SizedBox(height: 16),
          TextButton.icon(onPressed: () {}, icon: const Icon(Icons.add_rounded, size: 18), label: Text("Invite collaborators", style: GoogleFonts.roboto(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildUserRow(String init, String name, String role, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: color.withOpacity(0.2), child: Text(init, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(role, style: GoogleFonts.roboto(fontSize: 11, color: Colors.white24)),
          ]),
          const Spacer(),
          Icon(Icons.more_vert_rounded, color: Colors.white.withOpacity(0.2), size: 18),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  Widget _buildBottomNav(bool isDark) {
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context), isDark),
          _navItem(Icons.folder_copy_rounded, "Files", true, null, isDark),
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
