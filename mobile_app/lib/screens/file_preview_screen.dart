import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import '../services/permission_service.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:ui';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

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
  String? _downloadedPath;

  // Media Players
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Auto-load preview for text-based files
    if (_isTextFile) {
      _loadTextPreview();
    } else if (_isVideo) {
      _initVideoPlayer();
    } else if (_isAudio) {
      _initAudioPlayer();
    }
  }

  @override
  void dispose() {
    _client?.close();
    _videoController?.dispose();
    _chewieController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- LOGIC: MEDIA PLAYERS ---

  void _initVideoPlayer() {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(_previewUrl),
      httpHeaders: _headers,
    );

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      aspectRatio: 16 / 9,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      placeholder: Container(color: Colors.black),
      errorBuilder: (context, errorMessage) {
        return _buildPlaceholderCard(Icons.error_outline, "Error playing video");
      },
    );
  }

  void _initAudioPlayer() async {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() {});
    });
    _audioPlayer.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _audioDuration = d);
    });
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
    
    try {
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(_previewUrl), headers: _headers),
      );
    } catch (e) {
      debugPrint("Audio preview failed: $e");
    }
  }

  void _toggleAudio() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
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

  bool get _isTextFile => ['.txt', '.md', '.log', '.py', '.js', '.dart', '.json', '.css', '.html', '.yaml', '.xml', '.c', '.cpp', '.h', '.java', '.kt', '.swift', '.go', '.rb', '.php', '.sql']
      .contains(widget.fileExtension.toLowerCase());

  bool get _isCode => ['.py', '.js', '.dart', '.json', '.html', '.css', '.yaml', '.c', '.cpp', '.h', '.java', '.kt', '.swift', '.go', '.rb', '.php', '.sql']
      .contains(widget.fileExtension.toLowerCase());

  bool get _isPdf => widget.fileExtension.toLowerCase() == '.pdf';

  bool get _canOpenDirectly => ['.apk', '.exe', '.msi', '.docx', '.xlsx', '.pptx', '.zip', '.rar']
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

    // Request Storage Permission first
    if (Platform.isAndroid) {
      await PermissionService.requestAllPermissions();
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      _client = http.Client();
      final request = http.Request(
        'GET', 
        Uri.parse("$_baseUrl/files/download/chunked?path=${Uri.encodeComponent(widget.filePath)}")
      );
      
      request.headers.addAll(_headers);

      final response = await _client!.send(request).timeout(const Duration(minutes: 60));

      if (response.statusCode != 200) {
        throw Exception("Server Error: ${response.statusCode}");
      }

      final int total = response.contentLength ?? widget.fileSize;
      int received = 0;
      
      // STREAM DIRECTLY TO FILE (Avoid OOM)
      final directory = Platform.isAndroid 
          ? Directory('/storage/emulated/0/Download') 
          : await getApplicationDocumentsDirectory();
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File("${directory.path}/${widget.fileName}");
      final IOSink sink = file.openWrite();

      final streamSubscription = response.stream.listen(
        (List<int> chunk) {
          received += chunk.length;
          sink.add(chunk);
          if (mounted) {
            setState(() {
              _downloadProgress = total > 0 ? (received / total) : 0.0;
            });
          }
        },
        onDone: () async {
          await sink.close();
          
          if (received < total && total > 0 && _isDownloading) {
            _showError("Transfer incomplete: Connection interrupted.");
            if (await file.exists()) await file.delete();
            _resetDownloadState();
            return;
          }
          
          if (!_isDownloading) {
            if (await file.exists()) await file.delete();
            return;
          }

          try {
            // CRITICAL: Notify Android Media Scanner (Multi-Method Deep Scan)
            if (Platform.isAndroid) {
              // Method 1: Standard Plugin Scan
              await MediaScanner.loadMedia(path: file.path);
              
              // Method 2: Direct MethodChannel Broadcast (Forces 'Recents' update)
              try {
                const platform = MethodChannel('com.cypher.app/media_scan');
                await platform.invokeMethod('scanFile', {'path': file.path});
              } catch (_) {
                // Method 3: Fallback Flutter legacy channel
                try {
                  const MethodChannel('flutter.io/media_scanner').invokeMethod('scanFile', {'path': file.path});
                } catch (_) {}
              }
              
              debugPrint("Deep Scan Completed for: ${file.path}");
            }

            if (mounted) {
              setState(() {
                _isDownloading = false;
                _isDownloaded = true;
                _downloadProgress = 1.0;
                _downloadedPath = file.path;
              });
              HapticFeedback.heavyImpact();
              _showSuccess("Saved to Downloads");

              // Auto-open if it's a file we can't preview but can open locally
              if (_canOpenDirectly) {
                _openDownloadedFile();
              }
            }
          } catch (e) {
            _showError("Storage error: Make sure you have enough free space.");
            _resetDownloadState();
          }
          _client?.close();
        },
        onError: (e) async {
          await sink.close();
          if (await file.exists()) await file.delete();
          _showError("Transfer failed: Connection lost.");
          _resetDownloadState();
        },
        cancelOnError: true,
      );

      // Store subscription for cancellation
      _currentSubscription = streamSubscription;

    } catch (e) {
      _showError("Failed to initiate download.");
      _resetDownloadState();
    }
  }

  StreamSubscription? _currentSubscription;

  void _cancelDownload() async {
    if (!_isDownloading) return;
    
    // Stop local stream
    await _currentSubscription?.cancel();
    _client?.close();
    
    // Notify PC server to stop the stream worker if possible
    try {
      http.post(Uri.parse("$_baseUrl/files/download/cancel"), headers: _headers);
    } catch (_) {}

    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
    });
    _showError("Download cancelled.");
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

  void _shareFile() async {
    if (_isDownloaded && _downloadedPath != null) {
      await Share.shareXFiles([XFile(_downloadedPath!)], text: widget.fileName);
    } else {
      _showToast("Save to phone first to share.");
    }
  }

  void _openDownloadedFile() {
    final path = _downloadedPath;
    if (path == null) return;

    OpenFilex.open(path);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            onPressed: _shareFile,
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
    return Row(
      children: [
        if (_isDownloading)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _cancelDownload,
              child: Container(
                height: 54, width: 54,
                decoration: BoxDecoration(color: const Color(0xFFFF453A).withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.3))),
                child: const Icon(Icons.close_rounded, color: Color(0xFFFF453A), size: 24),
              ),
            ),
          ),
        Expanded(
          child: GestureDetector(
            onTap: _isDownloading ? null : _downloadFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 54,
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
          ),
        ),
      ],
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

    if (_isPdf) {
      return Container(
        padding: const EdgeInsets.only(top: 80, bottom: 100),
        child: SfPdfViewer.network(
          _previewUrl,
          headers: _headers,
          canShowScrollHead: true,
          canShowScrollStatus: true,
        ),
      );
    }

    if (_isVideo && _chewieController != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    if (_isAudio) {
      return _buildAudioPlayerUI();
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
              child: _isCode 
                ? HighlightView(
                    _textContent.isEmpty ? "No content to display." : _textContent,
                    language: widget.fileExtension.replaceAll('.', ''),
                    theme: atomOneDarkTheme,
                    padding: const EdgeInsets.all(12),
                    textStyle: GoogleFonts.firaCode(fontSize: 12),
                  )
                : SelectableText(
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
    if (_canOpenDirectly) {
      return _buildPlaceholderCard(
        _isDownloaded ? Icons.open_in_new_rounded : Icons.file_download_outlined, 
        _isDownloaded ? "Tap below to open" : "Download to open on your phone",
        color: _isDownloaded ? const Color(0xFF30D158) : const Color(0xFF6C63FF)
      );
    }

    return _buildPlaceholderCard(Icons.insert_drive_file_outlined, "Preview not available for this file type");
  }

  Widget _buildAudioPlayerUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Vinyl Effect
          Pulse(
            infinite: _audioPlayer.playing,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.2), blurRadius: 40, spreadRadius: 5)
                ]
              ),
              child: const Center(child: Icon(Icons.music_note, color: Color(0xFF6C63FF), size: 80)),
            ),
          ),
          const SizedBox(height: 50),
          Text(widget.fileName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          // Progress
          Slider(
            value: _audioPosition.inSeconds.toDouble(),
            max: _audioDuration.inSeconds.toDouble() > 0 ? _audioDuration.inSeconds.toDouble() : 1.0,
            onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
            activeColor: const Color(0xFF6C63FF),
            inactiveColor: Colors.white12,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_audioPosition), style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
                Text(_formatDuration(_audioDuration), style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => _audioPlayer.seek(Duration(seconds: _audioPosition.inSeconds - 10)), icon: const Icon(Icons.replay_10, color: Colors.white, size: 32)),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: _toggleAudio,
                child: Container(
                  width: 70, height: 70,
                  decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                  child: Icon(_audioPlayer.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(width: 20),
              IconButton(onPressed: () => _audioPlayer.seek(Duration(seconds: _audioPosition.inSeconds + 10)), icon: const Icon(Icons.forward_10, color: Colors.white, size: 32)),
            ],
          )
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
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