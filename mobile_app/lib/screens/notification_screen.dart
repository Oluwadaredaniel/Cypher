import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class NotificationScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const NotificationScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  Map<String, dynamic> _transferStats = {};
  Map<String, dynamic> _systemStats = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final headers = {'X-Auth-Token': widget.authToken};
      final baseUrl = 'http://${widget.pcIpAddress}:5000';

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/notifications'), headers: headers),
        http.get(Uri.parse('$baseUrl/files/transfers'), headers: headers),
        http.get(Uri.parse('$baseUrl/system-stats'), headers: headers),
      ]);

      if (results[0].statusCode == 200) {
        setState(() => _notifications = (jsonDecode(results[0].body) as List).reversed.toList());
      }
      if (results[1].statusCode == 200) {
        setState(() => _transferStats = jsonDecode(results[1].body));
      }
      if (results[2].statusCode == 200) {
        setState(() => _systemStats = jsonDecode(results[2].body));
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(accent, isDark),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDark),
                        const SizedBox(height: 24),
                        _buildBentoGrid(accent, isDark),
                        const SizedBox(height: 32),
                        _buildFooterBento(accent, isDark),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFloatingHeader(accent, isDark),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildFloatingHeader(Color accent, bool isDark) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF080F17) : const Color(0xFFF2F2F7)).withOpacity(0.8),
          border: Border(bottom: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20), onPressed: () => Navigator.pop(context)),
                Text("ALERTS", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.sensors_rounded, color: accent, size: 18),
                const SizedBox(width: 8),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF10B981), blurRadius: 4)])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent, bool isDark) => const SizedBox(height: 64);

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SYSTEM STATUS", style: GoogleFonts.roboto(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Alert Center", style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
            TextButton(
              onPressed: () {},
              child: Text("Clear All", style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoGrid(Color accent, bool isDark) {
    return Column(
      children: [
        if (_notifications.isNotEmpty)
          _buildNotificationItem(_notifications.first, accent, isDark, isUrgent: true)
        else
          _buildPlaceholderAlert(accent, isDark),

        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildActiveSyncsCard(accent, isDark),
                  const SizedBox(height: 16),
                  _buildHistoryCard(accent, isDark),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildHealthCard(accent, isDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholderAlert(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("System Shield Active", style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                Text("No security threats detected.", style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(dynamic n, Color accent, bool isDark, {bool isUrgent = false}) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: isUrgent ? Colors.redAccent.withOpacity(0.1) : accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(isUrgent ? Icons.security_rounded : Icons.info_rounded, color: isUrgent ? Colors.redAccent : accent, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n['title'] ?? "System Alert", style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text(n['message'] ?? "", style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38), height: 1.4)),
                    ],
                  ),
                ),
                if (isUrgent)
                  Text("URGENT", style: GoogleFonts.roboto(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(n['timestamp'] ?? "Just now", style: GoogleFonts.roboto(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.12))),
                Row(
                  children: [
                    Text("Details", style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 10),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActiveSyncsCard(Color accent, bool isDark) {
    int active = _transferStats.values.where((v) => v['status'] != 'completed').length;
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CURRENT FILE SYNCS", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold)),
              Text("$active ACTIVE", style: GoogleFonts.roboto(fontSize: 8, color: accent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (active > 0) ...[
            Text(_transferStats.values.first['name'], style: GoogleFonts.roboto(fontSize: 13, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: 0.82, minHeight: 2, backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1), valueColor: AlwaysStoppedAnimation(accent)),
            ),
          ] else
            Text("No active transfers", style: GoogleFonts.roboto(fontSize: 13, color: (isDark ? Colors.white : Colors.black).withOpacity(0.12))),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("RECENT HISTORY", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._notifications.skip(1).take(2).map((n) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                const SizedBox(width: 8),
                Expanded(child: Text(n['title'], style: GoogleFonts.roboto(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.38)), overflow: TextOverflow.ellipsis)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildHealthCard(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("HEALTH", style: GoogleFonts.roboto(fontSize: 8, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontWeight: FontWeight.bold)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("99.9%", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: accent)),
              Text("Uptime", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("12ms", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFFFB786))),
              Text("Sync Speed", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterBento(Color accent, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 1,
      mainAxisSpacing: 12,
      childAspectRatio: 3.5,
      children: [
        _footerItem("Storage Capacity", "42.8 GB / 100 GB", Icons.storage_rounded, accent, isDark),
        _footerItem("Security Level", "AES-256-GCM", Icons.lock_rounded, const Color(0xFF10B981), isDark),
        _footerItem("Connected Devices", "1,024 Verified", Icons.hub_rounded, const Color(0xFFFFB786), isDark),
      ],
    );
  }

  Widget _footerItem(String label, String value, IconData icon, Color color, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.roboto(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
              Text(value, style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          Icon(icon, color: color, size: 28),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final theme = Provider.of<ThemeService>(context, listen: false);
    final isDark = theme.isDarkMode;
    return GlassContainer(
      height: 90,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", false, () => Navigator.pop(context), isDark),
          _navItem(Icons.folder_copy_rounded, "Files", false, () => Navigator.pushReplacementNamed(context, '/browser', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
          _navItem(Icons.grid_view_rounded, "Tools", true, null, isDark),
          _navItem(Icons.tune_rounded, "Settings", false, () => Navigator.pushReplacementNamed(context, '/settings', arguments: {'pcIpAddress': widget.pcIpAddress, 'authToken': widget.authToken}), isDark),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, [VoidCallback? tap, bool isDark = true]) {
    final accent = const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: tap,
      child: Opacity(
        opacity: active ? 1.0 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? accent : (isDark ? Colors.white : Colors.black), size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: active ? accent : (isDark ? Colors.white : Colors.black))),
          ],
        ),
      ),
    );
  }
}
