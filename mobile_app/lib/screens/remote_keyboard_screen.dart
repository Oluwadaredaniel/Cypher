import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class RemoteKeyboardScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const RemoteKeyboardScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<RemoteKeyboardScreen> createState() => _RemoteKeyboardScreenState();
}

class _RemoteKeyboardScreenState extends State<RemoteKeyboardScreen> {
  final TextEditingController _typeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Future<void> _sendType(String text) async {
    if (text.isEmpty) return;
    try {
      await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/type'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      _typeController.clear();
    } catch (_) {}
  }

  Future<void> _sendHotkey(List<String> keys) async {
    try {
      HapticFeedback.lightImpact();
      await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/keyboard/hotkey'),
        headers: {'X-Auth-Token': widget.authToken, 'Content-Type': 'application/json'},
        body: jsonEncode({'keys': keys}),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("REMOTE KEYBOARD", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w800, color: accent)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Typing Interface", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Text("Send text directly to your computer's active window.", style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
            const SizedBox(height: 32),

            // Typing Box
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _typeController,
                    focusNode: _focusNode,
                    maxLines: 3,
                    style: GoogleFonts.roboto(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "Start typing...",
                      hintStyle: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _sendType,
                  ),
                  const Divider(color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _sendType(_typeController.text),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text("SEND TEXT", style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: accent),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 40),
            Text("Common Shortcuts", style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 16),

            // Hotkey Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _hotkeyBtn("Alt + Tab", ["alt", "tab"], isDark),
                _hotkeyBtn("Win + D", ["win", "d"], isDark),
                _hotkeyBtn("Ctrl + C", ["ctrl", "c"], isDark),
                _hotkeyBtn("Ctrl + V", ["ctrl", "v"], isDark),
                _hotkeyBtn("Ctrl + Z", ["ctrl", "z"], isDark),
                _hotkeyBtn("Enter", ["enter"], isDark),
                _hotkeyBtn("Backspace", ["backspace"], isDark),
                _hotkeyBtn("Esc", ["esc"], isDark),
                _hotkeyBtn("Space", ["space"], isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hotkeyBtn(String label, List<String> keys, bool isDark) {
    return GestureDetector(
      onTap: () => _sendHotkey(keys),
      child: GlassContainer(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
        ),
      ),
    );
  }
}
