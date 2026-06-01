import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Timer(const Duration(seconds: 3), () => _navigateToNext());
  }

  void _navigateToNext() async {
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
      backgroundColor: const Color(0xFF080F17), // Always dark for that classic feel
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Original Pulsing Shield
            Pulse(
              infinite: true,
              duration: const Duration(seconds: 2),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.1), width: 1),
                ),
                child: Icon(Icons.shield_moon_outlined, color: accent, size: 64),
              ),
            ),

            const SizedBox(height: 48),

            // Classic Clean Brand
            FadeIn(
              duration: const Duration(seconds: 1),
              child: Column(
                children: [
                  Text(
                    "CYPHER",
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "SECURING CONNECTION",
                    style: GoogleFonts.roboto(
                      fontSize: 10,
                      color: Colors.white24,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 64),

            // Minimalist Progress
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withOpacity(0.03),
                  valueColor: AlwaysStoppedAnimation(accent),
                  minHeight: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
