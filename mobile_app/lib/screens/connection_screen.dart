import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/discovery_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';
import '../widgets/cypher_card.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _ipCtrl = TextEditingController();
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionProvider>().scan();
    });
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectTo(DiscoveredPc pc) async {
    final cp = context.read<ConnectionProvider>();
    final result = await cp.connectTo(pc);
    if (!mounted) return;

    if (result) {
      if (cp.status == ConnectionStatus.pairing) {
        Navigator.pushReplacementNamed(context, '/pairing');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      _showError(cp.error ?? 'Connection failed');
    }
  }

  Future<void> _connectManually() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    await _connectTo(DiscoveredPc(ip: ip, name: 'PC'));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: CypherColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<ConnectionProvider>(
          builder: (_, cp, __) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Find Your PC', style: AppTheme.headline(context)),
                      const SizedBox(height: 6),
                      Text(
                        'Make sure CYPHER is running on your PC and both devices are on the same network.',
                        style: AppTheme.body(context),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('NEARBY DEVICES', style: AppTheme.label(context)),
                      if (cp.isScanning)
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: CypherColors.accentLight),
                        )
                      else
                        GestureDetector(
                          onTap: cp.scan,
                          child: const Text('Scan again', style: TextStyle(fontSize: 12, color: CypherColors.accentBright)),
                        ),
                    ],
                  ),
                ),
              ),

              if (cp.isScanning)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: CypherColors.accent)),
                  ),
                )
              else if (cp.discovered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CypherCard(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded, color: CypherColors.textMuted, size: 32),
                          const SizedBox(height: 12),
                          Text('No PCs found', style: AppTheme.subtitle(context)),
                          const SizedBox(height: 4),
                          Text(
                            'Make sure CYPHER desktop is running.\nTry connecting manually below.',
                            style: AppTheme.body(context),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: cp.discovered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final pc = cp.discovered[i];
                      return CypherCard(
                        onTap: () => _connectTo(pc),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: CypherColors.accentDim,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.desktop_windows_rounded, color: CypherColors.accent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pc.name, style: AppTheme.subtitle(context)),
                                  Text(pc.ip,   style: AppTheme.caption(context)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: CypherColors.textMuted),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showManual = !_showManual),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showManual ? 'Hide manual entry' : 'Enter IP manually',
                              style: const TextStyle(fontSize: 13, color: CypherColors.textMuted),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showManual ? Icons.expand_less : Icons.expand_more,
                              size: 16, color: CypherColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                      if (_showManual) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ipCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '192.168.43.2',
                            prefixIcon: Icon(Icons.router_rounded, size: 18),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CypherButton(
                          label: 'Connect',
                          onTap: _connectManually,
                          loading: cp.status == ConnectionStatus.connecting,
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/guide'),
                        child: const Text('Setup guide'),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                        child: const Text(
                          'Explore without connecting',
                          style: TextStyle(fontSize: 12, color: CypherColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}