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
# 📗 The Ultimate CYPHER Guide

Welcome to your new digital command center. CYPHER is designed to make the boundary between your PC and Phone disappear.

---

### 1. 📋 Universal Clipboard
Stop emailing links to yourself. 
- **Send to PC**: Copy text on your phone, go to the **Clipboard** tab, and tap **"Send to PC"**. It will instantly be ready to paste on your PC using `Ctrl + V`.
- **Get from PC**: Anything you copy on your PC can be fetched by tapping **"Fetch from PC"** on your phone.

### 2. 📂 Windows-Style File Browsing
The Browser is now more powerful than ever.
- **View Modes**: Toggle between **List** and **Grid** views (Windows Explorer style) using the top icon.
- **Smart Grouping**: Tap the filter icon to group files by **Date** (Today, Last Week, etc.) or **Type**.
- **Deep Rendering**: We now show **ALL** file types including `.exe`, `.apk`, and system files. Large folders with thousands of items now load smoothly.
- **Live Thumbnails**: See small previews of your images directly in the list, just like on your PC.

### 3. 🎞️ Pro Previews & Editing
- **Media**: Instant playback for Video and Audio.
- **Documents**: View **PDFs** and **Code Files** (Python, JS, Dart, etc.) with full syntax highlighting without downloading.
- **Auto-Open**: For Word, Excel, and APKs, just tap download. Once finished, Cypher will automatically ask to open them in your preferred app.

### 4. 👥 Secure Guest Access
Perfect for sharing files with visitors without sharing your Wi-Fi password or giving full PC access.
- **PC Dashboard**: Go to the **Security** tab on your PC app.
- **Setup Permissions**: You can choose exactly which folders the guest can see. By default, they only see a temporary "Public" folder, but you can add your "Downloads" or "Pictures" for specific sessions.
- **Access Control**: You can set a timer (e.g., 30 minutes). Once the time is up, their connection is automatically severed by the PC.
- **Connect**: The guest just needs to scan the **QR Code** generated on your screen. They don't need to install the app; they can use their browser!
- **Useful for**: Sharing study materials, office documents, or party photos without handing over your unlocked phone.

### 5. 🌐 Troubleshooting Connection (Hotspots & Wi-Fi)
If you see "Lost Connection to PC" while on a hotspot or public Wi-Fi:
- **AP Isolation**: Some routers (and phone hotspots) prevent devices from "talking" to each other for security. Check your hotspot settings for "Allow devices to see each other".
- **Windows Firewall**: Your PC might be blocking incoming connections on a "Public" network. Try setting your hotspot network to **"Private"** in Windows Network Settings.
- **IP Change**: Hotspots often change your PC's address. If connection fails, check the **PC Address** on the dashboard and ensure it matches what the app is looking for.
- **Mum's Hotspot Tip**: Ensure "Data Saver" isn't killing background processes on either the phone or the PC.

---
*Version 1.1.0 • Built for Power Users • Emerald Dev*
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
