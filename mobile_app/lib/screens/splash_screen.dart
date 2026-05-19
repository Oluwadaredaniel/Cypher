import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/illustrations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() {
    Timer(const Duration(milliseconds: 3200), () async {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFF0D0D0D);
    const Color accent = Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // Subtle Background Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: SvgPicture.string(
                '''<svg width="400" height="400" viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg"><circle cx="200" cy="200" r="180" stroke="white" stroke-width="1" fill="none"/></svg>''',
              ),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Illustration
                FadeInDown(
                  duration: const Duration(milliseconds: 1000),
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: accent.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)],
                    ),
                    child: Pulse(
                        duration: const Duration(seconds: 2),
                        child: CypherIllustrations.splashCore(),
                      ),
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // Wordmark with improved spacing
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLetter('C', 0, Colors.white),
                    _buildLetter('Y', 100, accent),
                    _buildLetter('P', 200, Colors.white),
                    _buildLetter('H', 300, Colors.white),
                    _buildLetter('E', 400, Colors.white),
                    _buildLetter('R', 500, Colors.white),
                  ],
                ),

                const SizedBox(height: 12),

                FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: Text(
                    'Your files. Anywhere.',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF86868B),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Progress Bar
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: FadeIn(
              delay: const Duration(milliseconds: 1200),
              child: Center(
                child: Container(
                  width: 160, height: 4,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                  child: Stack(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 2000),
                        builder: (context, value, _) => FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 10)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetter(String char, int delay, Color color) {
    return FadeInUp(
      delay: Duration(milliseconds: delay + 400),
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          char,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 56,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
          ),
        ),
      ),
    );
  }
}
