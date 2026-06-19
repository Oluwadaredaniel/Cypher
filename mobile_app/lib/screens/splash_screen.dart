import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/storage_service.dart';
import '../theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _scale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final onboarded = await StorageService.getOnboarded();
    if (!onboarded) {
      Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final cp = context.read<ConnectionProvider>();

    // Auto-connect if enabled & already paired
    if (cp.autoConnectEnabled && cp.ip != null && cp.token != null) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }

    if (cp.isConnected) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/connection');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CypherColors.bgDeep,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: CypherColors.bgCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: CypherColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: CypherColors.accentGlow,
                          blurRadius: 48,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: CypherColors.accent,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'CYPHER',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: CypherColors.textPrimary,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your PC. In your pocket.',
                    style: TextStyle(
                      fontSize: 13,
                      color: CypherColors.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
