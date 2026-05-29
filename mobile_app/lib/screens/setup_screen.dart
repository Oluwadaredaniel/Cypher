import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nsd/nsd.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class DiscoveredPC {
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;

  DiscoveredPC({required this.name, required this.ip, required this.port, required this.lastSeen});
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final Map<String, DiscoveredPC> _discoveredMap = {};
  bool _isScanning = true;
  Discovery? _nsdDiscovery;
  RawDatagramSocket? _udpSocket;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    setState(() => _isScanning = true);

    // 1. Start mDNS (The standard way)
    _nsdDiscovery = await startDiscovery('_cypher._tcp');
    _nsdDiscovery?.addListener(() {
      for (var service in _nsdDiscovery!.services) {
        if (service.host != null) {
          _addPC(service.name ?? "CYPHER PC", service.host!, 5000);
        }
      }
    });

    // 2. Start UDP Listener (The LocalSend way)
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5001);
    _udpSocket?.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _udpSocket?.receive();
        if (dg != null) {
          try {
            final data = jsonDecode(utf8.decode(dg.data));
            if (data['type'] == 'CYPHER_BEACON') {
              _addPC(data['pc_name'], data['ip'], data['port']);
            }
          } catch (_) {}
        }
      }
    });

    // 3. ACTIVE PROBE (MiFi / Airtel / MTN Security Bypass)
    _runActiveProbe();

    // 4. Periodic Cleanup (Remove stale devices)
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final now = DateTime.now();
      setState(() {
        _discoveredMap.removeWhere((key, pc) => now.difference(pc.lastSeen).inSeconds > 15);
      });
    });
  }

  Future<void> _runActiveProbe() async {
    try {
      final interfaces = await NetworkInterface.list(includeLinkLocal: false, type: InternetAddressType.IPv4);
      if (interfaces.isEmpty) return;

      final myIp = interfaces.first.addresses.first.address;
      final subnet = myIp.substring(0, myIp.lastIndexOf('.'));

      // Probing most common PC IP addresses in a local subnet
      for (int i in [1, 2, 5, 10, 50, 100, 101, 105, 137, 138]) {
        _probeIP("$subnet.$i");
      }
    } catch (_) {}
  }

  Future<void> _probeIP(String targetIp) async {
    try {
      final socket = await Socket.connect(targetIp, 5000, timeout: const Duration(milliseconds: 600));
      _addPC("Computer", targetIp, 5000);
      socket.destroy();
    } catch (_) {}
  }

  void _addPC(String name, String ip, int port) {
    if (mounted) {
      setState(() {
        _discoveredMap[ip] = DiscoveredPC(name: name, ip: ip, port: port, lastSeen: DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    if (_nsdDiscovery != null) stopDiscovery(_nsdDiscovery!);
    _udpSocket?.close();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);
    final sortedPCs = _discoveredMap.values.toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(accent),
            _buildStatusHeader(accent),
            Expanded(
              child: sortedPCs.isEmpty ? _buildSearchingState(isDark) : _buildDeviceList(sortedPCs, accent, isDark),
            ),
            _buildManualEntry(accent, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(Icons.shield_moon_outlined, color: accent, size: 28),
          const SizedBox(width: 12),
          Text("CYPHER", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
                const SizedBox(width: 12),
                Text("SEARCHING_WIFI", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_find_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 80),
          const SizedBox(height: 24),
          Text("Looking for your PC...", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          Text("Make sure CYPHER is open on your computer", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDeviceList(List<DiscoveredPC> pcs, Color accent, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: pcs.length,
      itemBuilder: (context, i) {
        final pc = pcs[i];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': pc.ip}),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.computer_rounded, color: accent)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pc.name, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      Text("Available to connect", style: GoogleFonts.roboto(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualEntry(Color accent, bool isDark) {
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        child: Row(
          children: [
            Expanded(child: TextField(controller: controller, style: GoogleFonts.roboto(fontSize: 13, color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(hintText: "Enter IP Manually", border: InputBorder.none, hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))))),
            TextButton(onPressed: () => Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': controller.text}), child: Text("LINK", style: TextStyle(color: accent, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}
