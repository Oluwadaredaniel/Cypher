import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';

// MasterControlScreen — local admin panel stub.
// The old implementation called https://cypher-3ctq.onrender.com (cloud) which violates
// the local-network-only constraint. Replaced with a local info screen.
class MasterControlScreen extends StatelessWidget {
  const MasterControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About CYPHER')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/icon/icon.png', width: 80, height: 80, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('CYPHER', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3, color: CypherColors.textPrimary)),
            ),
            const Center(
              child: Text('PC Remote Control', style: TextStyle(fontSize: 13, color: CypherColors.textSecondary)),
            ),
            const SizedBox(height: 32),
            _Section(
              title: 'About',
              rows: const [
                ('Version', '2.0.0'),
                ('Publisher', 'Emerald Dev'),
                ('Architecture', '100% Local Network'),
                ('Protocol', 'HTTP + mDNS on port 5000'),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: 'Privacy',
              rows: const [
                ('Cloud Services', 'None'),
                ('Data Collection', 'None'),
                ('Analytics', 'None'),
                ('Telemetry', 'None'),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CypherColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CypherColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: CypherColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All data stays on your local network. No information is ever sent to external servers.',
                      style: AppTheme.caption(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: CypherColors.accent)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: CypherColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CypherColors.border),
          ),
          child: Column(
            children: List.generate(rows.length, (i) {
              final (label, value) = rows[i];
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 13, color: CypherColors.textSecondary)),
                        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CypherColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
