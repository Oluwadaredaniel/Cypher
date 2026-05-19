import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;

class ActiveTasksScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ActiveTasksScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<ActiveTasksScreen> createState() => _ActiveTasksScreenState();
}

class _ActiveTasksScreenState extends State<ActiveTasksScreen> {
  List<dynamic> _windows = [];
  bool _isLoading = true;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _fetchActiveWindows();
  }

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {"X-Auth-Token": widget.authToken, "Content-Type": "application/json"};

  Future<void> _fetchActiveWindows() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/system/active-windows'), headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _windows = jsonDecode(response.body);
            _isLoading = false;
            _isError = false;
          });
        }
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _isError = true; });
    }
  }

  Future<void> _closeWindow(int id, String title) async {
    HapticFeedback.heavyImpact();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/apps/close'),
        headers: _headers,
        body: jsonEncode({"id": id}),
      );
      if (response.statusCode == 200) {
        _showToast("Closed $title");
        _fetchActiveWindows(); // Refresh list
      } else {
        _showToast("Failed to close window", isError: true);
      }
    } catch (e) {
      _showToast("Network error", isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF6C63FF),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

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
        title: Text("Active Tasks", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _fetchActiveWindows, icon: const Icon(Icons.refresh, color: Colors.white70)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
        : _isError 
          ? _buildErrorState()
          : _buildWindowsList(),
    );
  }

  Widget _buildWindowsList() {
    if (_windows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text("No active windows found", style: GoogleFonts.outfit(color: Colors.white24)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _windows.length,
      itemBuilder: (context, index) {
        final win = _windows[index];
        return FadeInLeft(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index * 50),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(_getIcon(win['title']), color: const Color(0xFF6C63FF), size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        win['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (win['tab_hint'] > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text("${win['tab_hint']} Tabs", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          Text(
                            win['is_minimized'] ? "Minimized" : "Active",
                            style: GoogleFonts.outfit(color: win['is_minimized'] ? Colors.white24 : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _closeWindow(win['id'], win['title']),
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('chrome') || t.contains('edge') || t.contains('firefox')) return Icons.language_rounded;
    if (t.contains('spotify') || t.contains('music')) return Icons.music_note_rounded;
    if (t.contains('vlc') || t.contains('media') || t.contains('video')) return Icons.play_circle_fill_rounded;
    if (t.contains('code') || t.contains('studio')) return Icons.code_rounded;
    if (t.contains('word') || t.contains('docs')) return Icons.description_rounded;
    if (t.contains('folder') || t.contains('file explorer')) return Icons.folder_open_rounded;
    return Icons.window_rounded;
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text("Failed to load active tasks", style: GoogleFonts.outfit(color: Colors.white)),
          TextButton(onPressed: _fetchActiveWindows, child: const Text("Try Again")),
        ],
      ),
    );
  }
}
