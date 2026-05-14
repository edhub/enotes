import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../sync/providers/sync_provider.dart';
import '../../sync/widgets/backup_list_dialog.dart';
import '../providers/notes_provider.dart';
import '../services/export_service.dart';

enum _MenuAction {
  // 本地导入导出
  exportJson,
  exportMarkdown,
  importJson,
  // 云备份
  login,
  uploadBackup,
  restoreFromCloud,
  logout,
}

/// 固定在右上角的数据管理按钮，包含本地导入导出和云备份功能。
class DataMenuButton extends ConsumerStatefulWidget {
  const DataMenuButton({super.key});

  @override
  ConsumerState<DataMenuButton> createState() => _DataMenuButtonState();
}

class _DataMenuButtonState extends ConsumerState<DataMenuButton> {
  final _export = const ExportService();

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final syncState = ref.watch(syncProvider);

    // 监听同步错误，以 SnackBar 形式提示
    ref.listen<String?>(
      syncProvider.select((s) => s.error),
      (prev, next) {
        if (next == null || next == prev) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          width: 400,
          duration: const Duration(seconds: 5),
        ));
      },
    );

    return Positioned(
      right: LayoutConstants.pageHPad + 8,
      top: LayoutConstants.pageHPad,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: nc?.controlSurface ?? Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: nc?.searchBarBorder ?? Theme.of(context).dividerColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: PopupMenuButton<_MenuAction>(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.more_horiz_rounded),
              // 上传中时显示进度指示点
              if (syncState.isBusy)
                Positioned(
                  right: -4,
                  top: -4,
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Data & Cloud',
          onSelected: (action) => _handleAction(action, syncState),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(36, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          itemBuilder: (_) => [
            // ── 本地导入导出 ───────────────────────────────────────────────
            const PopupMenuItem(
              value: _MenuAction.exportJson,
              child: ListTile(
                leading: Icon(Icons.backup_outlined),
                title: Text('Export JSON (full backup)'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const PopupMenuItem(
              value: _MenuAction.exportMarkdown,
              child: ListTile(
                leading: Icon(Icons.description_outlined),
                title: Text('Export Markdown (plain text)'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: _MenuAction.importJson,
              child: ListTile(
                leading: Icon(Icons.restore_outlined),
                title: Text('Import JSON…'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),

            // ── 云备份 ─────────────────────────────────────────────────────
            const PopupMenuDivider(),
            if (!syncState.isLoggedIn) ...[
              const PopupMenuItem(
                value: _MenuAction.login,
                child: ListTile(
                  leading: Icon(Icons.cloud_outlined),
                  title: Text('Sign in with GitHub (Cloud Backup)'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ] else ...[
              // 显示当前用户（不可点击）
              PopupMenuItem<_MenuAction>(
                enabled: false,
                child: ListTile(
                  leading: const Icon(Icons.account_circle_outlined,
                      color: Colors.grey),
                  title: Text(
                    syncState.user?.username.isNotEmpty == true
                        ? syncState.user!.username
                        : 'Signing in…',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.uploadBackup,
                enabled: !syncState.isBusy,
                child: ListTile(
                  leading: Icon(
                    Icons.cloud_upload_outlined,
                    color: syncState.isBusy ? Colors.grey : null,
                  ),
                  title: Text(
                    syncState.status == SyncStatus.uploading
                        ? 'Uploading…'
                        : 'Upload Backup Now',
                    style: syncState.isBusy
                        ? const TextStyle(color: Colors.grey)
                        : null,
                  ),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.restoreFromCloud,
                enabled: !syncState.isBusy,
                child: ListTile(
                  leading: Icon(
                    Icons.cloud_download_outlined,
                    color: syncState.isBusy ? Colors.grey : null,
                  ),
                  title: const Text('Restore from Cloud…'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.grey),
                  title: Text('Sign Out',
                      style: TextStyle(color: Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(_MenuAction action, SyncState syncState) async {
    final notifier = ref.read(notesProvider.notifier);
    final syncNotifier = ref.read(syncProvider.notifier);

    switch (action) {
      // ── 本地导入导出 ──────────────────────────────────────────────────────
      case _MenuAction.exportJson:
        final result = await _export.exportJson(
          ref.read(notesProvider).allNotes,
        );
        if (!mounted || result == null) return;
        _snack(result ? '✓ JSON backup saved' : 'Export failed — check logs');

      case _MenuAction.exportMarkdown:
        final result = await _export.exportMarkdown(
          ref.read(notesProvider).allNotes,
        );
        if (!mounted || result == null) return;
        _snack(
          result ? '✓ Markdown export saved' : 'Export failed — check logs',
        );

      case _MenuAction.importJson:
        final confirmed = await _confirmImport();
        if (!mounted || !confirmed) return;
        final notes = await _export.importJson();
        if (!mounted) return;
        if (notes == null) {
          _snack('Import failed — invalid or unsupported file');
          return;
        }
        if (notes.isEmpty) return;
        await notifier.importNotes(notes);
        if (!mounted) return;
        _snack('✓ Imported ${notes.length} notes');

      // ── 云备份 ────────────────────────────────────────────────────────────
      case _MenuAction.login:
        await syncNotifier.login();

      case _MenuAction.uploadBackup:
        await syncNotifier.uploadBackup();
        if (!mounted) return;
        final error = ref.read(syncProvider).error;
        if (error == null) {
          _snack('✓ Backup uploaded to cloud');
        }
        // 错误已由 ref.listen 以 SnackBar 提示

      case _MenuAction.restoreFromCloud:
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => const BackupListDialog(),
        );

      case _MenuAction.logout:
        await syncNotifier.logout();
        if (!mounted) return;
        _snack('Signed out');
    }
  }

  Future<bool> _confirmImport() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Notes'),
        content: const Text(
          'This will replace ALL current notes with the contents of the '
          'selected file. This cannot be undone.\n\nContinue?',
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
    return result ?? false;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 360,
      ),
    );
  }
}
