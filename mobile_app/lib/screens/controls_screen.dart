import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/system_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../widgets/cypher_button.dart';
import '../widgets/control_button.dart';

class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  Timer? _statusTimer;
  Uint8List? _screenshotBytes;
  bool _isTakingScreenshot = false;
  final _typeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ip = context.read<ConnectionProvider>().ip ?? '';
      if (ip.isNotEmpty) {
        context.read<SystemProvider>().fetchActiveWindow(ip);
        context.read<SystemProvider>().fetchVolume(ip);
        _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (mounted) context.read<SystemProvider>().fetchActiveWindow(ip);
        });
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? CypherColors.error : CypherColors.accent,
    ));
  }

  Future<void> _takeScreenshot() async {
    final ip = context.read<ConnectionProvider>().ip ?? '';
    setState(() => _isTakingScreenshot = true);
    try {
      final bytes = await ApiService.getScreenshot(ip);
      setState(() {
        _screenshotBytes = bytes;
        _isTakingScreenshot = false;
      });
      _toast('Screenshot captured');
    } catch (_) {
      setState(() => _isTakingScreenshot = false);
      _toast('Failed to capture screen', err: true);
    }
  }

  Future<void> _saveScreenshot() async {
    if (_screenshotBytes == null) return;
    try {
      // Get user-visible Downloads folder (not app cache)
      Directory downloadDir;
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          final parts = external.path.split('/');
          final storageIndex = parts.indexOf('storage');
          if (storageIndex >= 0) {
            final publicPath =
                '${parts.sublist(0, storageIndex + 2).join('/')}/Download';
            downloadDir = Directory(publicPath);
          } else {
            downloadDir = external;
          }
        } else {
          downloadDir = await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      await downloadDir.create(recursive: true);

      final fileName =
          'Screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${downloadDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(_screenshotBytes!);
      _toast('Saved to Downloads folder');
    } catch (e) {
      _toast('Failed to save screenshot', err: true);
    }
  }

  Future<void> _sendType() async {
    final text = _typeCtrl.text.trim();
    if (text.isEmpty) return;
    final ip = context.read<ConnectionProvider>().ip ?? '';
    try {
      await ApiService.remoteType(ip, text);
      _typeCtrl.clear();
      FocusScope.of(context).unfocus();
    } catch (_) {
      _toast('Type failed', err: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SystemProvider>();
    final ip = context.read<ConnectionProvider>().ip ?? '';

    return Scaffold(
      backgroundColor: CypherColors.bgDeep,
      appBar: AppBar(
        backgroundColor: CypherColors.bgDeep,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Remote Control',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CypherColors.textPrimary)),
            if (sp.activeWindow.isNotEmpty)
              Text(sp.activeWindow,
                  style: const TextStyle(
                      fontSize: 11, color: CypherColors.textMuted),
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Media ─────────────────────────────────────────────
            _SectionLabel('MEDIA'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              decoration: BoxDecoration(
                color: CypherColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CypherColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ControlButton(
                          icon: Icons.skip_previous_rounded,
                          label: 'Prev',
                          onTap: () => sp.prevTrack(ip)),
                      ControlButton(
                          icon: sp.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          label: sp.isPlaying ? 'Pause' : 'Play',
                          onTap: () => sp.togglePlayPause(ip),
                          active: sp.isPlaying,
                          size: 68),
                      ControlButton(
                          icon: Icons.skip_next_rounded,
                          label: 'Next',
                          onTap: () => sp.nextTrack(ip)),
                      ControlButton(
                          icon: Icons.volume_off_rounded,
                          label: 'Mute',
                          onTap: () => sp.toggleMute(ip)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.volume_mute_rounded,
                          size: 14, color: CypherColors.textMuted),
                      Expanded(
                        child: Slider(
                          value: sp.volume.toDouble(),
                          min: 0,
                          max: 100,
                          onChangeEnd: (v) => sp.setVolume(ip, v.toInt()),
                          onChanged: (v) => sp.setVolume(ip, v.toInt()),
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded,
                          size: 14, color: CypherColors.textMuted),
                      const SizedBox(width: 6),
                      Text('${sp.volume}%',
                          style: const TextStyle(
                              fontSize: 12, color: CypherColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Remote Keyboard ───────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('REMOTE KEYBOARD'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CypherColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CypherColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _typeCtrl,
                      style: const TextStyle(
                          fontSize: 14, color: CypherColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Type on PC…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendType(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _sendType,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CypherColors.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // ── Screenshot ────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('SCREENSHOT'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: CypherColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CypherColors.border),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(13)),
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      color: CypherColors.bgDeep,
                      child: _isTakingScreenshot
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: CypherColors.accent, strokeWidth: 2))
                          : _screenshotBytes != null
                              ? InteractiveViewer(
                                  child: Image.memory(_screenshotBytes!,
                                      fit: BoxFit.contain))
                              : const Center(
                                  child: Icon(Icons.monitor_rounded,
                                      color: CypherColors.textDisabled,
                                      size: 36)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: CypherButton(
                            label:
                                _isTakingScreenshot ? 'Capturing…' : 'Capture',
                            onTap: _takeScreenshot,
                            loading: _isTakingScreenshot,
                          ),
                        ),
                        if (_screenshotBytes != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: CypherButton(
                              label: 'Save',
                              onTap: _saveScreenshot,
                              variant: CypherButtonVariant.secondary,
                            ),
                          ),
                        ],
                      ],
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: CypherColors.textMuted,
            letterSpacing: 0.8),
      );
}
