import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'phone_browser_screen.dart';

enum UploadState { picking, uploading, success, error }

class SendToPCScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final File? preSelectedFile;

  const SendToPCScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
    this.preSelectedFile,
  });

  @override
  State<SendToPCScreen> createState() => _SendToPCScreenState();
}

class _SendToPCScreenState extends State<SendToPCScreen> with TickerProviderStateMixin {
  // Logic State
  UploadState _currentState = UploadState.picking;
  PlatformFile? _selectedFile;
  File? _directFile;
  String? _selectedDestination;
  String _currentPath = ""; // Empty string represents Root
  List<dynamic> _folders = [];
  bool _isLoadingFolders = false;

  // Upload Tracking
  double _uploadProgress = 0.0;
  String _uploadSpeed = "0 MB/s";
  String _timeLeft = "Calculating...";

  // Animation Controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {"X-Auth-Token": widget.authToken};

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedFile != null) {
      _directFile = widget.preSelectedFile;
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // --- API LOGIC ---

  Future<void> _fetchFolders([String? path]) async {
    if (!mounted) return;
    setState(() => _isLoadingFolders = true);
    try {
      final uri = (path == null || path.isEmpty)
          ? Uri.parse("$_baseUrl/files")
          : Uri.parse("$_baseUrl/files/browse?path=${Uri.encodeComponent(path)}");

      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _folders = data.where((item) => item['type'] == 'folder').toList();
          if (path != null) _currentPath = path;
          _isLoadingFolders = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFolders = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _uploadFile() async {
    if ((_selectedFile == null && _directFile == null) || _selectedDestination == null) return;

    setState(() {
      _currentState = UploadState.uploading;
      _uploadProgress = 0.0;
    });

    try {
      final String filePath = _directFile?.path ?? _selectedFile!.path!;
      final file = File(filePath);
      
      final request = http.MultipartRequest('POST', Uri.parse("$_baseUrl/files/upload"));
      request.headers.addAll(_headers);
      request.fields['destination'] = _selectedDestination!;

      final multipartFile = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(multipartFile);

      final response = await request.send();

      if (response.statusCode == 200) {
        _triggerSuccess();
      } else {
        setState(() => _currentState = UploadState.error);
      }
    } catch (e) {
      setState(() => _currentState = UploadState.error);
    }
  }

  void _triggerSuccess() {
    if (!mounted) return;
    setState(() {
      _uploadProgress = 1.0;
      _currentState = UploadState.success;
    });
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Send to PC", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildCurrentStateUI(),
        ),
      ),
    );
  }

  Widget _buildCurrentStateUI() {
    switch (_currentState) {
      case UploadState.picking:
        return _buildPickingState();
      case UploadState.uploading:
        return _buildUploadingState();
      case UploadState.success:
        return _buildSuccessState();
      case UploadState.error:
        return _buildErrorState();
    }
  }

  Widget _buildPickingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildUploadArea(),
        const SizedBox(height: 32),
        Text("Where should it go?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text("Pick a folder on your PC", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 13)),
        const SizedBox(height: 16),
        _buildDestinationSelector(),
        const Spacer(),
        _buildSendButton(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildUploadArea() {
    if (_selectedFile != null || _directFile != null) {
      final String name = _directFile != null ? p.basename(_directFile!.path) : _selectedFile!.name;
      final int size = _directFile != null ? _directFile!.lengthSync() : _selectedFile!.size;
      
      return FadeIn(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2C2C2C))
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.insert_drive_file, color: Color(0xFF6C63FF), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                    Text("${(size / 1024 / 1024).toStringAsFixed(2)} MB", style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF6C63FF), size: 20),
                onPressed: () {
                  setState(() { _selectedFile = null; _directFile = null; });
                  _pickFile();
                },
              )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _pickFile,
          child: FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("📤", style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 16),
                  Text("Choose a file to send", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Photos, videos, or documents", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) => PhoneBrowserScreen(pcIpAddress: widget.pcIpAddress, authToken: widget.authToken),
          )),
          icon: const Icon(Icons.folder_shared_rounded, color: Color(0xFF6C63FF)),
          label: Text("Browse Phone Storage (Hidden Files)", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF))),
        )
      ],
    );
  }

  Widget _buildDestinationSelector() {
    String folderName = _selectedDestination == null || _selectedDestination == ""
        ? "Choose destination"
        : p.basename(_selectedDestination!);

    return InkWell(
      onTap: _showDestinationSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _selectedDestination != null ? const Color(0xFF6C63FF) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_open, color: _selectedDestination != null ? const Color(0xFF6C63FF) : const Color(0xFF86868B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                folderName,
                style: TextStyle(color: _selectedDestination != null ? Colors.white : const Color(0xFF86868B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF86868B)),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    bool isActive = _selectedFile != null && _selectedDestination != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isActive ? _uploadFile : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF6C63FF) : const Color(0xFF1A1A1A),
          shape: const StadiumBorder(),
          elevation: isActive ? 8 : 0,
          shadowColor: const Color(0xFF6C63FF).withOpacity(0.5),
        ),
        child: Text(
            "Send to PC",
            style: GoogleFonts.outfit(
                color: isActive ? Colors.white : Colors.white24,
                fontWeight: FontWeight.bold,
                fontSize: 16
            )
        ),
      ),
    );
  }

  // --- DESTINATION SHEET ---

  void _showDestinationSheet() {
    _fetchFolders();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Select Folder", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (_currentPath.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, color: Color(0xFF6C63FF), size: 20),
                          onPressed: () async {
                            // Simple parent path logic
                            List<String> parts = _currentPath.split(RegExp(r'[/\\]'));
                            parts.removeLast();
                            String parent = parts.join(Platform.isWindows ? "\\" : "/");
                            await _fetchFolders(parent);
                            setSheetState(() {});
                          },
                        )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_currentPath.isEmpty ? "Root Directory" : _currentPath, style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoadingFolders
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                        : _folders.isEmpty
                        ? const Center(child: Text("No folders found", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                      itemCount: _folders.length,
                      itemBuilder: (context, index) {
                        final folder = _folders[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.05), shape: BoxShape.circle),
                            child: const Icon(Icons.folder, color: Color(0xFF6C63FF), size: 20),
                          ),
                          title: Text(folder['name'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFF2C2C2C)),
                          onTap: () async {
                            await _fetchFolders(folder['path']);
                            setSheetState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedDestination = _currentPath);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: const StadiumBorder()),
                      child: const Text("Select current folder", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  )
                ],
              ),
            );
          }
      ),
    );
  }

  // --- UPLOAD, SUCCESS, ERROR STATES ---

  Widget _buildUploadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140, height: 140,
              child: CircularProgressIndicator(
                  value: _uploadProgress == 0 ? null : _uploadProgress,
                  strokeWidth: 6,
                  color: const Color(0xFF6C63FF),
                  backgroundColor: Colors.white10
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${(_uploadProgress * 100).toInt()}%", style: GoogleFonts.outfit(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                const Text("Uploading", style: TextStyle(color: Color(0xFF86868B), fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text(_selectedFile!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(100)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(_uploadSpeed, style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
              const SizedBox(width: 16),
              const Icon(Icons.timer_outlined, color: Color(0xFF6C63FF), size: 16),
              const SizedBox(width: 4),
              Text(_timeLeft, style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 40),
        TextButton(
            onPressed: () => setState(() => _currentState = UploadState.picking),
            child: const Text("Cancel Upload", style: TextStyle(color: Colors.redAccent, fontSize: 14))
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ZoomIn(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6C63FF), width: 2)
              ),
              child: const Icon(Icons.check, color: Color(0xFF6C63FF), size: 50),
            ),
          ),
          const SizedBox(height: 32),
          Text("File sent successfully", style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Sent to: ${p.basename(_selectedDestination ?? 'Root')}", style: const TextStyle(color: Color(0xFF86868B))),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: () => setState(() { _selectedFile = null; _currentState = UploadState.picking; }),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: const StadiumBorder()),
              child: const Text("Send another file", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done", style: TextStyle(color: Color(0xFF86868B)))),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShakeX(
            child: Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 80),
          ),
          const SizedBox(height: 24),
          Text("Upload failed", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text("We couldn't reach your PC. Please check if the server is still running.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF86868B))),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _uploadFile,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: const StadiumBorder()),
              child: const Text("Try again", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: () => setState(() => _currentState = UploadState.picking), child: const Text("Pick another file", style: TextStyle(color: Color(0xFF86868B)))),
        ],
      ),
    );
  }
}