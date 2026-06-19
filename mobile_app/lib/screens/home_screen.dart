import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/system_provider.dart';
import '../theme/colors.dart';
import '../widgets/cypher_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cp = context.read<ConnectionProvider>();
      if (cp.ip != null) {
        context.read<SystemProvider>()
          ..startPolling(cp.ip!)
          ..fetchActivity(cp.ip!);
      }
    });
  }

  @override
  void dispose() {
    context.read<SystemProvider>().stopPolling();
    super.dispose();
  }

  void _requireConnection(BuildContext context, VoidCallback action) {
    final cp = context.read<ConnectionProvider>();
    if (!cp.isConnected) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: CypherColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Not Connected', style: TextStyle(color: CypherColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          content: const Text(
            'Connect to your PC first to use this feature.',
            style: TextStyle(color: CypherColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/connection');
              },
              child: const Text('Connect', style: TextStyle(color: CypherColors.accent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: CypherColors.textMuted)),
            ),
          ],
        ),
      );
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();
    final sp = context.watch<SystemProvider>();

    return Scaffold(
      backgroundColor: CypherColors.bgDeep,
      body: SafeArea(
        child: IndexedStack(
          index: _activeTab,
          children: [
            _HomeTab(cp: cp, sp: sp, requireConnection: (cb) => _requireConnection(context, cb)),
            _MoreTab(requireConnection: (cb) => _requireConnection(context, cb)),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        activeTab: _activeTab,
        onTab: (i) => setState(() => _activeTab = i),
      ),
    );
  }
}

// ── HOME TAB ──────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final ConnectionProvider cp;
  final SystemProvider sp;
  final void Function(VoidCallback) requireConnection;
  const _HomeTab({required this.cp, required this.sp, required this.requireConnection});

  @override
  Widget build(BuildContext context) {
    final batteryPct = (sp.battery['percent'] as num?)?.toDouble() ?? 0.0;

    return CustomScrollView(
      slivers: [
        // Offline banner
        if (!cp.isConnected)
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/connection'),
              child: Container(
                color: CypherColors.accent.withOpacity(0.10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 14, color: CypherColors.accent),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Not connected — tap to connect',
                        style: TextStyle(fontSize: 12, color: CypherColors.accent),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: CypherColors.accent),
                  ],
                ),
              ),
            ),
          ),

        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(fontSize: 12, color: CypherColors.textMuted, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cp.pcName ?? 'CYPHER PC',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: CypherColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: cp.isConnected ? CypherColors.success : CypherColors.textDisabled,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            cp.isConnected ? 'Connected' : 'Offline',
                            style: const TextStyle(fontSize: 12, color: CypherColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/notifications'),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CypherColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CypherColors.border),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: CypherColors.textSecondary, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),

        // System metrics
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: const Text('SYSTEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CypherColors.textMuted, letterSpacing: 0.8)),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
            children: [
              _MetricTile(label: 'CPU',     value: '${sp.cpu.toInt()}%',        icon: Icons.speed_rounded,        color: CypherColors.cpu),
              _MetricTile(label: 'RAM',     value: '${sp.ram.toInt()}%',        icon: Icons.memory_rounded,       color: CypherColors.ram),
              _MetricTile(label: 'Storage', value: '${sp.disk.toInt()}%',       icon: Icons.storage_rounded,      color: CypherColors.storage),
              _MetricTile(label: 'Battery', value: '${batteryPct.toInt()}%',    icon: Icons.battery_charging_full_rounded, color: CypherColors.battery),
            ],
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // Quick actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: const Text('QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CypherColors.textMuted, letterSpacing: 0.8)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              _ActionTile(
                icon: Icons.folder_open_rounded,
                label: 'Get Files',
                subtitle: 'from PC',
                color: CypherColors.storage,
                onTap: () => requireConnection(() => Navigator.pushNamed(context, '/browser')),
              ),
              _ActionTile(
                icon: Icons.send_rounded,
                label: 'Send Files',
                subtitle: 'to PC',
                color: CypherColors.accent,
                onTap: () => requireConnection(() => Navigator.pushNamed(context, '/send')),
              ),
              _ActionTile(
                icon: Icons.screenshot_monitor_rounded,
                label: 'Screenshot',
                subtitle: 'capture',
                color: CypherColors.info,
                onTap: () => requireConnection(() => Navigator.pushNamed(context, '/recorder')),
              ),
              _ActionTile(
                icon: Icons.lock_rounded,
                label: 'Lock PC',
                subtitle: 'secure now',
                color: CypherColors.error,
                onTap: () => requireConnection(() {
                  final ip = context.read<ConnectionProvider>().ip;
                  if (ip != null) context.read<SystemProvider>().lock(ip);
                }),
              ),
            ],
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // Recent activity
        if (sp.activity.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CypherColors.textMuted, letterSpacing: 0.8)),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/activity'),
                    child: const Text('See all', style: TextStyle(fontSize: 12, color: CypherColors.accentLight, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: (sp.activity.length).clamp(0, 3),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = sp.activity[i] as Map<String, dynamic>? ?? {};
                return CypherCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: CypherColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['name'] ?? item['action'] ?? 'Action',
                          style: const TextStyle(fontSize: 13, color: CypherColors.textPrimary),
                        ),
                      ),
                      Text(
                        item['time'] ?? '',
                        style: const TextStyle(fontSize: 11, color: CypherColors.textMuted),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── METRIC TILE ───────────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CypherColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CypherColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CypherColors.textPrimary, height: 1),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: CypherColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── ACTION TILE ───────────────────────────────────────────────
class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: _pressed ? CypherColors.bgHover : CypherColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CypherColors.border),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: widget.color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CypherColors.textPrimary),
                ),
                Text(
                  widget.subtitle,
                  style: const TextStyle(fontSize: 11, color: CypherColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── MORE TAB ──────────────────────────────────────────────────
class _MoreTab extends StatelessWidget {
  final void Function(VoidCallback) requireConnection;
  const _MoreTab({required this.requireConnection});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _SectionHeader(title: 'Files & Transfer'),
        const SizedBox(height: 10),
        _MoreItem(icon: Icons.folder_rounded,           title: 'Browse Files',    subtitle: 'PC files',        onTap: () => requireConnection(() => Navigator.pushNamed(context, '/browser'))),
        _MoreItem(icon: Icons.send_rounded,             title: 'Send to PC',      subtitle: 'Upload files',    onTap: () => requireConnection(() => Navigator.pushNamed(context, '/send'))),
        _MoreItem(icon: Icons.content_paste_rounded,    title: 'Clipboard',       subtitle: 'Sync & history',  onTap: () => requireConnection(() => Navigator.pushNamed(context, '/clipboard'))),
        const SizedBox(height: 20),
        _SectionHeader(title: 'Control & Commands'),
        const SizedBox(height: 10),
        _MoreItem(icon: Icons.keyboard_rounded,         title: 'Remote Control',  subtitle: 'Type & hotkeys',  onTap: () => requireConnection(() => Navigator.pushNamed(context, '/controls'))),
        _MoreItem(icon: Icons.screenshot_monitor_rounded, title: 'Screenshot',    subtitle: 'Capture screen',  onTap: () => requireConnection(() => Navigator.pushNamed(context, '/recorder'))),
        _MoreItem(icon: Icons.power_settings_new_rounded, title: 'Power',         subtitle: 'Shutdown, sleep', onTap: () => requireConnection(() => Navigator.pushNamed(context, '/power'))),
        const SizedBox(height: 20),
        _SectionHeader(title: 'System'),
        const SizedBox(height: 10),
        _MoreItem(icon: Icons.settings_rounded,         title: 'Settings',        subtitle: 'Configuration',   onTap: () => Navigator.pushNamed(context, '/settings')),
        _MoreItem(icon: Icons.history_rounded,          title: 'Activity',        subtitle: 'Recent actions',  onTap: () => Navigator.pushNamed(context, '/activity')),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CypherColors.textMuted, letterSpacing: 0.8),
    );
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CypherCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CypherColors.bgOverlay,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: CypherColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: CypherColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: CypherColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: CypherColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── BOTTOM NAV ────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int activeTab;
  final void Function(int) onTab;

  const _BottomNav({required this.activeTab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CypherColors.bgCard,
        border: Border(top: BorderSide(color: CypherColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(index: 0,  active: activeTab, icon: Icons.home_rounded,         label: 'Home',    onTap: onTab),
              _NavItem(index: -1, active: -1,         icon: Icons.send_rounded,          label: 'Send',    onTap: (_) => Navigator.pushNamed(context, '/send')),
              _NavItem(index: -2, active: -1,         icon: Icons.keyboard_rounded,      label: 'Control', onTap: (_) => Navigator.pushNamed(context, '/controls')),
              _NavItem(index: 1,  active: activeTab, icon: Icons.more_horiz_rounded,    label: 'More',    onTap: onTab),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int active;
  final IconData icon;
  final String label;
  final void Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index >= 0 && index == active;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isActive ? CypherColors.accent : CypherColors.textMuted),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? CypherColors.accent : CypherColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
