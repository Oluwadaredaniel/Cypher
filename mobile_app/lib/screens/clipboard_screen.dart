import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;

class ClipboardScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  const ClipboardScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  String _pcContent = '';
  String _phoneContent = '';
  bool _isCopying = false;
  bool _isSending = false;
  Timer? _refreshTimer;
  final TextEditingController _quickSendController = TextEditingController();

  String get _baseUrl => 'http://${widget.pcIpAddress}:5000';
  Map<String, String> get _headers => {
    'X-Auth-Token': widget.authToken,
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _quickSendController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      final pcResp = await http.get(Uri.parse('$_baseUrl/clipboard'), headers: _headers).timeout(const Duration(seconds: 5));
      if (pcResp.statusCode == 200 && mounted) {
        setState(() => _pcContent = jsonDecode(pcResp.body)['content'] ?? '');
      }
    } catch (_) {}

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (mounted) setState(() => _phoneContent = data?.text ?? '');
    } catch (_) {}
  }

  Future<void> _copyToPhone() async {
    if (_pcContent.isEmpty) return;
    setState(() => _isCopying = true);
    await Clipboard.setData(ClipboardData(text: _pcContent));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isCopying = false);
    _showToast('Copied to your phone ✓');
  }

  Future<void> _sendToPC(String text) async {
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await http.post(
        Uri.parse('$_baseUrl/clipboard'),
        headers: _headers,
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 5));
      HapticFeedback.mediumImpact();
      _showToast('Sent to PC ✓', success: true);
      _quickSendController.clear();
    } catch (_) {
      _showToast("Couldn't send. Check your connection.", success: false);
    }
    if (mounted) setState(() => _isSending = false);
  }

  void _showToast(String msg, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
      backgroundColor: success ? const Color(0xFF6C63FF) : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildCard({required String label, required String content, required List<Widget> actions}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          content.isEmpty
            ? Text('Nothing here yet', style: GoogleFonts.outfit(color: const Color(0xFF444444), fontSize: 14, fontStyle: FontStyle.italic))
            : Text(content, maxLines: 6, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          Row(children: actions),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Clipboard', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF86868B)),
            onPressed: _fetchAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FadeInUp(duration: const Duration(milliseconds: 300), delay: const Duration(milliseconds: 100),
            child: _buildCard(
              label: 'YOUR PC',
              content: _pcContent,
              actions: [
                Expanded(child: GestureDetector(
                  onTap: _copyToPhone,
                  child: Container(
                    height: 44, decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(100)),
                    child: Center(child: Text(_isCopying ? 'Copied ✓' : 'Copy to my phone',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(duration: const Duration(milliseconds: 300), delay: const Duration(milliseconds: 200),
            child: _buildCard(
              label: 'YOUR PHONE',
              content: _phoneContent,
              actions: [
                Expanded(child: GestureDetector(
                  onTap: () => _sendToPC(_phoneContent),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF6C63FF)),
                    ),
                    child: Center(child: Text(_isSending ? 'Sending...' : 'Send to PC',
                      style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 14))),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(duration: const Duration(milliseconds: 300), delay: const Duration(milliseconds: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QUICK SEND', style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      TextField(
                        controller: _quickSendController,
                        style: GoogleFonts.outfit(color: Colors.white),
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Type something to send to your PC...',
                          hintStyle: GoogleFonts.outfit(color: const Color(0xFF444444)),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _sendToPC(_quickSendController.text),
                        child: Container(
                          width: double.infinity, height: 48,
                          decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(100)),
                          child: Center(child: Text('Send to PC', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
