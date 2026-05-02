import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

enum GuestState { setup, active, expired }

class GuestScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const GuestScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  // State variables
  GuestState _currentState = GuestState.setup;
  List<String> _availableFolders = [];
  Set<String> _selectedFolders = {};
  int _selectedDurationMinutes = 15;
  bool _isLoading = false;

  // Active Session variables
  String? _guestToken;
  DateTime? _expiryTime;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _isGuestConnected = false;
  int _filesAccessedCount = 0;
  int _backCountdown = 10;

  @override
  void initState() {
    super.initState();
    _fetchFolders();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // --- API LOGIC ---

  Future<void> _fetchFolders() async {
    try {
      final response = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/files'),
        headers: {"X-Auth-Token": widget.authToken},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _availableFolders = data.map((e) => e.toString()).toList();
          _selectedFolders = Set.from(_availableFolders);
        });
      }
    } catch (e) {
      debugPrint("Error fetching folders: $e");
    }
  }

  Future<void> _createGuestAccess() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get connect code from PC
      final codeRes = await http.get(
        Uri.parse('http://${widget.pcIpAddress}:5000/connect-code'),
        headers: {"X-Auth-Token": widget.authToken},
      );

      if (codeRes.statusCode == 200) {
        // 2. Mocking/Generating the specific guest session token logic 
        // In a real flow, you'd POST to /pair to register the session
        _guestToken = "GUEST_${DateTime.now().millisecondsSinceEpoch}";
        _expiryTime = DateTime.now().add(Duration(minutes: _selectedDurationMinutes));
        
        setState(() {
          _currentState = GuestState.active;
          _isLoading = false;
        });

        _startCountdown();
        _startPolling();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_expiryTime == null) return;
      final remaining = _expiryTime!.difference(DateTime.now());
      
      if (remaining.isNegative) {
        _expireSession();
      } else {
        setState(() {}); // Refresh timer UI
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final res = await http.get(
          Uri.parse('http://${widget.pcIpAddress}:5000/paired-devices'),
          headers: {"X-Auth-Token": widget.authToken},
        );
        if (res.statusCode == 200) {
          final List devices = json.decode(res.body);
          // Simple logic: if a new device appears or status changes
          if (devices.isNotEmpty && !_isGuestConnected) {
            setState(() => _isGuestConnected = true);
          }
        }
        
        // Also fetch history to update "files viewed"
        final histRes = await http.get(
          Uri.parse('http://${widget.pcIpAddress}:5000/history'),
          headers: {"X-Auth-Token": widget.authToken},
        );
        if (histRes.statusCode == 200) {
          final List history = json.decode(histRes.body);
          setState(() => _filesAccessedCount = history.length);
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  void _expireSession() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() => _currentState = GuestState.expired);
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_backCountdown > 0) {
        setState(() => _backCountdown--);
      } else {
        timer.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  Future<void> _endSessionManually() async {
    _expireSession();
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _currentState == GuestState.setup ? _buildAppBar() : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStateView(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF86868B), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text("Guest Access", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      centerTitle: true,
    );
  }

  Widget _buildCurrentStateView() {
    switch (_currentState) {
      case GuestState.setup:
        return _viewSetup();
      case GuestState.active:
        return _viewActive();
      case GuestState.expired:
        return _viewExpired();
    }
  }

  // --- STATE 1: SETUP ---

  Widget _viewSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildIllustration("👥"),
          const SizedBox(height: 24),
          Text("Share files temporarily", 
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Pick what to share and for how long. Your guest scans a code to get access.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 13)),
          const SizedBox(height: 32),
          
          // Folder Selector
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("What can they see?", 
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ..._availableFolders.map((folder) => _buildFolderRow(folder)),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Duration Selector
          Align(
            alignment: Alignment.centerLeft,
            child: Text("How long?", 
                style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDurationPill("15 min", 15),
              _buildDurationPill("30 min", 30),
              _buildDurationPill("1 hour", 60),
              _buildDurationPill("2 hours", 120),
            ],
          ),
          
          const SizedBox(height: 40),
          _buildPrimaryButton("Create Guest Access", _createGuestAccess, isLoading: _isLoading),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFolderRow(String folder) {
    bool isSelected = _selectedFolders.contains(folder);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          setState(() {
            isSelected ? _selectedFolders.remove(folder) : _selectedFolders.add(folder);
          });
        },
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
                border: Border.all(color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF2C2C2C), width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            const Text("📁", style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(folder, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationPill(String label, int mins) {
    bool isSelected = _selectedDurationMinutes == mins;
    return GestureDetector(
      onTap: () => setState(() => _selectedDurationMinutes = mins),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF2C2C2C)),
        ),
        child: Text(label, 
            style: GoogleFonts.outfit(color: isSelected ? Colors.white : const Color(0xFF86868B), fontSize: 12)),
      ),
    );
  }

  // --- STATE 2: ACTIVE ---

  Widget _viewActive() {
    final remaining = _expiryTime?.difference(DateTime.now()) ?? Duration.zero;
    final timeStr = "${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}";
    
    Color timerColor = const Color(0xFF6C63FF);
    if (remaining.inMinutes < 1) timerColor = Colors.red;
    else if (remaining.inMinutes < 5) timerColor = Colors.amber;

    return Column(
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFF0D2818),
            child: Text("Guest session is active", 
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: const Color(0xFF30D158), fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ZoomIn(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      children: [
                        QrImageView(
                          data: json.encode({
                            "ip": widget.pcIpAddress,
                            "token": _guestToken,
                            "folders": _selectedFolders.toList(),
                            "expires": _expiryTime?.millisecondsSinceEpoch
                          }),
                          version: QrVersions.auto,
                          size: 200.0,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.white),
                          dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text("Ask your guest to scan this", 
                            style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(timeStr, style: GoogleFonts.outfit(color: timerColor, fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                // Status Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: _isGuestConnected ? const Color(0xFF30D158) : const Color(0xFF86868B),
                        shape: BoxShape.circle,
                        boxShadow: _isGuestConnected ? [BoxShadow(color: const Color(0xFF30D158).withOpacity(0.4), blurRadius: 10)] : []
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_isGuestConnected ? "Guest connected" : "Waiting for guest", 
                        style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
                  ],
                ),
                if (_isGuestConnected) 
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text("$_filesAccessedCount files viewed", style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
                  ),
                
                const SizedBox(height: 40),
                _buildGhostButton("Extend by 30 min", () {
                  setState(() => _expiryTime = _expiryTime?.add(const Duration(minutes: 30)));
                }),
                const SizedBox(height: 12),
                _buildPrimaryButton("End Session", _endSessionManually, color: Colors.red),
              ],
            ),
          ),
        )
      ],
    );
  }

  // --- STATE 3: EXPIRED ---

  Widget _viewExpired() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIllustration("🕐"),
          const SizedBox(height: 24),
          Text("Session ended", style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Your guest's access has expired", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 13)),
          const SizedBox(height: 32),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                _buildSummaryRow("Duration", "$_selectedDurationMinutes min"),
                _buildSummaryRow("Folders", "${_selectedFolders.length}"),
                _buildSummaryRow("Files Accessed", "$_filesAccessedCount"),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          _buildPrimaryButton("Start new session", () => setState(() => _currentState = GuestState.setup)),
          const SizedBox(height: 24),
          Text("Redirecting in $_backCountdown...", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text("Go back", style: GoogleFonts.outfit(color: const Color(0xFF86868B), decoration: TextDecoration.underline)),
          )
        ],
      ),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildIllustration(String emoji) {
    return Container(
      width: 180, height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.1), blurRadius: 40, spreadRadius: 5)],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 80))),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onTap, {Color color = const Color(0xFF6C63FF), bool isLoading = false}) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
        child: Center(
          child: isLoading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(text, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildGhostButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0xFF2C2C2C))
        ),
        child: Center(
          child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}