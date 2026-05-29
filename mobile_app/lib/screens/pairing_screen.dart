import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class PairingScreen extends StatefulWidget {
  final String pcIpAddress;
  const PairingScreen({super.key, required this.pcIpAddress});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _nameController = TextEditingController(text: "Mobile Client");
  bool _isPairing = false;

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _nameController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _attemptPairing();
    }
  }

  Future<void> _attemptPairing() async {
    setState(() => _isPairing = true);
    final pairingCode = _controllers.map((c) => c.text).join();

    try {
      final response = await http.post(
        Uri.parse('http://${widget.pcIpAddress}:5000/pair_device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pairing_code': pairingCode,
          'device_id': 'mobile-${DateTime.now().millisecondsSinceEpoch}',
          'device_name': _nameController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_paired', true);
        await prefs.setString('pc_ip_address', widget.pcIpAddress);
        await prefs.setString('auth_token', token);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home', arguments: {
            'pcIpAddress': widget.pcIpAddress,
            'authToken': token
          });
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Pairing Code")));
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Failed: $e")));
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Atmospheric Glow
          Positioned(
            top: -150, right: -150,
            child: Container(
              width: 500, height: 500,
              decoration: BoxDecoration(color: accent.withOpacity(0.08), shape: BoxShape.circle),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120), child: Container(color: Colors.transparent)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_moon_outlined, color: accent, size: 24),
                          const SizedBox(width: 12),
                          Text("CYPHER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24))),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        // Pairing Card
                        GlassContainer(
                          padding: const EdgeInsets.all(32),
                          borderRadius: BorderRadius.circular(32),
                          child: Column(
                            children: [
                              Text("Link your Phone", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                              const SizedBox(height: 8),
                              Text("Enter the 6-digit code shown on your computer to start the connection.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.roboto(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                              const SizedBox(height: 48),

                              // Code Input Area
                              Text("VERIFICATION CODE", style: GoogleFonts.roboto(fontSize: 10, color: accent, letterSpacing: 2)),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) => _buildCodeBox(index, isDark)),
                              ),

                              const SizedBox(height: 48),

                              // Device Naming Area
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text("IDENTIFY THIS DEVICE", style: GoogleFonts.roboto(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.24), letterSpacing: 1)),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  style: GoogleFonts.roboto(color: isDark ? Colors.white : Colors.black),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    border: InputBorder.none,
                                    suffixIcon: Icon(Icons.phone_android_rounded, color: accent.withOpacity(0.4)),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Connect Button
                              SizedBox(
                                width: double.infinity, height: 64,
                                child: ElevatedButton(
                                  onPressed: _isPairing ? null : _attemptPairing,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    elevation: 0,
                                  ),
                                  child: _isPairing
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text("Connect Device", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.arrow_forward_rounded),
                                        ],
                                      ),
                                ),
                              ),

                              const SizedBox(height: 20),
                              // Security Indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 8)])),
                                  const SizedBox(width: 10),
                                  Text("AES-256 Encrypted Connection", style: GoogleFonts.roboto(fontSize: 10, color: const Color(0xFF10B981).withOpacity(0.6))),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                        TextButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.help_outline_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), size: 18),
                          label: Text("Having trouble connecting?", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.3))),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBox(int index, bool isDark) {
    final accent = const Color(0xFF6C63FF);
    return Container(
      width: 45, height: 60,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _focusNodes[index].hasFocus ? accent : (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (v) => _onCodeChanged(v, index),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: accent),
        decoration: const InputDecoration(counterText: "", border: InputBorder.none),
      ),
    );
  }
}
