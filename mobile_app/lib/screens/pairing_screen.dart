import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../providers/connection_provider.dart';
import '../services/storage_service.dart';

import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_button.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes   = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes)  f.dispose();
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _submit() async {
    if (_code.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final deviceId   = await StorageService.getDeviceId() ?? const Uuid().v4();
    final deviceName = '${deviceInfo.manufacturer} ${deviceInfo.model}';
    await StorageService.saveDeviceId(deviceId);

    final cp = context.read<ConnectionProvider>();
    final ok = await cp.pair(_code, deviceId, deviceName);

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } else {
      setState(() => _error = cp.error ?? 'Wrong code, try again');
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    }
  }

  void _onDigitChanged(int idx, String value) {
    if (value.length == 1 && idx < 5) _focusNodes[idx + 1].requestFocus();
    if (value.isEmpty && idx > 0)      _focusNodes[idx - 1].requestFocus();
    if (_code.length == 6) _submit();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pair Device')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: CypherColors.accentDim,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CypherColors.borderFocus),
                ),
                child: const Icon(Icons.link_rounded, color: CypherColors.accent, size: 36),
              ),
              const SizedBox(height: 24),
              Text('Enter Pairing Code', style: AppTheme.headline(context), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Open CYPHER on your PC and enter the 6-digit code shown on screen.',
                style: AppTheme.body(context),
                textAlign: TextAlign.center,
              ),
              if (cp.pcName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CypherColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CypherColors.border),
                  ),
                  child: Text(cp.pcName!, style: AppTheme.caption(context)),
                ),
              ],
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  width: 44, height: 54,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700,
                      color: CypherColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: CypherColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: CypherColors.accent, width: 1.5),
                      ),
                      filled: true,
                      fillColor: CypherColors.bgCard,
                    ),
                    onChanged: (v) => _onDigitChanged(i, v),
                  ),
                )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: CypherColors.error, fontSize: 13), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 32),
              CypherButton(label: 'Pair Now', onTap: _submit, loading: _loading),
              const SizedBox(height: 12),
              CypherButton(
                label: 'Back to Scan',
                variant: CypherButtonVariant.secondary,
                onTap: () => Navigator.pushReplacementNamed(context, '/connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}