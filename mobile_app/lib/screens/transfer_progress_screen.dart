import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';
import '../widgets/glass_container.dart';

class TransferProgressScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final List<dynamic>? transfers;

  const TransferProgressScreen({super.key, required this.pcIpAddress, required this.authToken, this.transfers});

  @override
  State<TransferProgressScreen> createState() => _TransferProgressScreenState();
}

class _TransferProgressScreenState extends State<TransferProgressScreen> {
  Map<String, dynamic> _activeTransfers = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final res = await http.get(
          Uri.parse('http://${widget.pcIpAddress}:5000/files/transfers'),
          headers: {'X-Auth-Token': widget.authToken},
        );
        if (res.statusCode == 200 && mounted) {
          setState(() => _activeTransfers = jsonDecode(res.body));
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: const Color(0xFF0D141D),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildSummaryBento(),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Transfer Queue", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.pause_circle_rounded, color: Colors.white24)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_activeTransfers.isEmpty)
                        _buildEmptyState()
                      else
                        ..._activeTransfers.entries.map((e) => _buildTransferCard(e.value)).toList(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final accent = const Color(0xFF6C63FF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
              Text("TRANSFERS", style: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
            ],
          ),
          const Icon(Icons.sensors_rounded, color: Color(0xFF6C63FF)),
        ],
      ),
    );
  }

  Widget _buildSummaryBento() {
    int uploads = _activeTransfers.values.where((v) => v['status'] == 'sending').length;
    int downloads = _activeTransfers.values.where((v) => v['status'] == 'receiving').length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildSummaryCard("UPLOADS", uploads.toString(), Icons.upload_rounded, const Color(0xFF6C63FF)),
        _buildSummaryCard("DOWNLOADS", downloads.toString(), Icons.download_rounded, const Color(0xFFFFB786)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(label, style: GoogleFonts.roboto(fontSize: 8, color: Colors.white24, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> data) {
    final bool isCompleted = data['status'] == 'completed';
    final double progress = (data['progress'] as num).toDouble() / 100;
    final accent = isCompleted ? const Color(0xFF10B981) : const Color(0xFF6C63FF);

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF192029).withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.description_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'], style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                      Text(isCompleted ? "FINISHED" : "${data['speed']} • SYNCING", style: GoogleFonts.roboto(fontSize: 9, color: Colors.white24)),
                    ],
                  ),
                ),
                Text("${(progress * 100).toInt()}%", style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_motion_rounded, color: Colors.white10, size: 48),
          const SizedBox(height: 16),
          Text("No active transfers", style: GoogleFonts.roboto(color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context)),
          _navItem(Icons.folder_copy_rounded, "Files", true),
          _navItem(Icons.settings_input_component_rounded, "Controls", false),
          _navItem(Icons.tune_rounded, "Settings", false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, [VoidCallback? tap]) {
    final accent = const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: tap,
      child: Opacity(
        opacity: active ? 1.0 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? accent : Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: active ? accent : Colors.white)),
          ],
        ),
      ),
    );
  }
}
