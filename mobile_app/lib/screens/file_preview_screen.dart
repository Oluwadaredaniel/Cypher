import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
  // Transfer States
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;
  
  // Preview States
  String _textContent = "";
  bool _isLoadingText = false;
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    // Auto-load preview for text-based files
    if (_isTextFile) {
      _loadTextPreview();
    }
  }

  @override
  void dispose() {
    _client?.close(); // Cancel any ongoing requests
    super.dispose();
  }

  // --- GETTERS & HELPERS ---

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  
  String get _previewUrl => 
    "$_baseUrl/files/preview?path=${Uri.encodeComponent(widget.filePath)}";

  Map<String, String> get _headers => {
    "X-Auth-Token": widget.authToken,
    "Accept": "*/*",
  };

  bool get _isImage => ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']
      .contains(widget.fileExtension.toLowerCase());

  bool get _isTextFile => ['.txt', '.md', '.log', '.py', '.js', '.dart', '.json', '.css', '.html', '.yaml', '.xml']
      .contains(widget.fileExtension.toLowerCase());

  bool get _isCode => ['.py', '.js', '.dart', '.json', '.html', '.css', '.yaml', '.cpp', '.h']
      .contains(widget.fileExtension.toLowerCase());

  bool get _isVideo => ['.mp4', '.mkv', '.avi', '.mov', '.wmv']
      .contains(widget.fileExtension.toLowerCase());

  bool get _isAudio => ['.mp3', '.wav', '.flac', '.aac', '.m4a']
      .contains(widget.fileExtension.toLowerCase());

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  // --- LOGIC: TEXT PREVIEW ---

  Future<void> _loadTextPreview() async {
    if (!mounted) return;
    setState(() => _isLoadingText = true);
    
    try {
      final resp = await http.get(Uri.parse(_previewUrl), headers: _headers)
          .timeout(const Duration(seconds: 15));
          
      if (resp.statusCode == 200) {
        setState(() => _textContent = resp.body);
      } else {
        setState(() => _textContent = "This file type cannot be previewed.");
      }
    } catch (e) {
      setState(() => _textContent = "Unable to reach PC for preview.");
    } finally {
      if (mounted) setState(() => _isLoadingText = false);
    }
  }

  // --- LOGIC: CHUNKED DOWNLOAD ---

  Future<void> _downloadFile() async {
    if (_isDownloaded || _isDownloading) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // Check for available storage (Simplified check by catching error)
      _client = http.Client();
      final request = http.Request(
        'GET', 
        Uri.parse("$_baseUrl/files/download?path=${Uri.encodeComponent(widget.filePath)}")
      );
      
      request.headers.addAll(_headers);

      final response = await _client!.send(request).timeout(const Duration(minutes: 10));

      if (response.statusCode != 200) {
        throw Exception("Server Error: ${response.statusCode}");
      }

      final int total = response.contentLength ?? widget.fileSize;
      int received = 0;
      List<int> bytes = [];

      response.stream.listen(
        (List<int> chunk) {
          received += chunk.length;
          bytes.addAll(chunk);
          if (mounted) {
            setState(() {
              _downloadProgress = total > 0 ? (received / total) : 0.0;
            });
          }
        },
        onDone: () async {
          try {
            // Save to device storage
            final directory = Platform.isAndroid 
                ? Directory('/storage/emulated/0/Download') 
                : await getApplicationDocumentsDirectory();
            
            final file = File("${directory.path}/${widget.fileName}");
            await file.writeAsBytes(bytes);

            if (mounted) {
              setState(() {
                _isDownloading = false;
                _isDownloaded = true;
                _downloadProgress = 1.0;
              });
              HapticFeedback.heavyImpact();
              _showSuccess("File saved to Downloads");
            }
          } catch (e) {
            _showError("Storage error: Make sure you have enough free space.");
            _resetDownloadState();
          }
          _client?.close();
        },
        onError: (e) {
          _showError("Transfer failed: Connection lost.");
          _resetDownloadState();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _showError("Failed to initiate download.");
      _resetDownloadState();
    }
  }

  void _resetDownloadState() {
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
    _client?.close();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF6C63FF), behavior: SnackBarBehavior.floating),
    );
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isImage ? Colors.black : const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          Positioned.fill(child: _buildPreviewContent()),
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 16, right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              widget.fileName,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
            onPressed: () {}, // Future Share Implementation
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 24, 
        right: 24, 
        bottom: MediaQuery.of(context).padding.bottom + 20, 
        top: 20
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatBytes(widget.fileSize), style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(widget.fileExtension.toUpperCase(), style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
            ],
          ),
          const Spacer(),
          _buildDownloadButton(),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return GestureDetector(
      onTap: _downloadFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 54,
        width: _isDownloaded ? 130 : 190,
        decoration: BoxDecoration(
          color: _isDownloaded ? const Color(0xFF30D158) : const Color(0xFF6C63FF),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: (_isDownloaded ? Colors.green : const Color(0xFF6C63FF)).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isDownloading)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.2)),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isDownloaded) ZoomIn(child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20)),
                if (!_isDownloading && !_isDownloaded) const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                if (_isDownloaded || (!_isDownloading)) const SizedBox(width: 10),
                Text(
                  _isDownloading 
                      ? "${(_downloadProgress * 100).toInt()}%" 
                      : _isDownloaded ? "Saved" : "Save to Phone",
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (_isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: FadeIn(
          child: Image.network(
            _previewUrl,
            headers: _headers,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null 
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! 
                    : null,
                  color: const Color(0xFF6C63FF),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => _buildPlaceholderCard(Icons.broken_image_outlined, "Image too large or invalid"),
          ),
        ),
      );
    }

    if (_isTextFile) {
      return Container(
        color: const Color(0xFF0D0D0D),
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 100, 20, 120),
        child: _isLoadingText 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                _textContent.isEmpty ? "No content to display." : _textContent,
                style: GoogleFonts.firaCode(
                  color: const Color(0xFFE0E0E0),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
      );
    }

    // Default Fallbacks for non-previewable files
    if (_isVideo) return _buildPlaceholderCard(Icons.play_circle_outline_rounded, "Video preview not supported yet");
    if (_isAudio) return _buildPlaceholderCard(Icons.music_note_outlined, "Audio preview coming soon", isAudio: true);
    if (widget.fileExtension.toLowerCase() == ".pdf") return _buildPlaceholderCard(Icons.picture_as_pdf_outlined, "PDFs must be downloaded", color: Colors.redAccent);

    return _buildPlaceholderCard(Icons.insert_drive_file_outlined, "Preview not available for this file type");
  }

  Widget _buildPlaceholderCard(IconData icon, String message, {bool isAudio = false, Color color = const Color(0xFF6C63FF)}) {
    return Center(
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isAudio ? color.withOpacity(0.1) : const Color(0xFF1A1A1A),
                shape: isAudio ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isAudio ? null : BorderRadius.circular(28),
                border: Border.all(color: color.withOpacity(0.2), width: 2),
              ),
              child: Icon(icon, color: color, size: 60),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Text(
                widget.fileName, 
                textAlign: TextAlign.center, 
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
            const SizedBox(height: 10),
            Text(message, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}