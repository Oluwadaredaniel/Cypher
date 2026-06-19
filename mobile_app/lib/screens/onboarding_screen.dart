import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/colors.dart';
import '../widgets/illustrations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _controller = PageController();
  late AnimationController _float;
  int _page = 0;

  static const _slides = [
    (
      title: 'Your files, always within reach',
      desc: 'Browse and grab anything from your PC — documents, videos, music — straight to your phone in seconds.',
      type: _SlideType.files,
    ),
    (
      title: 'Send anything to your PC instantly',
      desc: 'Photos, files, links — send from your phone and they appear on your PC immediately.',
      type: _SlideType.send,
    ),
    (
      title: 'Private, fast, no internet needed',
      desc: 'Everything happens on your own WiFi — no cloud, no strangers, just your devices talking directly.',
      type: _SlideType.security,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _checkDone();
  }

  Future<void> _checkDone() async {
    final done = await StorageService.getOnboarded();
    if (done && mounted) Navigator.pushReplacementNamed(context, '/setup');
  }

  @override
  void dispose() {
    _controller.dispose();
    _float.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await StorageService.setOnboarded(true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Skip
            Positioned(
              top: 8, right: 16,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip', style: TextStyle(color: CypherColors.textMuted, fontSize: 15)),
              ),
            ),

            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (p) => setState(() => _page = p),
                    itemBuilder: (_, i) => _Slide(slide: _slides[i], floatCtrl: _float),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                  child: Column(
                    children: [
                      // Page dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 7,
                          width: _page == i ? 22 : 7,
                          decoration: BoxDecoration(
                            color: _page == i ? CypherColors.accent : CypherColors.border,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        )),
                      ),
                      const SizedBox(height: 28),
                      _NextButton(
                        label: _page == _slides.length - 1 ? 'Get Started' : 'Next',
                        onTap: _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _SlideType { files, send, security }

class _Slide extends StatelessWidget {
  final ({String title, String desc, _SlideType type}) slide;
  final AnimationController floatCtrl;
  const _Slide({required this.slide, required this.floatCtrl});

  Widget _illustration() {
    return switch (slide.type) {
      _SlideType.files    => CypherIllustrations.filesIllustration(),
      _SlideType.send     => CypherIllustrations.sendIllustration(),
      _SlideType.security => CypherIllustrations.securityIllustration(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: floatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -6 * floatCtrl.value),
              child: child,
            ),
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                color: CypherColors.bgCard,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: CypherColors.accent.withOpacity(0.25), width: 1.5),
                boxShadow: [BoxShadow(color: CypherColors.accentGlow, blurRadius: 40, spreadRadius: -4)],
              ),
              child: Center(child: _illustration()),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CypherColors.textPrimary, height: 1.25),
          ),
          const SizedBox(height: 14),
          Text(
            slide.desc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: CypherColors.textSecondary, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NextButton({required this.label, required this.onTap});

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: CypherColors.accent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [BoxShadow(color: CypherColors.accentGlow, blurRadius: 20, spreadRadius: -4)],
          ),
          child: Center(
            child: Text(widget.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
