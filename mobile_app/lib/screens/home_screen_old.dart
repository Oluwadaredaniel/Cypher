import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/system_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_card.dart';
import '../widgets/stat_ring.dart';
import '../widgets/connection_badge.dart';
import '../widgets/shimmer_box.dart';

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
          ..fetchActivity(cp.ip!)
          ..fetchApps(cp.ip!);
      }
    });
  }

  @override
  void dispose() {
    context.read<SystemProvider>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();
    final sp = context.watch<SystemProvider>();

    if (!cp.isConnected) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: CypherColors.textMuted),
              SizedBox(height: 12),
              Text('Disconnected', style: TextStyle(color: CypherColors.textSecondary, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _activeTab,
              children: [
                _DashTab(cp: cp, sp: sp),
                _MoreTab(),
              ],
            ),
            _BottomNav(activeTab: _activeTab, onTab: (i) => setState(() => _activeTab = i)),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────
class _DashTab extends StatelessWidget {
  final ConnectionProvider cp;
  final SystemProvider sp;
  const _DashTab({required this.cp, required this.sp});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CYPHER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CypherColors.accent, letterSpacing: 3)),
                    const SizedBox(height: 2),
                    Text(cp.pcName ?? 'My PC', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CypherColors.textPrimary)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: CypherColors.textSecondary),
                      onPressed: () => Navigator.pushNamed(context, '/notifications'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: CypherColors.textSecondary),
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Stat rings
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatRing(value: sp.cpu / 100, label: 'CPU', sublabel: '${sp.cpu.toInt()}%', color: CypherColors.accent),
                StatRing(value: sp.ram / 100, label: 'RAM', sublabel: '${sp.ram.toInt()}%', color: CypherColors.info),
                StatRing(value: sp.disk / 100, label: 'Disk', sublabel: '${sp.disk.toInt()}%', color: CypherColors.warning),
              ],
            ),
          ),
        ),

        // Active window
        if (sp.activeWindow.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CypherCard(
                child: Row(
                  children: [
                    const Icon(Icons.window_rounded, color: CypherColors.accentLight, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(sp.activeWindow,
                        style: const TextStyle(fontSize: 13, color: CypherColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Quick actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CypherSectionHeader(title: 'Quick Access', action: 'All', onAction: () {}),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: [
                    _QuickTile(icon: Icons.folder_rounded, label: 'Files', color: CypherColors.warning, onTap: () => Navigator.pushNamed(context, '/browser')),
                    _QuickTile(icon: Icons.keyboard_rounded, label: 'Controls', color: CypherColors.accent, onTap: () => Navigator.pushNamed(context, '/controls')),
                    _QuickTile(icon: Icons.content_paste_rounded, label: 'Clipboard', color: CypherColors.info, onTap: () => Navigator.pushNamed(context, '/clipboard')),
                    _QuickTile(icon: Icons.apps_rounded, label: 'Apps', color: CypherColors.success, onTap: () => Navigator.pushNamed(context, '/apps_launcher')),
                    _QuickTile(icon: Icons.memory_rounded, label: 'Processes', color: CypherColors.error, onTap: () => Navigator.pushNamed(context, '/processes')),
                    _QuickTile(icon: Icons.videocam_rounded, label: 'Recorder', color: const Color(0xFFEC4899), onTap: () => Navigator.pushNamed(context, '/recorder')),
                    _QuickTile(icon: Icons.wifi_tethering_rounded, label: 'Drop', color: const Color(0xFF06B6D4), onTap: () => Navigator.pushNamed(context, '/drop')),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Recent activity
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: CypherSectionHeader(title: 'Recent Activity', action: 'See all', onAction: () => Navigator.pushNamed(context, '/activity')),
          ),
        ),
        if (sp.activity.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No recent activity', style: TextStyle(color: CypherColors.textMuted, fontSize: 13)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.separated(
              itemCount: (sp.activity.length).clamp(0, 5),
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final item = sp.activity[i] as Map<String, dynamic>? ?? {};
                return CypherCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 16, color: CypherColors.accentLight),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item['name'] ?? item['action'] ?? 'Action', style: const TextStyle(fontSize: 13, color: CypherColors.textPrimary))),
                      Text(item['time'] ?? item['timestamp'] ?? '', style: const TextStyle(fontSize: 11, color: CypherColors.textMuted)),
                    ],
                  ),
                );
              },
            ),
          ),

        // Power bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            child: CypherCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Power', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CypherColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _PowerBtn(Icons.power_settings_new_rounded, 'Shutdown', CypherColors.error, () => _confirmPower(context, 'Shut down', () => context.read<SystemProvider>().shutdown(cp.ip!))),
                      _PowerBtn(Icons.replay_rounded, 'Restart', CypherColors.warning, () => _confirmPower(context, 'Restart', () => context.read<SystemProvider>().restart(cp.ip!))),
                      _PowerBtn(Icons.bedtime_rounded, 'Sleep', CypherColors.info, () => context.read<SystemProvider>().sleep(cp.ip!)),
                      _PowerBtn(Icons.lock_rounded, 'Lock', CypherColors.textSecondary, () => context.read<SystemProvider>().lock(cp.ip!)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmPower(BuildContext context, String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$action PC?'),
        content: Text('This will $action your computer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(context); onConfirm(); }, child: Text(action, style: const TextStyle(color: CypherColors.error))),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CypherCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CypherColors.textPrimary)),
        ],
      ),
    );
  }
}

class _PowerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PowerBtn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: CypherColors.textMuted)),
        ],
      ),
    );
  }
}

// ── More Tab ──────────────────────────────────────────────────
class _MoreTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const CypherSectionHeader(title: 'Apps & Tasks'),
        const SizedBox(height: 8),
        _MoreItem(icon: Icons.rocket_launch_rounded, title: 'App Launcher', subtitle: 'Open installed programs', onTap: () => Navigator.pushNamed(context, '/apps_launcher')),
        _MoreItem(icon: Icons.task_alt_rounded,       title: 'Active Tasks',   subtitle: 'Manage transfers', onTap: () => Navigator.pushNamed(context, '/active_tasks')),
        _MoreItem(icon: Icons.videocam_rounded,       title: 'Screen Recorder',subtitle: 'Record your PC screen', onTap: () => Navigator.pushNamed(context, '/recorder')),
        _MoreItem(icon: Icons.memory_rounded,         title: 'Process Manager',subtitle: 'View & kill processes', onTap: () => Navigator.pushNamed(context, '/processes')),
        const SizedBox(height: 20),
        const CypherSectionHeader(title: 'Security'),
        const SizedBox(height: 8),
        _MoreItem(icon: Icons.people_outline,    title: 'Guest Access', subtitle: 'Share folders temporarily', onTap: () => Navigator.pushNamed(context, '/guest')),
        _MoreItem(icon: Icons.power_settings_new_rounded, title: 'Wake on LAN', subtitle: 'Wake up sleeping PCs', onTap: () => Navigator.pushNamed(context, '/wol')),
        const SizedBox(height: 20),
        const CypherSectionHeader(title: 'Activity & Logs'),
        const SizedBox(height: 8),
        _MoreItem(icon: Icons.history_rounded,           title: 'Activity Log',   subtitle: 'Recent actions', onTap: () => Navigator.pushNamed(context, '/activity')),
        _MoreItem(icon: Icons.notifications_none_rounded, title: 'Notifications', subtitle: 'PC alerts',      onTap: () => Navigator.pushNamed(context, '/notifications')),
        const SizedBox(height: 20),
        const CypherSectionHeader(title: 'System'),
        const SizedBox(height: 8),
        _MoreItem(icon: Icons.help_outline_rounded,   title: 'Guide',    subtitle: 'Setup & troubleshooting', onTap: () => Navigator.pushNamed(context, '/guide')),
        _MoreItem(icon: Icons.settings_outlined,      title: 'Settings', subtitle: 'Connection & preferences', onTap: () => Navigator.pushNamed(context, '/settings')),
        _MoreItem(icon: Icons.smartphone_rounded,     title: 'Send to PC', subtitle: 'Upload from your phone', onTap: () => Navigator.pushNamed(context, '/send')),
        _MoreItem(icon: Icons.folder_special_rounded, title: 'Phone Files', subtitle: 'Browse local phone files', onTap: () => Navigator.pushNamed(context, '/phone_browser')),
        const SizedBox(height: 20),
        const CypherSectionHeader(title: 'Share'),
        const SizedBox(height: 8),
        _MoreItem(icon: Icons.wifi_tethering_rounded, title: 'CypherDrop', subtitle: 'Send files to nearby devices', onTap: () => Navigator.pushNamed(context, '/drop')),
      ],
    );
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MoreItem({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CypherCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: CypherColors.bgOverlay, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: CypherColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: CypherColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: CypherColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: CypherColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int activeTab;
  final void Function(int) onTab;
  const _BottomNav({required this.activeTab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16, left: 16, right: 16,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: CypherColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CypherColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(index: 0, active: activeTab, icon: Icons.dashboard_rounded, label: 'Home', onTap: onTab),
            _NavItem(index: -1, active: -1, icon: Icons.send_rounded, label: 'Send', onTap: (_) => Navigator.pushNamed(context, '/send')),
            _NavItem(index: -2, active: -1, icon: Icons.keyboard_alt_rounded, label: 'Controls', onTap: (_) => Navigator.pushNamed(context, '/controls')),
            _NavItem(index: 1, active: activeTab, icon: Icons.more_horiz_rounded, label: 'More', onTap: onTab),
          ],
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
  const _NavItem({required this.index, required this.active, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = index >= 0 && index == active;
    final color = isActive ? CypherColors.accent : CypherColors.textMuted;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: color)),
          ],
        ),
      ),
    );
  }
}