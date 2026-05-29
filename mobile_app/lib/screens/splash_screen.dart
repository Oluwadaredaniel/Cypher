import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  String _statusText = "Connecting to your PC...";
  int _stageIndex = 0;
  final List<Map<String, dynamic>> _stages = [
    {'limit': 0.2, 'text': "Checking connection..."},
    {'limit': 0.45, 'text': "Finding computer..."},
    {'limit': 0.75, 'text': "Linking devices..."},
    {'limit': 0.9, 'text': "Checking access..."},
    {'limit': 1.0, 'text': "Connected."},
  ];

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  void _startInitialization() {
    // Progress Simulation
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progress < 1.0) {
          _progress += (0.01 + (0.03 * (1 - _progress))); // Variable speed
          if (_stageIndex < _stages.length && _progress >= _stages[_stageIndex]['limit']) {
            _statusText = _stages[_stageIndex]['text'];
            _stageIndex++;
          }
        } else {
          _progress = 1.0;
          timer.cancel();
          _navigateToNext();
        }
      });
    });
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isPaired = prefs.getBool('is_paired') ?? false;
    final ip = prefs.getString('pc_ip_address') ?? '';
    final token = prefs.getString('auth_token') ?? '';

    if (isPaired && ip.isNotEmpty && token.isNotEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home', arguments: {'pcIpAddress': ip, 'authToken': token});
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
    }
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
          // Background Atmospheric Elements
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(color: accent.withOpacity(0.05), shape: BoxShape.circle),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120), child: Container(color: Colors.transparent)),
            ),
          ),
          Positioned(
            bottom: -100, right: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(color: accent.withOpacity(0.05), shape: BoxShape.circle),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120), child: Container(color: Colors.transparent)),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Brand Anchor
                FadeIn(
                  duration: const Duration(milliseconds: 1200),
                  child: Pulse(
                    infinite: true,
                    duration: const Duration(seconds: 4),
                    child: GlassContainer(
                      width: 100, height: 100,
                      borderRadius: BorderRadius.circular(100),
                      opacity: 0.1,
                      child: Center(
                        child: Icon(Icons.shield_moon_outlined, color: accent, size: 48),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Brand Identity
                FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  child: Column(
                    children: [
                      Text(
                        "CYPHER",
                        style: GoogleFonts.roboto(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "STARTING UP",
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),

                // Status & Progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _statusText,
                                  style: GoogleFonts.roboto(
                                    fontSize: 11,
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  "${(_progress * 100).toInt()}%",
                                  style: GoogleFonts.roboto(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _progress,
                                minHeight: 2,
                                backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                                valueColor: AlwaysStoppedAnimation(accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Contextual Detail Row
                      FadeInUp(
                        delay: const Duration(milliseconds: 500),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 8)],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Secure Connection Active",
                              style: GoogleFonts.roboto(
                                fontSize: 10,
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
