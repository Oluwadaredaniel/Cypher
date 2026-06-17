import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cypher_card.dart';

class TransferProgressScreen extends StatelessWidget {
  const TransferProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers'),
        actions: [
          Consumer<FileProvider>(
            builder: (_, fp, __) {
              final hasDone = fp.transfers.any(
                (t) => t.status == TransferStatus.done || t.status == TransferStatus.error,
              );
              if (!hasDone) return const SizedBox.shrink();
              return TextButton(
                onPressed: fp.clearTransfers,
                child: const Text('Clear Done', style: TextStyle(color: CypherColors.accent)),
              );
            },
          ),
        ],
      ),
      body: Consumer<FileProvider>(
        builder: (_, fp, __) {
          final transfers = fp.transfers;
          if (transfers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz_rounded, color: CypherColors.textMuted, size: 48),
                  SizedBox(height: 12),
                  Text('No active transfers', style: TextStyle(color: CypherColors.textMuted, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Downloads and uploads appear here', style: TextStyle(color: CypherColors.textDisabled, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: transfers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _TransferCard(task: transfers[i]),
          );
        },
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final TransferTask task;
  const _TransferCard({required this.task});

  String _fmtSize(int b) {
    if (b < 1024)       return '$b B';
    if (b < 1048576)    return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isDone   = task.status == TransferStatus.done;
    final isError  = task.status == TransferStatus.error;
    final isActive = task.status == TransferStatus.downloading || task.status == TransferStatus.uploading;

    final statusColor = isError ? CypherColors.error : isDone ? CypherColors.success : CypherColors.accent;
    final statusIcon  = isError
        ? Icons.error_outline_rounded
        : isDone
            ? Icons.check_circle_outline_rounded
            : task.isUpload
                ? Icons.upload_rounded
                : Icons.download_rounded;

    return CypherCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CypherColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadge(task.status),
            ],
          ),

          if (isActive || task.total > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: task.progress.clamp(0.0, 1.0),
              color: statusColor,
              backgroundColor: CypherColors.bgOverlay,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.total > 0
                      ? '${_fmtSize(task.received)} / ${_fmtSize(task.total)}'
                      : _fmtSize(task.received),
                  style: AppTheme.caption(context),
                ),
                Text(
                  '${(task.progress * 100).clamp(0, 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CypherColors.accentLight),
                ),
              ],
            ),
          ],

          if (isError && task.error != null) ...[
            const SizedBox(height: 6),
            Text(task.error!, style: const TextStyle(fontSize: 11, color: CypherColors.error)),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TransferStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransferStatus.done        => ('Done', CypherColors.success),
      TransferStatus.error       => ('Error', CypherColors.error),
      TransferStatus.uploading   => ('Uploading', CypherColors.accent),
      TransferStatus.downloading => ('Downloading', CypherColors.info),
      TransferStatus.paused      => ('Paused', CypherColors.warning),
      TransferStatus.idle        => ('Queued', CypherColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
