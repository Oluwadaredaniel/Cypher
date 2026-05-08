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
  List<PlatformFile> _selectedFiles = [];
  File? _directFile;
  String? _selectedDestination;
  String _currentPath = ""; // Empty string represents Root
  List<dynamic> _folders = [];
  bool _isLoadingFolders = false;

  // Upload Tracking
  double _uploadProgress = 0.0;
  int _currentFileIndex = 0;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController);

    if (widget.preSelectedFile != null) {
      _directFile = widget.preSelectedFile;
    }
    _loadFolders();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {"X-Auth-Token": widget.authToken};

  Future<void> _loadFolders() async {
    setState(() => _isLoadingFolders = true);
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/files/list?path=$_currentPath"),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _folders = data['contents'].where((item) => item['is_dir'] == true).toList();
          _isLoadingFolders = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingFolders = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _selectedFiles = result.files;
        _directFile = null;
      });
    }
  }

  Future<void> _uploadFile() async {
    if ((_selectedFiles.isEmpty && _directFile == null) || _selectedDestination == null) return;

    setState(() {
      _currentState = UploadState.uploading;
      _uploadProgress = 0.0;
      _currentFileIndex = 0;
    });

    try {
      if (_directFile != null) {
        await _uploadSingleFile(_directFile!.path);
      } else {
        for (int i = 0; i < _selectedFiles.length; i++) {
          setState(() => _currentFileIndex = i);
          await _uploadSingleFile(_selectedFiles[i].path!);
        }
      }
      _triggerSuccess();
    } catch (e) {
      setState(() => _currentState = UploadState.error);
    }
  }

  Future<void> _uploadSingleFile(String path) async {
    final request = http.MultipartRequest('POST', Uri.parse("$_baseUrl/files/upload"));
    request.headers.addAll(_headers);
    request.fields['destination'] = _selectedDestination!;

    final multipartFile = await http.MultipartFile.fromPath('file', path);
    request.files.add(multipartFile);

    final response = await request.send();
    if (response.statusCode != 200) throw Exception("Failed");
  }

  void _triggerSuccess() {
    setState(() => _currentState = UploadState.success);
  }

  void _showDestinationSheet() {
    _loadFolders();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0C10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text("Choose Destination", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          if (_currentPath != "")
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () {
                                final parts = _currentPath.split(Platform.pathSeparator);
                                parts.removeLast();
                                setModalState(() {
                                  _currentPath = parts.join(Platform.pathSeparator);
                                  _loadFolders().then((_) => setModalState(() {}));
                                });
                              },
                            )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoadingFolders 
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _folders.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return ListTile(
                                    leading: const Icon(Icons.check_circle_outline, color: Color(0xFF6C63FF)),
                                    title: Text("Select current: ${_currentPath == "" ? "Root" : p.basename(_currentPath)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onTap: () {
                                      setState(() => _selectedDestination = _currentPath);
                                      Navigator.pop(context);
                                    },
                                  );
                                }
                                final folder = _folders[index - 1];
                                return ListTile(
                                  leading: const Icon(Icons.folder_rounded, color: Color(0xFF86868B)),
                                  title: Text(folder['name'], style: const TextStyle(color: Colors.white)),
                                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                                  onTap: () {
                                    setModalState(() {
                                      _currentPath = folder['path'];
                                      _loadFolders().then((_) => setModalState(() {}));
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Send to PC", style: GoogleFonts.syne(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentState) {
      case UploadState.picking:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("1. Select Content", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildUploadArea(),
            const SizedBox(height: 32),
            Text("2. Choose Folder", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildDestinationSelector(),
            const Spacer(),
            _buildSendButton(),
          ],
        );
      case UploadState.uploading:
        return _buildUploadingState();
      case UploadState.success:
        return _buildSuccessState();
      case UploadState.error:
        return _buildErrorState();
    }
  }

  Widget _buildUploadArea() {
    if (_selectedFiles.isNotEmpty || _directFile != null) {
      final String label = _directFile != null 
          ? p.basename(_directFile!.path) 
          : (_selectedFiles.length == 1 ? _selectedFiles.first.name : "${_selectedFiles.length} files selected");
      
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
                child: const Icon(Icons.copy_all_rounded, color: Color(0xFF6C63FF), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                    Text(_directFile != null ? "Ready to send" : "Tap to change selection", style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF6C63FF), size: 20),
                onPressed: () {
                  setState(() { _selectedFiles = []; _directFile = null; });
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
    bool isActive = (_selectedFiles.isNotEmpty || _directFile != null) && _selectedDestination != null;
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
            isActive ? "Send to PC" : "Select File & Folder",
            style: GoogleFonts.outfit(
                color: isActive ? Colors.white : Colors.white24,
                fontWeight: FontWeight.bold,
                fontSize: 16
            )
        ),
      ),
    );
  }

  Widget _buildUploadingState() {
    final String currentFileName = _directFile != null 
        ? p.basename(_directFile!.path) 
        : _selectedFiles[_currentFileIndex].name;
    
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
                Text("${_currentFileIndex + 1}/${_selectedFiles.length + (_directFile != null ? 1 : 0)}", 
                  style: GoogleFonts.outfit(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                const Text("Sending", style: TextStyle(color: Color(0xFF86868B), fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text(currentFileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text("Warp Speed Protocol Active", style: const TextStyle(color: Color(0xFF86868B), fontSize: 12)),
        const SizedBox(height: 40),
        TextButton(
            onPressed: () => setState(() => _currentState = UploadState.picking),
            child: const Text("Cancel Batch", style: TextStyle(color: Colors.redAccent, fontSize: 14))
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
          Text("Batch sent successfully", style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Files are safe on your PC", style: const TextStyle(color: Color(0xFF86868B))),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: () => setState(() { _selectedFiles = []; _directFile = null; _currentState = UploadState.picking; }),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: const StadiumBorder()),
              child: const Text("Send more", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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