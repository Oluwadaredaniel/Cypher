import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../providers/connection_provider.dart';

class ConnectionBadge extends StatelessWidget {
  final ConnectionStatus status;
  final String? pcName;

  const ConnectionBadge({super.key, required this.status, this.pcName});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ConnectionStatus.connected    => (CypherColors.success, 'Connected'),
      ConnectionStatus.connecting   => (CypherColors.warning, 'Connecting'),
      ConnectionStatus.pairing      => (CypherColors.info,    'Pairing'),
      ConnectionStatus.disconnected => (CypherColors.textMuted, 'Offline'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, pulse: status == ConnectionStatus.connecting),
          const SizedBox(width: 6),
          Text(
            pcName != null && status == ConnectionStatus.connected
                ? pcName!
                : label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, this.pulse = false});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
