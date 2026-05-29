import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../widgets/glass_container.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: const Color(0xFF080F17),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: GlassContainer(
                  width: 100, height: 100,
                  borderRadius: BorderRadius.circular(100),
                  child: Icon(Icons.wifi_protected_setup_rounded, color: accent, size: 40),
                ),
              ),
              const SizedBox(height: 40),
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: Text("Connecting to your computer", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text("Initializing peer-to-peer encryption protocols...", textAlign: TextAlign.center, style: GoogleFonts.roboto(color: Colors.white24)),
              ),
              const SizedBox(height: 60),
              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ],
          ),
        ),
      ),
    );
  }
}
