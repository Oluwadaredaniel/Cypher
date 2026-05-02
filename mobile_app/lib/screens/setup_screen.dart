import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/services.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _ipController = TextEditingController();
  BonsoirDiscovery? _discovery;
  List<BonsoirService> _discoveredPCs = [];
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  @override
  void dispose() {
    _discovery?.stop();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    setState(() => _isScanning = true);
    _discovery = BonsoirDiscovery(type: '_cypher._tcp');
    await _discovery!.ready;
    
    _discovery!.eventStream!.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved || 
          event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        if (event.service != null && event.service is ResolvedBonsoirService) {
          final service = event.service as ResolvedBonsoirService;
          setState(() {
            if (!_discoveredPCs.any((p) => p.name == service.name)) {
              _discoveredPCs.add(service);
            }
          });
        }
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        setState(() {
          _discoveredPCs.removeWhere((p) => p.name == event.service?.name);
        });
      }
    });

    await _discovery!.start();
    Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  void _onPcSelected(BonsoirService service) {
    if (service is ResolvedBonsoirService) {
      final ip = service.host;
      HapticFeedback.mediumImpact();
      Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': ip});
    }
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
              FadeInDown(
                child: Text("Connect to PC",
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: Text("Make sure CYPHER is running on your PC and both devices are on the same WiFi.",
                    style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
              ),
              const SizedBox(height: 40),
              
              Text("FOUND ON NETWORK", 
                style: GoogleFonts.outfit(color: const Color(0xFF4C4C4C), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPcTile(BonsoirService pc) {
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
                  Text(pc.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
          Text("OR ENTER ADDRESS MANUALLY", 
            style: GoogleFonts.outfit(color: const Color(0xFF4C4C4C), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                hintText: "e.g. 192.168.1.5",
                hintStyle: GoogleFonts.outfit(color: const Color(0xFF3A3A3C)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF6C63FF)),
                  onPressed: () {
                    if (_ipController.text.isNotEmpty) {
                      Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': _ipController.text});
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
