import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_container.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F17),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Welcome to", style: GoogleFonts.roboto(fontSize: 16, color: Colors.white38)),
                    Text("CYPHER ECOSYSTEM", style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF6C63FF))),
                    const SizedBox(height: 12),
                    Text("Control your computer from your phone easily and securely.",
                      style: GoogleFonts.roboto(fontSize: 14, color: Colors.white24, height: 1.5)),
                    const SizedBox(height: 40),

                    _buildStep(
                      "01",
                      "LINK YOUR PC",
                      "Open CYPHER on your computer. It will show a 6-digit code. Enter that code on your phone to connect the two devices.",
                      Icons.qr_code_scanner_rounded
                    ),

                    _buildStep(
                      "02",
                      "FILE SHARING",
                      "Browse your computer's files instantly. Hold down on any file to download it, or send photos and documents from your phone directly to your PC.",
                      Icons.sync_alt_rounded
                    ),

                    _buildStep(
                      "03",
                      "REMOTE COMMANDS",
                      "Use the 'Controls' tab to trigger system power states (Shutdown, Sleep, Lock) or manage active Windows processes in real-time.",
                      Icons.terminal_rounded
                    ),

                    _buildStep(
                      "04",
                      "GUEST ACCESS",
                      "Need to share a file with someone nearby? Generate a temporary Guest Link. They can scan your phone's QR code to access specific folders without needing the app.",
                      Icons.person_add_alt_1_rounded
                    ),

                    const SizedBox(height: 40),
                    _buildSupportCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      expandedHeight: 60,
      floating: true,
    );
  }

  Widget _buildStep(String number, String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2))
                ),
                child: Center(child: Text(number, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF)))),
              ),
              Container(width: 1, height: 100, color: Colors.white.withOpacity(0.05)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: const Color(0xFF6C63FF), size: 20),
                      const SizedBox(width: 12),
                      Text(title, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(description, style: GoogleFonts.roboto(fontSize: 13, color: Colors.white38, height: 1.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF6C63FF),
      opacity: 0.05,
      child: Column(
        children: [
          const Icon(Icons.help_outline_rounded, color: Color(0xFF6C63FF), size: 32),
          const SizedBox(height: 16),
          Text("Need Technical Support?", style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Visit our documentation or join the community discord for real-time help.",
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(fontSize: 12, color: Colors.white24)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: const Text("VISIT HUB"),
            ),
          )
        ],
      ),
    );
  }
}
