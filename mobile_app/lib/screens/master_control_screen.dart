import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:animate_do/animate_do.dart';

class MasterControlScreen extends StatefulWidget {
  const MasterControlScreen({super.key});

  @override
  State<MasterControlScreen> createState() => _MasterControlScreenState();
}

class _MasterControlScreenState extends State<MasterControlScreen> {
  // ... controllers ...
  
  // Production URL for Emerald's Central Hub
  final String _hubUrl = "https://cypher-3ctq.onrender.com";

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await http.get(Uri.parse('$_hubUrl/api/broadcast'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _titleController.text = data['title'] ?? "";
          _msgController.text = data['message'] ?? "";
          _linkController.text = data['link'] ?? "";
          _btnController.text = data['link_text'] ?? "Join";
          _isActive = data['active'] ?? true;
        });
      }
      
      // In a real app, you'd have a dedicated stats endpoint
      // For now we'll simulate or fetch if you added it to admin_hub.py
    } catch (_) {}
  }

  Future<void> _deploy() async {
    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse('$_hubUrl/master/broadcast'),
        body: {
          'title': _titleController.text,
          'message': _msgController.text,
          'link': _linkController.text,
          'link_text': _btnController.text,
          'active': _isActive ? 'on' : 'off',
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 DEPLOYED GLOBALLY"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to deploy"), backgroundColor: Colors.redAccent),
        );
      }
    }
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("MASTER CONTROL", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection("ANALYTICS"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Text("📱", style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Installations", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                      Text("Loading...", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            _buildSection("GLOBAL BROADCAST"),
            _buildField("Banner Title", _titleController),
            _buildField("Description", _msgController, maxLines: 3),
            _buildField("Action Link (WhatsApp/TikTok)", _linkController),
            _buildField("Button Label", _btnController),
            
            Row(
              children: [
                Switch(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeColor: const Color(0xFF6C63FF),
                ),
                Text("Enable banner for all users", style: GoogleFonts.outfit(color: Colors.white)),
              ],
            ),
            
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _isSending ? null : _deploy,
              child: Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(30)),
                child: Center(
                  child: _isSending 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("DEPLOY TO ALL USERS", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(label, style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
    );
  }

  Widget _buildField(String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24), border: InputBorder.none),
      ),
    );
  }
}
