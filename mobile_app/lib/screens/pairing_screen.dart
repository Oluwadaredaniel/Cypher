import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io'; // Added for SocketException handling
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

enum PairingStatus { input, loading, success, error }

class PairingScreen extends StatefulWidget {
  final String pcIpAddress;
  const PairingScreen({super.key, required this.pcIpAddress});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late AnimationController _floatController;
  late AnimationController _particleController;
  AnimationController? _shakeController;

  PairingStatus _status = PairingStatus.input;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _particleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    // Auto-focus the first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    _floatController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  bool get _isCodeComplete => _controllers.every((c) => c.text.isNotEmpty);

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _handlePairing(); // Auto-submit when last digit entered
      }
    }
    setState(() {});
  }

  void _onKeyEvent(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return "${androidInfo.manufacturer} ${androidInfo.model}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.name ?? "iPhone";
    }
    return "Mobile Device";
  }

  Future<void> _handlePairing() async {
    if (!_isCodeComplete || _status == PairingStatus.loading) return;

    setState(() {
      _status = PairingStatus.loading;
      _errorMessage = "";
    });

    final code = _controllers.map((c) => c.text).join();
    final deviceId = const Uuid().v4();

    try {
      final deviceName = await _getDeviceName();
      final cleanIp = widget.pcIpAddress.trim();

      // Update: Route updated to /pair_device as per server.py audit
      final url = Uri.parse('http://$cleanIp:5000/pair_device');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'pairing_code': code,
          'device_id': deviceId,
          'device_name': deviceName,
        }),
      ).timeout(const Duration(seconds: 10));

      // --- AUDIT FIX: Granular Error Handling & Persistence ---
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String authToken = data['token'];
        
        // PERSISTENCE UPDATE: Saving credentials for Activity/Notification screens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', authToken);
        await prefs.setString('device_id', deviceId);
        await prefs.setString('pc_ip_address', cleanIp);
        await prefs.setBool('is_paired', true);

        setState(() => _status = PairingStatus.success);
        _particleController.forward();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // Navigate and clear stack so user cannot "go back" to pairing
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/home', 
              (route) => false, 
              arguments: {
                'pcIpAddress': cleanIp,
                'authToken': authToken,
              },
            );
          }
        });
      } else if (response.statusCode == 401) {
        _triggerError("Wrong code. Double-check the code on your PC.");
      } else if (response.statusCode == 500) {
        _triggerError("Something went wrong on your PC. Try restarting CYPHER.");
      } else {
        _triggerError("Unexpected error (${response.statusCode}). Please try again.");
      }
    } on TimeoutException {
      _triggerError("Your PC took too long to respond. Make sure CYPHER is open.");
    } on SocketException {
      _triggerError("Can't reach your PC. Check your hotspot is on.");
    } catch (e) {
      _triggerError("Something went wrong. Please try again.");
    }
  }

  void _triggerError(String msg) {
    if (!mounted) return;
    setState(() {
      _status = PairingStatus.error;
      _errorMessage = msg;
    });

    // Shake the input boxes
    _shakeController?.forward(from: 0.0);

    // AUDIT FIX: Clear after 1.5s, return focus to start, and reset status
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        for (var c in _controllers) { c.clear(); }
        setState(() {
          _status = PairingStatus.input;
          _errorMessage = "";
        });
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  FadeInDown(
                    child: Text("Almost there",
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Text("Enter the 6-digit code from your PC screen",
                        style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
                  ),
                  const SizedBox(height: 40),
                  _buildIllustration(),
                  const SizedBox(height: 40),
                  _buildInputSection(),
                  const Spacer(),
                  _buildActionSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          if (_status == PairingStatus.success) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, sin(_floatController.value * 2 * pi) * 10),
          child: child,
        );
      },
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2), width: 2),
            boxShadow: [
              BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.1), blurRadius: 30, spreadRadius: 5)
            ]
        ),
        child: const Center(child: Text("🔐", style: TextStyle(fontSize: 64))),
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      children: [
        ShakeX(
          manualTrigger: true,
          controller: (controller) => _shakeController = controller,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) => _buildCodeBox(index)),
          ),
        ),
        const SizedBox(height: 25),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _status == PairingStatus.error ? _errorMessage : "Connected to: ${widget.pcIpAddress}",
            key: ValueKey(_status == PairingStatus.error ? _errorMessage : "normal"),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                color: _status == PairingStatus.error ? Colors.redAccent : const Color(0xFF86868B),
                fontSize: 14,
                fontWeight: _status == PairingStatus.error ? FontWeight.w600 : FontWeight.normal
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeBox(int index) {
    return Container(
      width: 48,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: _focusNodes[index].hasFocus
                ? const Color(0xFF6C63FF)
                : (_status == PairingStatus.error ? Colors.redAccent.withOpacity(0.5) : const Color(0xFF2C2C2C)),
            width: 2
        ),
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onKeyEvent(index, event),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 1,
          showCursor: false,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(counterText: "", border: InputBorder.none),
          onChanged: (v) => _onDigitChanged(index, v),
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    bool active = _isCodeComplete && _status != PairingStatus.loading;
    return FadeInUp(
      child: GestureDetector(
        onTap: active ? _handlePairing : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF6C63FF) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: active ? [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))] : [],
          ),
          child: Center(
            child: _status == PairingStatus.loading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text("Pair Device", style: GoogleFonts.outfit(color: active ? Colors.white : Colors.white24, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: const Color(0xFF0D0D0D),
      child: Center(
        child: ZoomIn(
          duration: const Duration(milliseconds: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF6C63FF), size: 120),
              const SizedBox(height: 24),
              Text("Sync Complete", style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Your phone is now linked", style: GoogleFonts.outfit(color: Colors.white60, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}