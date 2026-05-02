import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:animate_do/animate_do.dart';
import 'package:path/path.dart' as p;
import 'send_to_pc_screen.dart';

class PhoneBrowserScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  
  const PhoneBrowserScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<PhoneBrowserScreen> createState() => _PhoneBrowserScreenState();
}

class _PhoneBrowserScreenState extends State<PhoneBrowserScreen> {
  Directory? _currentDir;
  List<FileSystemEntity> _items = [];
  bool _isLoading = true;
  bool _showHidden = true;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      // Request storage permissions
      if (await Permission.manageExternalStorage.request().isGranted || 
          await Permission.storage.request().isGranted) {
        _loadDir(Directory('/storage/emulated/0'));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Storage permission required to browse files.")),
          );
        }
      }
    } else {
      _loadDir(await getApplicationDocumentsDirectory());
    }
  }

  Future<void> _loadDir(Directory dir) async {
    setState(() => _isLoading = true);
    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      setState(() {
        _currentDir = dir;
        _items = entities;
        if (!_showHidden) {
          _items = _items.where((item) => !p.basename(item.path).startsWith('.')).toList();
        }
        // Sort: Folders first, then alphabetically
        _items.sort((a, b) {
          if (a is Directory && b is! Directory) return -1;
          if (a is! Directory && b is Directory) return 1;
          return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onEntityTap(FileSystemEntity entity) {
    if (entity is Directory) {
      _loadDir(entity);
    } else if (entity is File) {
      _confirmUpload(entity);
    }
  }

  void _confirmUpload(File file) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => SendToPCScreen(
        pcIpAddress: widget.pcIpAddress,
        authToken: widget.authToken,
        preSelectedFile: file,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Phone Storage", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(_currentDir?.path ?? "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off, size: 20),
            onPressed: () {
              setState(() => _showHidden = !_showHidden);
              if (_currentDir != null) _loadDir(_currentDir!);
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
        : Column(
            children: [
              if (_currentDir?.path != '/storage/emulated/0' && _currentDir?.parent != null)
                ListTile(
                  leading: const Icon(Icons.arrow_upward, color: Color(0xFF6C63FF)),
                  title: const Text("..", style: TextStyle(color: Colors.white)),
                  onTap: () => _loadDir(_currentDir!.parent),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isDir = item is Directory;
                    final name = p.basename(item.path);
                    final isHidden = name.startsWith('.');

                    return FadeInUp(
                      duration: const Duration(milliseconds: 300),
                      delay: Duration(milliseconds: index * 10),
                      child: ListTile(
                        leading: Icon(
                          isDir ? Icons.folder : Icons.insert_drive_file, 
                          color: isHidden ? Colors.grey.withOpacity(0.3) : (isDir ? const Color(0xFF6C63FF) : Colors.white70)
                        ),
                        title: Text(name, style: TextStyle(color: isHidden ? Colors.grey : Colors.white, fontSize: 14)),
                        onTap: () => _onEntityTap(item),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}
