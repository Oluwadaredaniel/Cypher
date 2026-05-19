import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for built-in HapticFeedback
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cypher/screens/setup_screen.dart'; // Needed for direct navigation
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cypher/theme/app_theme.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;
  double _buttonScale = 1.0;

  void _handleConnect() async {
    // Haptic feedback on action
    await HapticFeedback.mediumImpact();
    
    if (_ipController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid IP address")),
      );
      return;
    }

    setState(() => _isConnecting = true);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pc_ip_address', _ipController.text);
    
    // Simulating network latency for the skeleton/loading state
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() => _isConnecting = false);
      // Navigate to Pairing
      Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': _ipController.text});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FadeIn( // Rule: 300ms fade in on load
            duration: const Duration(milliseconds: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Text(
                  "PC CONNECTION",
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Enter the PC address of your Windows PC running the CYPHER backend. If on a mobile hotspot, ensure 'Client Isolation' is disabled in your hotspot settings.",
                  style: GoogleFonts.outfit(
                    color: Colors.white54, 
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _ipController,
                  style: GoogleFonts.outfit(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "IPv4 Address",
                    hintText: "192.168.x.x",
                  ),
                ),
                const Spacer(),
                // Rule: Button press animation (scale to 0.97)
                GestureDetector(
                  onTapDown: (_) {
                    HapticFeedback.lightImpact();
                    setState(() => _buttonScale = 0.97);
                  },
                  onTapUp: (_) => setState(() => _buttonScale = 1.0),
                  onTapCancel: () => setState(() => _buttonScale = 1.0),
                  child: AnimatedScale(
                    scale: _buttonScale,
                    duration: const Duration(milliseconds: 100),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isConnecting ? null : _handleConnect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: const StadiumBorder(),
                        ),
                        child: _isConnecting 
                          ? const SizedBox(
                              height: 24, 
                              width: 24, 
                              child: CircularProgressIndicator(
                                color: Colors.white, 
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text("ESTABLISH LINK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}