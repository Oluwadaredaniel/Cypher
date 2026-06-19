import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';

class DisconnectedScreen extends StatefulWidget {
  const DisconnectedScreen({super.key});

  @override
  State<DisconnectedScreen> createState() => _DisconnectedScreenState();
}

class _DisconnectedScreenState extends State<DisconnectedScreen> {
  bool _retrying = false;
  bool _reconnected = false;
  int _countdown = 10;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        _tryReconnect(silent: true);
      }
    });
  }

  Future<void> _tryReconnect({bool silent = false}) async {
    if (_retrying || _reconnected) return;
    if (!silent) setState(() => _retrying = true);

    final cp = context.read<ConnectionProvider>();
    if (cp.ip != null) {
      await cp.connectManually(cp.ip!);
    }

    if (!mounted) return;
    if (cp.isConnected) {
      setState(() => _reconnected = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() { _retrying = false; _countdown = 10; });
      _startCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _reconnected ? _buildSuccess() : _buildMain(),
        ),
      ),
    );
  }

  Widget _buildMain() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
          const SizedBox(height: 32),

          // Broken connection illustration
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: CypherColors.error.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: CypherColors.error.withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.wifi_off_rounded, color: CypherColors.error, size: 40),
            ),
          ),
          const SizedBox(height: 28),

          const Center(
            child: Text(
              'Lost connection to PC',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CypherColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Make sure your PC is on and on the\nsame network as your phone.',
              style: TextStyle(color: CypherColors.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 36),

          // Reasons card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CypherColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CypherColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What might have happened', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CypherColors.textPrimary)),
                const SizedBox(height: 12),
                ...[
                  (Icons.phone_android_rounded, 'Phone hotspot turned off'),
                  (Icons.bedtime_rounded,       'PC went to sleep'),
                  (Icons.wifi_rounded,           'Moved out of WiFi range'),
                ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(e.$1, color: CypherColors.textMuted, size: 16),
                      const SizedBox(width: 10),
                      Text(e.$2, style: const TextStyle(fontSize: 13, color: CypherColors.textSecondary)),
                    ],
                  ),
                )),
              ],
            ),
          ),

          const SizedBox(height: 36),

          CypherButton(
            label: 'Try Reconnecting',
            onTap: _tryReconnect,
            loading: _retrying,
          ),
          const SizedBox(height: 12),
          CypherButton(
            label: 'Find New PC',
            variant: CypherButtonVariant.secondary,
            onTap: () => Navigator.pushReplacementNamed(context, '/connection'),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _retrying ? 'Connecting…' : 'Auto-retrying in ${_countdown}s',
              style: AppTheme.caption(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: CypherColors.success, size: 72),
          SizedBox(height: 20),
          Text('Reconnected!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CypherColors.textPrimary)),
          SizedBox(height: 6),
          Text('Taking you back…', style: TextStyle(color: CypherColors.textSecondary)),
        ],
      ),
    );
  }
}
