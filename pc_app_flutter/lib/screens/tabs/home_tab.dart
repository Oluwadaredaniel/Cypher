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
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildPairingCard()),
              const SizedBox(width: 20),
              Expanded(flex: 3, child: _buildLinkedDevices()),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF10B981), letterSpacing: 2)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Dashboard', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, height: 1.1)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
          ),
          child: Text(
            'System ready to link',
            style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ),
      ],
    );
  }

  Widget _buildPairingCard() {
    final raw = pairingCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').padRight(6, '·');
    final digits = raw.substring(0, 6);

    return GlassContainer(
      padding: const EdgeInsets.all(28),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: Icon(Icons.phone_android_rounded, color: accent, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mobile Link', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                  Text('Enter this code in the CYPHER app', style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 6; i++) ...[
                if (i == 3)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('—', style: GoogleFonts.inter(fontSize: 18, color: accent.withOpacity(0.35), fontWeight: FontWeight.w300)),
                  ),
                _digitBox(digits[i]),
              ],
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('End-to-end encrypted', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w500)),
                ],
              ),
              GestureDetector(
                onTap: onRefreshCode,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text('Refresh', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _digitBox(String char) {
    return Container(
      width: 50, height: 62,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.18), width: 1.5),
      ),
      child: Center(
        child: Text(
          char,
          style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget _buildLinkedDevices() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Linked Devices', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${devices.length}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.black38)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (devices.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.smartphone_outlined, size: 40, color: isDark ? Colors.white10 : Colors.black12),
                    const SizedBox(height: 12),
                    Text('No devices paired', style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Use the code to link your phone', style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white12 : Colors.black12)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _deviceItem(
                  devices[i]['device_name'] ?? 'Unknown Device',
                  'Connected',
                  Icons.smartphone_rounded,
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRefreshCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text('Rotate Access Key', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceItem(String name, String status, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
                Text(status, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981))),
              ],
            ),
          ),
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x5510B981), blurRadius: 6, spreadRadius: 1)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard('Processor', (stats['cpu_percent'] as num?)?.toInt() ?? 0, Icons.memory_rounded, accent, (stats['cpu_percent'] as num?)?.toDouble() ?? 0.0)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Memory', (stats['ram_percent'] as num?)?.toInt() ?? 0, Icons.speed_rounded, const Color(0xFF8B5CF6), (stats['ram_percent'] as num?)?.toDouble() ?? 0.0)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Storage', (stats['disk_percent'] as num?)?.toInt() ?? 0, Icons.storage_rounded, const Color(0xFF10B981), (stats['disk_percent'] as num?)?.toDouble() ?? 0.0)),
      ],
    );
  }

  Widget _statCard(String label, int val, IconData icon, Color color, double percent) {
    final frac = (percent / 100).clamp(0.0, 1.0);
    final isHigh = percent > 80;

    return GlassContainer(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isHigh ? const Color(0xFFEF4444) : color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: isHigh ? const Color(0xFFEF4444) : color, size: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$val', style: GoogleFonts.inter(fontSize: 38, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 2),
                child: Text('%', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white30 : Colors.black38)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Glowing progress bar
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isHigh ? const Color(0xFFEF4444) : color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: (isHigh ? const Color(0xFFEF4444) : color).withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
