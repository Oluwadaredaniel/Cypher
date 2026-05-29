import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/glass_container.dart';

class HomeTab extends StatelessWidget {
  final String pairingCode;
  final List<dynamic> devices;
  final Map<String, dynamic> stats;
  final bool isDark;
  final Color accent;
  final VoidCallback onRefreshCode;

  const HomeTab({
    super.key,
    required this.pairingCode,
    required this.devices,
    required this.stats,
    required this.isDark,
    required this.accent,
    required this.onRefreshCode,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Dashboard", "Your system is ready to link."),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildPairingCard()),
              const SizedBox(width: 24),
              Expanded(child: _buildLinkedDevices()),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text("LIVE CONNECTION", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        Text(sub, style: GoogleFonts.roboto(fontSize: 14, color: isDark ? Colors.white24 : Colors.black38)),
      ],
    );
  }

  Widget _buildPairingCard() {
    String cleanCode = pairingCode.replaceAll("-", "").padRight(6, "-");
    String p1 = cleanCode.substring(0, 3);
    String p2 = cleanCode.substring(3, 6);

    return GlassContainer(
      padding: const EdgeInsets.all(32),
      height: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Mobile Connection", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  Text("Enter this code on your phone to link.", style: GoogleFonts.roboto(fontSize: 13, color: isDark ? Colors.white30 : Colors.black38)),
                ],
              ),
              Icon(Icons.qr_code_scanner_rounded, color: isDark ? Colors.white24 : Colors.black26),
            ],
          ),
          const Spacer(),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _codeBlock(p1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(":", style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.bold, color: accent.withOpacity(0.5))),
                ),
                _codeBlock(p2),
              ],
            ),
          ),
          const Spacer(),
          Divider(color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(width: 8),
                  Text("End-to-end encrypted channel", style: GoogleFonts.roboto(fontSize: 11, color: isDark ? Colors.white24 : Colors.black38)),
                ],
              ),
              TextButton(onPressed: onRefreshCode, child: Text("Refresh", style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: accent))),
            ],
          )
        ],
      ),
    );
  }

  Widget _codeBlock(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.1)),
      ),
      child: Text(code, style: GoogleFonts.roboto(fontSize: 44, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black, letterSpacing: 8)),
    );
  }

  Widget _buildLinkedDevices() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      height: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Linked Devices", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 24),
          if (devices.isEmpty)
            Expanded(child: Center(child: Text("No devices linked", style: GoogleFonts.roboto(color: isDark ? Colors.white10 : Colors.black12))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _deviceItem(devices[i]['device_name'], "Connected", Icons.smartphone_rounded, true),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text("Link New Device", style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceItem(String name, String status, IconData icon, bool active) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? accent.withOpacity(0.2) : Colors.transparent)
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? accent : (isDark ? Colors.white24 : Colors.black26), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              Text(status, style: GoogleFonts.roboto(fontSize: 11, color: isDark ? Colors.white24 : Colors.black38)),
            ]),
          ),
          if (active) Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard("Processor", "${stats['cpu_percent']?.toInt() ?? 0}%", Icons.memory_rounded, accent, (stats['cpu_percent'] as num?)?.toDouble() ?? 0.0)),
        const SizedBox(width: 16),
        Expanded(child: _statCard("Memory", "${stats['ram_percent']?.toInt() ?? 0}%", Icons.speed_rounded, const Color(0xFF8B5CF6), (stats['ram_percent'] as num?)?.toDouble() ?? 0.0)),
        const SizedBox(width: 16),
        Expanded(child: _statCard("Storage", "${stats['disk_percent']?.toInt() ?? 0}%", Icons.storage_rounded, const Color(0xFF10B981), (stats['disk_percent'] as num?)?.toDouble() ?? 0.0)),
      ],
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color, double percent) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.roboto(fontSize: 8, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(val, style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: (percent / 100).clamp(0.0, 1.0), minHeight: 2, backgroundColor: isDark ? Colors.white10 : Colors.black12, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      ),
    );
  }
}
