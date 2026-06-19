import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import 'cypher_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CypherColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CypherColors.border),
              ),
              child: Icon(icon, size: 32, color: CypherColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.subtitle(context), textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(body!, style: AppTheme.body(context), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 160,
                child: CypherButton(
                  label: actionLabel!,
                  onTap: onAction,
                  fullWidth: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
