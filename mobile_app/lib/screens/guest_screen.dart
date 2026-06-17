import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';
import '../widgets/cypher_card.dart';

enum _GuestState { setup, active, expired }

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  _GuestState _phase = _GuestState.setup;
  List<Map<String, dynamic>> _folders = [];
  Set<String> _selected = {};
  int _durationMinutes = 15;
  bool _loading = false;

  String? _guestToken;
  String? _guestUrl;
  DateTime? _expiry;
  Timer? _countdown;
  Timer? _poll;
  bool _guestConnected = false;
  int _accessCount = 0;
  int _backCountdown = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFolders());
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  String get _ip => context.read<ConnectionProvider>().ip ?? '';

  Future<void> _loadFolders() async {
    try {
      final data = await ApiService.getSettings(_ip);
      final shared = (data['shared_folders'] as List? ?? []);
      setState(() {
        _folders = shared.map<Map<String, dynamic>>((p) => {
          'name': p.toString().split(RegExp(r'[/\\]')).last,
          'path': p.toString(),
        }).toList();
        _selected = _folders.map((f) => f['path'].toString()).toSet();
      });
    } catch (_) {}
  }

  Future<void> _createSession() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one folder')));
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiService.createGuestSession(_ip, folders: _selected.toList(), durationMinutes: _durationMinutes);
      _guestToken = data['token']?.toString();
      _guestUrl   = data['url']?.toString();
      _expiry     = DateTime.now().add(Duration(minutes: _durationMinutes));
      setState(() { _phase = _GuestState.active; _loading = false; });
      _startCountdown();
      _startPoll();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_expiry == null) return;
      if (_expiry!.difference(DateTime.now()).isNegative) _expire();
      else if (mounted) setState(() {});
    });
  }

  void _startPoll() {
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final data = await ApiService.getGuestSessions(_ip);
        final sessions = data as List? ?? [];
        final session = sessions.firstWhere((s) => s['token'] == _guestToken, orElse: () => null);
        if (session != null && mounted) {
          setState(() {
            _accessCount    = session['access_count'] ?? 0;
            _guestConnected = _accessCount > 0;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _endSession() async {
    setState(() => _loading = true);
    try { await ApiService.endGuestSession(_ip, _guestToken ?? ''); } catch (_) {}
    _expire();
    setState(() => _loading = false);
  }

  void _expire() {
    _countdown?.cancel();
    _poll?.cancel();
    if (mounted) setState(() => _phase = _GuestState.expired);
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (_backCountdown > 0) {
        setState(() => _backCountdown--);
      } else {
        t.cancel();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
    });
  }

  String _fmtCountdown() {
    final rem = _expiry?.difference(DateTime.now()) ?? Duration.zero;
    if (rem.isNegative) return '00:00';
    return '${rem.inMinutes.toString().padLeft(2,'0')}:${(rem.inSeconds % 60).toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _phase == _GuestState.setup ? AppBar(title: const Text('Guest Access')) : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: switch (_phase) {
            _GuestState.setup   => _setupView(),
            _GuestState.active  => _activeView(),
            _GuestState.expired => _expiredView(),
          },
        ),
      ),
    );
  }

  Widget _setupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.people_alt_rounded, size: 40, color: CypherColors.accent),
          const SizedBox(height: 12),
          const Text('Share files temporarily', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CypherColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Your guest scans a QR code and gets read-only access.', style: TextStyle(color: CypherColors.textSecondary)),
          const SizedBox(height: 24),
          const CypherSectionHeader(title: 'Folders to share'),
          const SizedBox(height: 8),
          CypherCard(
            child: _folders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('No shared folders configured on PC', style: TextStyle(color: CypherColors.textMuted))),
                )
              : Column(
                  children: _folders.map((f) {
                    final path = f['path'].toString();
                    final sel  = _selected.contains(path);
                    return GestureDetector(
                      onTap: () => setState(() => sel ? _selected.remove(path) : _selected.add(path)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: sel ? CypherColors.accent : Colors.transparent,
                                border: Border.all(color: sel ? CypherColors.accent : CypherColors.border, width: 1.5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: sel ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.folder_rounded, color: CypherColors.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f['name'].toString(), style: const TextStyle(fontSize: 14, color: CypherColors.textPrimary), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
          ),
          const SizedBox(height: 20),
          const CypherSectionHeader(title: 'Duration'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [15, 30, 60, 120].map((m) {
              final sel = _durationMinutes == m;
              final label = m < 60 ? '$m min' : '${m ~/ 60}h';
              return GestureDetector(
                onTap: () => setState(() => _durationMinutes = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? CypherColors.accent : CypherColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? CypherColors.accent : CypherColors.border),
                  ),
                  child: Text(label, style: TextStyle(fontSize: 13, color: sel ? Colors.white : CypherColors.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          CypherButton(label: 'Create Guest Access', onTap: _createSession, loading: _loading),
        ],
      ),
    );
  }

  Widget _activeView() {
    final rem = _expiry?.difference(DateTime.now()) ?? Duration.zero;
    final color = rem.inMinutes < 1 ? CypherColors.error : rem.inMinutes < 5 ? CypherColors.warning : CypherColors.accent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            decoration: BoxDecoration(color: CypherColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('Guest session active', style: TextStyle(color: CypherColors.success, fontWeight: FontWeight.w600))),
          ),
          const SizedBox(height: 32),
          if (_guestUrl != null)
            CypherCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 180, height: 180, color: Colors.white,
                    child: Center(child: Text(_guestUrl!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 10))),
                  ),
                  const SizedBox(height: 12),
                  const Text('Ask your guest to scan this', style: TextStyle(color: CypherColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(_fmtCountdown(), style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _guestConnected ? CypherColors.success : CypherColors.textMuted, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(_guestConnected ? 'Guest connected — $_accessCount ops' : 'Waiting for guest', style: AppTheme.body(context)),
            ],
          ),
          const SizedBox(height: 32),
          CypherButton(
            label: 'End Session',
            variant: CypherButtonVariant.danger,
            onTap: _endSession,
            loading: _loading,
          ),
        ],
      ),
    );
  }

  Widget _expiredView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off_rounded, color: CypherColors.textMuted, size: 48),
          const SizedBox(height: 16),
          const Text('Session Ended', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CypherColors.textPrimary)),
          const SizedBox(height: 8),
          const Text("Your guest's access has expired.", style: TextStyle(color: CypherColors.textSecondary)),
          const SizedBox(height: 24),
          CypherCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow('Duration', '$_durationMinutes min'),
                _SummaryRow('Folders shared', '${_selected.length}'),
                _SummaryRow('Files accessed', '$_accessCount'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CypherButton(label: 'New Session', onTap: () => setState(() { _phase = _GuestState.setup; _backCountdown = 10; })),
          const SizedBox(height: 16),
          Text('Returning in $_backCountdown…', style: AppTheme.caption(context)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.body(context)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CypherColors.textPrimary)),
        ],
      ),
    );
  }
}
