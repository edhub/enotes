import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/backup_entry.dart';
import '../providers/sync_provider.dart';
import '../services/shelf_service.dart';

/// 云备份列表弹窗。
///
/// 打开时自动加载备份列表；支持恢复和删除操作。
class BackupListDialog extends ConsumerStatefulWidget {
  const BackupListDialog({super.key});

  @override
  ConsumerState<BackupListDialog> createState() => _BackupListDialogState();
}

class _BackupListDialogState extends ConsumerState<BackupListDialog> {
  late Future<List<BackupEntry>> _backupsFuture;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  void _loadBackups() {
    final token = ref.read(syncProvider).token;
    if (token == null) return;
    setState(() {
      _backupsFuture = ShelfService(token).listBackups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_outlined, size: 20),
          SizedBox(width: 8),
          Text('Cloud Backups'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: FutureBuilder<List<BackupEntry>>(
                future: _backupsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined,
                                size: 36, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load backups',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${snap.error}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final backups = snap.data!;
                  if (backups.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_outlined,
                                size: 36, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No backups yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Use "Upload Backup" to create your first cloud backup.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: backups.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _BackupTile(backup: backups[i], onChanged: _loadBackups),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ── 单条备份行 ─────────────────────────────────────────────────────────────────

class _BackupTile extends ConsumerWidget {
  const _BackupTile({required this.backup, required this.onChanged});

  final BackupEntry backup;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nc = Theme.of(context).extension<NoteColors>();
    final isBusy = ref.watch(syncProvider).isBusy;

    final fmt = DateFormat('yyyy-MM-dd  HH:mm');
    final dateStr = fmt.format(backup.createdAtLocal);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      dense: true,
      leading: const Icon(Icons.backup_outlined, size: 20),
      title: Text(dateStr, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        backup.displaySize,
        style: TextStyle(fontSize: 11, color: nc?.badgeForeground ?? Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 恢复
          Tooltip(
            message: 'Restore this backup (replaces all current notes)',
            child: IconButton(
              icon: const Icon(Icons.restore_outlined, size: 18),
              onPressed:
                  isBusy ? null : () => _confirmRestore(context, ref),
            ),
          ),
          // 删除
          Tooltip(
            message: 'Delete this backup from cloud',
            child: IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade300),
              onPressed:
                  isBusy ? null : () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will replace ALL current notes with the selected backup.\n'
          'This cannot be undone.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final count =
          await ref.read(syncProvider.notifier).restoreFromBackup(backup.id);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // 关闭弹窗
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✓ Restored $count notes from cloud backup'),
        behavior: SnackBarBehavior.floating,
        width: 360,
      ));
    } catch (_) {
      // 错误已由 SyncNotifier 写入 state.error，
      // DataMenuButton 的 ref.listen 会统一以 SnackBar 展示。
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup'),
        content: const Text('Remove this backup from the cloud? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(syncProvider.notifier).deleteRemoteBackup(backup.id);
      onChanged(); // 刷新列表
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        width: 360,
      ));
    }
  }
}
