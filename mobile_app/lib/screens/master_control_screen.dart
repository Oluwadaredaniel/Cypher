import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../widgets/glass_container.dart';

class MasterControlScreen extends StatefulWidget {
  const MasterControlScreen({super.key});

  @override
  State<MasterControlScreen> createState() => _MasterControlScreenState();
}

class _MasterControlScreenState extends State<MasterControlScreen> {
  Map<String, dynamic> _stats = {'total_installs': 0, 'active_today': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGlobalStats();
  }

  Future<void> _fetchGlobalStats() async {
    try {
      final res = await http.get(Uri.parse('https://cypher-3ctq.onrender.com/api/metadata'));
      if (res.statusCode == 200) {
        setState(() => _stats = jsonDecode(res.body));
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F17),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _buildDashboard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF6C63FF), size: 20), onPressed: () => Navigator.pop(context)),
              Text("MASTER HUB", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF6C63FF), letterSpacing: 2)),
            ],
          ),
          const Icon(Icons.admin_panel_settings_rounded, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard("TOTAL INSTALLS", _stats['total_installs'].toString())),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard("ACTIVE TODAY", _stats['active_today'].toString())),
          ],
        ),
        const SizedBox(height: 24),
        _buildActionTile("Push Global Announcement", Icons.campaign_rounded),
        _buildActionTile("Manage API Certificates", Icons.security_rounded),
        _buildActionTile("System Health Monitor", Icons.analytics_rounded),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.roboto(fontSize: 9, color: Colors.white24)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 16),
            Text(title, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.white10),
          ],
        ),
      ),
    );
  }
}
