import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:nsd/nsd.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _ipController = TextEditingController();
  Discovery? _discovery;
  final List<Service> _discoveredPCs = [];
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  @override
  void dispose() {
    _stopDiscovery();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _stopDiscovery() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
    }
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isScanning = true;
      _discoveredPCs.clear();
    });

    try {
      _discovery = await startDiscovery('_cypher._tcp');
      _discovery!.addListener(() {
        if (mounted) {
          setState(() {
            _discoveredPCs.clear();
            // AUDIT: Ensure we don't show duplicate entries by checking host/name
            final seen = <String>{};
            for (var service in _discovery!.services) {
              final key = "${service.name}-${service.host}";
              if (!seen.contains(key)) {
                _discoveredPCs.add(service);
                seen.add(key);
              }
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Discovery error: $e');
    }

    Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  void _onPcSelected(Service service) {
    // nsd provides the host (IP or hostname) directly
    final String address = service.host ?? service.name ?? 'unknown';

    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': address});
  }

  // --- UI Methods ---

  void _showScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            Text("Scan QR Code",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text("Dashboard, Connect, or Guest Access",
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        final val = barcode.rawValue!;
                        if (val.contains("cypher://") || val.contains("/guest/access")) {
                          HapticFeedback.heavyImpact();
                          Navigator.pop(context);
                          _handleQrLink(val);
                          break;
                        }
                      }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text("CANCEL", style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2))
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _handleQrLink(String link) {
    try {
      if (link.contains("/guest/access")) {
        // Universal Web Link fallback
        final uri = Uri.parse(link);
        final address = uri.host;
        final token = uri.queryParameters['token'];
        if (token != null) {
          _navigateToGuestView(address, token);
        }
        return;
      }

      final uri = link.replaceFirst("cypher://", "");
      if (uri.contains("/guest")) {
         // Guest Link: address:port/guest?token=xyz
         final parts = uri.split("/guest");
         final address = parts[0].split(":")[0];
         final token = Uri.parse(link).queryParameters['token'];
         if (token != null) _navigateToGuestView(address, token);
      } else {
        // Pairing Link: address:port/pair
        final parts = uri.split("/");
        final address = parts[0].split(":")[0];
        Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': address});
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid QR Code")));
    }
  }

  void _navigateToGuestView(String ip, String token) {
     // This would ideally open a restricted guest file browser in-app 
     // or just launch the browser if we want total convenience.
     // For now, let's launch the browser as it's the "Ultimate Convenience" path.
     launchUrlString("http://$ip:5000/guest/access?token=$token");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FadeInDown(
                    child: Text("Connect to PC",
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: _showScanner,
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6C63FF), size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: Text("Make sure CYPHER is running on your PC and both devices are on the same WiFi.",
                    style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
              ),
              const SizedBox(height: 40),
              
              // [NEW] Scan Instructions Card
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.1))
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Tip: You can scan the PC dashboard or a friend's phone to link instantly.",
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("FOUND ON NETWORK",
                      style: GoogleFonts.outfit(color: const Color(0xFF4C4C4C), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  if (!_isScanning)
                    GestureDetector(
                      onTap: _startDiscovery,
                      child: Text("REFRESH", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _discoveredPCs.isEmpty
                    ? _buildEmptyDiscovery()
                    : ListView.builder(
                  itemCount: _discoveredPCs.length,
                  itemBuilder: (context, index) {
                    final pc = _discoveredPCs[index];
                    return FadeInLeft(
                      delay: Duration(milliseconds: index * 100),
                      child: _buildPcTile(pc),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
              _buildManualInput(),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/guide'),
                  child: Text("Can't find your PC? View Troubleshooting", 
                    style: GoogleFonts.outfit(color: const Color(0xFF6C63FF).withOpacity(0.8), fontSize: 13)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPcTile(Service pc) {
    return GestureDetector(
      onTap: () => _onPcSelected(pc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Icon(Icons.desktop_windows_rounded, color: Color(0xFF6C63FF))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pc.name ?? 'Unknown PC', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("Tap to connect", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2C2C2C), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDiscovery() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _isScanning
              ? const CircularProgressIndicator(color: Color(0xFF6C63FF))
              : const Icon(Icons.search_off_rounded, color: Color(0xFF1A1A1A), size: 64),
          const SizedBox(height: 20),
          Text(_isScanning ? "Searching for PCs..." : "No PCs found automatically",
              style: GoogleFonts.outfit(color: const Color(0xFF4C4C4C), fontSize: 14)),
          if (!_isScanning)
            TextButton(onPressed: _startDiscovery, child: const Text("Scan Again", style: TextStyle(color: Color(0xFF6C63FF)))),
        ],
      ),
    );
  }

  Widget _buildManualInput() {
    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("OR ENTER ADDRESS MANUALLY",
                  style: GoogleFonts.outfit(color: const Color(0xFF4C4C4C), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              if (_ipController.text.isNotEmpty)
                _isTestingConnection 
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)))
                  : const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A), 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _ipController.text.isNotEmpty ? const Color(0xFF6C63FF).withOpacity(0.3) : Colors.transparent)
            ),
            child: TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.outfit(color: Colors.white),
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Enter address shown on PC (e.g. 192.168.1.5)",
                hintStyle: GoogleFonts.outfit(color: const Color(0xFF3A3A3C), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF6C63FF)),
                  onPressed: _testAndConnect,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isTestingConnection = false;
  void _testAndConnect() async {
    if (_ipController.text.isEmpty) return;
    
    setState(() => _isTestingConnection = true);
    String ip = _ipController.text.trim();
    
    // AUDIT FIX: Prevent port doubling if user enters 192.168.1.5:5000
    if (!ip.contains(":")) {
      ip = "$ip:5000";
    } else if (ip.endsWith(":5000")) {
      // Correct, use as is
    } else {
      // Possibly another port, but let's assume they want the server's port
      // For now, if it has a port, we trust it, otherwise we append :5000
    }

    try {
      final response = await http.get(Uri.parse('http://$ip/connect-code')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        // Strip port for pairing screen if it's the default 5000 to keep UI clean
        final cleanIp = ip.contains(":") ? ip.split(":")[0] : ip;
        Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': cleanIp});
      } else {
        _showConnectionError();
      }
    } catch (e) {
      _showConnectionError();
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  void _showConnectionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Could not reach PC at this address. Check your Hotspot/WiFi."),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
