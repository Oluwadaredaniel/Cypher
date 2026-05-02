import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DisconnectedScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final VoidCallback onReconnected;

  const DisconnectedScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
    required this.onReconnected,
  });

  @override
  State<DisconnectedScreen> createState() => _DisconnectedScreenState();
}

class _DisconnectedScreenState extends State<DisconnectedScreen> with TickerProviderStateMixin {
  // Connection State
  bool _isRetrying = false;
  bool _isSuccess = false;
  int _retryCountdown = 10;
  Timer? _autoRetryTimer;
  Timer? _countdownTimer;

  // Animation Controllers
  late AnimationController _dashController;

  @override
  void initState() {
    super.initState();
    
    _dashController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startAutoRetryLogic();
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    _countdownTimer?.cancel();
    _dashController.dispose();
    super.dispose();
  }

  void _startAutoRetryLogic() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_retryCountdown > 1) {
        setState(() => _retryCountdown--);
      } else {
        _attemptReconnect(silent: true);
      }
    });
  }

  Future<void> _attemptReconnect({bool silent = false}) async {
    if (_isRetrying || _isSuccess) return;

    if (!silent) setState(() => _isRetrying = true);

    try {
      final response = await http
          .get(Uri.parse('http://${widget.pcIpAddress}:5000/ping'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _handleSuccess();
      } else {
        _handleFailure(silent);
      }
    } catch (e) {
      _handleFailure(silent);
    }
  }

  void _handleSuccess() {
    _autoRetryTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _isRetrying = false;
      _isSuccess = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onReconnected();
    });
  }

  void _handleFailure(bool silent) {
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Still can't connect")),
      );
    }
    setState(() {
      _isRetrying = false;
      _retryCountdown = 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: FadeIn(
          duration: const Duration(milliseconds: 300),
          child: _isSuccess ? _buildSuccessState() : _buildDisconnectedState(),
        ),
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return Column(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  height: 120,
                  width: 240,
                  child: AnimatedBuilder(
                    animation: _dashController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: BrokenConnectionPainter(animationValue: _dashController.value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Text("Lost connection to your PC",
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("Make sure your PC is on and connected to your phone's hotspot",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
                const SizedBox(height: 40),
                
                // Reasons Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("What might have happened",
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _reasonRow("📱", "Your phone's hotspot turned off"),
                      _reasonRow("💤", "Your PC went to sleep"),
                      _reasonRow("📶", "You moved out of WiFi range"),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Action Buttons
                _buildPrimaryButton(),
                const SizedBox(height: 12),
                _buildGhostButton("Change PC address", _showIpEditSheet),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text("Go to home", 
                      style: GoogleFonts.outfit(color: const Color(0xFF86868B), decoration: TextDecoration.underline)),
                ),
                const SizedBox(height: 16),
                Text("Retrying in ${_retryCountdown}s...", 
                    style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ZoomIn(
            duration: const Duration(milliseconds: 400),
            child: Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          Text("Reconnected!", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Taking you back...", style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _reasonRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return GestureDetector(
      onTap: () => _attemptReconnect(),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(100)),
        child: Center(
          child: _isRetrying 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text("Try reconnecting", style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _showIpEditSheet() {
    final controller = TextEditingController(text: widget.pcIpAddress);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Edit PC Address", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            _buildGhostButton("Confirm", () async {
              (await SharedPreferences.getInstance()).setString('pc_ip_address', controller.text.trim());
              if (mounted) Navigator.pop(context);
              _attemptReconnect();
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class BrokenConnectionPainter extends CustomPainter {
  final double animationValue;
  BrokenConnectionPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final devicePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    final dashPaint = Paint()
      ..color = const Color(0xFFFF453A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw Device Rects
    RRect leftDevice = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height/4, 60, 60), const Radius.circular(12));
    RRect rightDevice = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 60, size.height/4, 60, 60), const Radius.circular(12));
    
    canvas.drawRRect(leftDevice, devicePaint);
    canvas.drawRRect(rightDevice, devicePaint);

    // Draw Dashed Line with offset
    double dashWidth = 8, dashSpace = 6;
    double startX = 70;
    double endX = size.width - 70;
    double y = size.height / 2;
    
    double currentX = startX + (animationValue * (dashWidth + dashSpace));
    while (currentX < endX) {
      canvas.drawLine(Offset(currentX, y), Offset(currentX + dashWidth, y), dashPaint);
      currentX += dashWidth + dashSpace;
    }
    
    // Draw "Broken" center gap overlay
    final bgPaint = Paint()..color = const Color(0xFF0D0D0D);
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width/2, y), width: 20, height: 10), bgPaint);
  }

  @override
  bool shouldRepaint(BrokenConnectionPainter oldDelegate) => true;
}