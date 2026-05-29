import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: "Access files from your PC",
      description: "Securely browse and manage your desktop files from anywhere with military-grade encryption.",
      child: _BentoFilesIllustration(),
    ),
    OnboardingSlide(
      title: "Control your computer remotely",
      description: "Securely access your workspace from any device, anywhere in the world with zero latency.",
      child: _BentoRemoteIllustration(),
    ),
    OnboardingSlide(
      title: "Your Data. Your Control.",
      description: "No central servers, no backdoors—just pure, encrypted peer-to-peer communication.",
      child: _BentoSecurityIllustration(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) Navigator.pushReplacementNamed(context, '/setup');
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
            top: 200, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(color: accent.withOpacity(0.05), shape: BoxShape.circle),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 120), child: Container(color: Colors.transparent)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Nav
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_moon_outlined, color: accent, size: 24),
                          const SizedBox(width: 8),
                          Text("CYPHER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
                        ],
                      ),
                      TextButton(
                        onPressed: _finishOnboarding,
                        child: Text("Skip", style: GoogleFonts.roboto(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), fontSize: 14)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return _buildSlide(_slides[index], isDark);
                    },
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Progress Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (index) {
                          bool active = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: active ? 24 : 6,
                            decoration: BoxDecoration(
                              color: active ? accent : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 48),
                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 10,
                            shadowColor: accent.withOpacity(0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _slides.length - 1 ? "Start Experience" : "Continue",
                                style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
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

  Widget _buildSlide(OnboardingSlide slide, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Center(child: slide.child)),
          const SizedBox(height: 60),
          FadeInUp(
            key: ValueKey(_currentPage),
            duration: const Duration(milliseconds: 600),
            child: Column(
              children: [
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, height: 1.1),
                ),
                const SizedBox(height: 20),
                Text(
                  slide.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(fontSize: 15, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final Widget child;
  OnboardingSlide({required this.title, required this.description, required this.child});
}

// --- BENTO ILLUSTRATIONS ---

class _BentoFilesIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF6C63FF);
    return Container(
      width: 300, height: 300,
      child: Stack(
        children: [
          Positioned(
            left: 20, top: 40,
            child: _BentoCard(
              width: 120, height: 200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.folder_open_rounded, color: accent, size: 40),
                  Column(
                    children: [
                      _Line(width: 40, color: accent.withOpacity(0.2)),
                      const SizedBox(height: 8),
                      _Line(width: 60),
                      const SizedBox(height: 8),
                      _Line(width: 30),
                    ],
                  )
                ],
              ),
            ),
          ),
          Positioned(
            right: 20, top: 60,
            child: _BentoCard(
              width: 130, height: 100,
              color: accent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.desktop_windows_rounded, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text("CONNECTED", style: GoogleFonts.roboto(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 40, bottom: 40,
            child: _BentoCard(
              width: 100, height: 100,
              child: Icon(Icons.verified_user_rounded, color: const Color(0xFFFFB786), size: 40),
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoRemoteIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF6C63FF);
    return Container(
      width: 300, height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 50,
            child: _BentoCard(
              width: 220, height: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Dot(color: Colors.redAccent.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      _Dot(color: Colors.amberAccent.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      _Dot(color: Colors.greenAccent.withOpacity(0.4)),
                    ],
                  ),
                  const Spacer(),
                  Align(alignment: Alignment.bottomRight, child: Icon(Icons.near_me_rounded, color: accent, size: 40)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30, right: 30,
            child: Container(
              width: 90, height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF192029),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 4),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
              ),
              child: Center(
                child: Icon(Icons.settings_input_component_rounded, color: accent, size: 32),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _BentoSecurityIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF6C63FF);
    return Container(
      width: 300, height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GlassContainer(
            width: 200, height: 200,
            borderRadius: BorderRadius.circular(40),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Pulse(
                    infinite: true,
                    child: Icon(Icons.security_rounded, color: accent, size: 80),
                  ),
                  const SizedBox(height: 16),
                  Text("ENCRYPTED", style: GoogleFonts.roboto(fontSize: 10, letterSpacing: 2, color: accent)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 40, right: 20,
            child: _SystemStatus(label: "PHONE", icon: Icons.smartphone_rounded, color: const Color(0xFFFFB786)),
          ),
          Positioned(
            bottom: 40, left: 20,
            child: _SystemStatus(label: "COMPUTER", icon: Icons.computer_rounded, color: accent),
          ),
        ],
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;
  final Color? color;
  const _BentoCard({required this.width, required this.height, required this.child, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF192029).withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}

class _Line extends StatelessWidget {
  final double width;
  final Color? color;
  const _Line({required this.width, this.color});
  @override
  Widget build(BuildContext context) => Container(width: width, height: 4, decoration: BoxDecoration(color: color ?? Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)));
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _SystemStatus extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SystemStatus({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: GoogleFonts.roboto(fontSize: 7, color: Colors.white38)),
              Text("Online", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          )
        ],
      ),
    );
  }
}
