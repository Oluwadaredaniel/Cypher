import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';
import '../widgets/cypher_card.dart';

// Setup screen — shown from onboarding before first pair.
// Duplicates the discovery + manual-IP flow from ConnectionScreen,
// but keeps its own route (/setup) for the onboarding funnel.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ipCtrl = TextEditingController();
  bool _testing = false;
  bool _scanning = true;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionProvider>().scan();
      _scanTimer = Timer(const Duration(seconds: 20), () {
        if (mounted) setState(() => _scanning = false);
      });
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect(String ip) async {
    setState(() => _testing = true);
    try {
      final ok = await ApiService.ping(ip);
      if (!mounted) return;
      if (ok) {
        Navigator.pushNamed(context, '/pairing', arguments: {'pcIpAddress': ip});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Can't reach PC at that address")));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection failed')));
    }
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.link_rounded, color: CypherColors.accent, size: 32),
              const SizedBox(height: 16),
              const Text('Connect to PC', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CypherColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Enable your phone hotspot and connect your PC to it. Then launch CYPHER on your PC.', style: TextStyle(color: CypherColors.textSecondary, fontSize: 14, height: 1.5)),

              const SizedBox(height: 28),

              // Info chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: CypherColors.accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CypherColors.accent.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: CypherColors.accentLight, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Both devices must be on the same WiFi or hotspot network.', style: AppTheme.caption(context))),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Discovered PCs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('FOUND ON NETWORK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: CypherColors.textMuted)),
                  if (!_scanning)
                    GestureDetector(
                      onTap: () {
                        setState(() => _scanning = true);
                        context.read<ConnectionProvider>().scan();
                        _scanTimer?.cancel();
                        _scanTimer = Timer(const Duration(seconds: 20), () {
                          if (mounted) setState(() => _scanning = false);
                        });
                      },
                      child: const Text('REFRESH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CypherColors.accent)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_scanning && (cp.discovered.isEmpty))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: CypherColors.accent, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Scanning…', style: TextStyle(color: CypherColors.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              else if (cp.discovered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('No PCs found automatically', style: TextStyle(color: CypherColors.textMuted))),
                )
              else
                ...cp.discovered.map((pc) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CypherCard(
                    onTap: () => _connect(pc.ip),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.desktop_windows_rounded, color: CypherColors.accentLight, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CypherColors.textPrimary)),
                              Text(pc.ip, style: AppTheme.caption(context)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: CypherColors.textMuted, size: 20),
                      ],
                    ),
                  ),
                )),

              const SizedBox(height: 28),

              const Text('OR ENTER MANUALLY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: CypherColors.textMuted)),
              const SizedBox(height: 10),
              TextField(
                controller: _ipCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'e.g. 192.168.43.2'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              CypherButton(
                label: 'Connect',
                onTap: _ipCtrl.text.trim().isEmpty || _testing ? null : () => _connect(_ipCtrl.text.trim()),
                loading: _testing,
              ),

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/guide'),
                  child: const Text("Can't connect? View troubleshooting", style: TextStyle(color: CypherColors.accent, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
