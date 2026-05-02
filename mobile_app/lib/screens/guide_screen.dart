import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String _markdownContent = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    setState(() => _isLoading = true);
    try {
      // In a real app, this would be a remote URL like https://cypher.app/api/guide.md
      // This allows you to update instructions without pushing a new app update.
      final response = await http.get(Uri.parse("https://raw.githubusercontent.com/example/cypher/main/GUIDE.md"))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        setState(() => _markdownContent = response.body);
      } else {
        throw Exception();
      }
    } catch (e) {
      // Fallback to local instructions if offline
      setState(() => _markdownContent = _fallbackGuide);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("User Guide", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
        : Markdown(
            data: _markdownContent,
            styleSheet: MarkdownStyleTheme.dark(context),
          ),
    );
  }

  final String _fallbackGuide = """
# Getting Started with CYPHER

Welcome to the future of local file sharing.

### 1. Connecting for the first time
Ensure your PC and Phone are on the **same WiFi network**.
- Open CYPHER on your PC.
- Tap 'Connect to PC' on your phone.
- Your PC should appear automatically. Tap it and enter the 6-digit code.

### 2. Fast File Sharing
- Use the **Browser** to download files from your PC.
- Use the **Send** button to push photos or links from your phone to your PC.

### 3. Quick Paste (Pro Tip)
You can paste your phone's clipboard anywhere on your PC by pressing `Ctrl + Alt + V` on your keyboard.

### 4. Remote Power
You can Lock, Sleep, or Shutdown your PC directly from the **Controls** tab.

---
*Version 1.0.0 • © 2024 CYPHER Team*
""";
}

class MarkdownStyleTheme {
  static MarkdownStyleSheet dark(BuildContext context) {
    return MarkdownStyleSheet(
      p: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 15, height: 1.6),
      h1: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
      h3: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      listBullet: GoogleFonts.outfit(color: const Color(0xFF6C63FF)),
      code: GoogleFonts.firaCode(backgroundColor: const Color(0xFF1A1A1A), color: const Color(0xFF6C63FF)),
      blockquote: GoogleFonts.outfit(color: Colors.white70),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
