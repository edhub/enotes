import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../sync/providers/sync_provider.dart';
import '../../sync/widgets/backup_list_dialog.dart';
import '../providers/notes_provider.dart';
import '../services/export_service.dart';
import 'column_header.dart';
import 'trash_note_card.dart';

const _kAppVersion = '1.0.0';

enum _Section { data, trash, about }

/// Settings dialog — opened from the draft column footer button.
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  _Section _section = _Section.data;
  final _export = const ExportService();

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final borderColor = nc?.columnBorder ?? Theme.of(context).dividerColor;
    final surface = nc?.columnSurface ?? Theme.of(context).colorScheme.surface;
    final sidebarBg = nc?.columnHeader ?? Theme.of(context).colorScheme.surface;

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

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: SizedBox(
        width: 740,
        height: 580,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              _buildHeader(context, borderColor),
              Divider(height: 1, thickness: 1, color: borderColor),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSidebar(context, sidebarBg, borderColor),
                    VerticalDivider(width: 1, thickness: 1, color: borderColor),
                    Expanded(child: _buildContent(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          Text(
            'Settings',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              minimumSize: const Size(28, 28),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, Color bg, Color border) {
    return ColoredBox(
      color: bg,
      child: SizedBox(
        width: 148,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            _SidebarItem(
              icon: Icons.storage_outlined,
              label: 'Data & Backup',
              selected: _section == _Section.data,
              onTap: () => setState(() => _section = _Section.data),
            ),
            _SidebarItem(
              icon: Icons.delete_outline_rounded,
              label: 'Recently Deleted',
              selected: _section == _Section.trash,
              onTap: () => setState(() => _section = _Section.trash),
            ),
            _SidebarItem(
              icon: Icons.info_outline_rounded,
              label: 'About',
              selected: _section == _Section.about,
              onTap: () => setState(() => _section = _Section.about),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (_section) {
      _Section.data => _buildDataSection(context),
      _Section.trash => const _TrashSection(),
      _Section.about => const _AboutSection(),
    };
  }

  // ── Data & Backup ───────────────────────────────────────────────────────────

  Widget _buildDataSection(BuildContext context) {
    final syncState = ref.watch(syncProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionLabel('Local'),
        const SizedBox(height: 6),
        _ActionTile(
          icon: Icons.backup_outlined,
          label: 'Export JSON (full backup)',
          onTap: () => _exportJson(),
        ),
        _ActionTile(
          icon: Icons.description_outlined,
          label: 'Export Markdown (plain text)',
          onTap: () => _exportMarkdown(),
        ),
        _ActionTile(
          icon: Icons.restore_outlined,
          label: 'Import JSON…',
          onTap: () => _importJson(),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Cloud Backup'),
        const SizedBox(height: 6),
        if (!syncState.isLoggedIn)
          _ActionTile(
            icon: Icons.cloud_outlined,
            label: 'Sign in with GitHub',
            onTap: () => ref.read(syncProvider.notifier).login(),
          )
        else ...[
          _ActionTile(
            icon: Icons.account_circle_outlined,
            label: syncState.user?.username.isNotEmpty == true
                ? syncState.user!.username
                : 'Signing in…',
            enabled: false,
          ),
          _ActionTile(
            icon: Icons.cloud_upload_outlined,
            label: syncState.status == SyncStatus.uploading
                ? 'Uploading…'
                : 'Upload Backup Now',
            enabled: !syncState.isBusy,
            onTap: () => _uploadBackup(),
          ),
          _ActionTile(
            icon: Icons.cloud_download_outlined,
            label: 'Restore from Cloud…',
            enabled: !syncState.isBusy,
            onTap: () => _restoreFromCloud(),
          ),
          _ActionTile(
            icon: Icons.logout,
            label: 'Sign Out',
            muted: true,
            onTap: () => _logout(),
          ),
        ],
      ],
    );
  }

  Future<void> _exportJson() async {
    final result = await _export.exportJson(ref.read(notesProvider).allNotes);
    if (!mounted || result == null) return;
    _snack(result ? '✓ JSON backup saved' : 'Export failed — check logs');
  }

  Future<void> _exportMarkdown() async {
    final result =
        await _export.exportMarkdown(ref.read(notesProvider).allNotes);
    if (!mounted || result == null) return;
    _snack(result ? '✓ Markdown export saved' : 'Export failed — check logs');
  }

  Future<void> _importJson() async {
    final confirmed = await _confirmImport();
    if (!mounted || !confirmed) return;
    final notes = await _export.importJson();
    if (!mounted) return;
    if (notes == null) {
      _snack('Import failed — invalid or unsupported file');
      return;
    }
    if (notes.isEmpty) return;
    await ref.read(notesProvider.notifier).importNotes(notes);
    if (!mounted) return;
    _snack('✓ Imported ${notes.length} notes');
  }

  Future<void> _uploadBackup() async {
    await ref.read(syncProvider.notifier).uploadBackup();
    if (!mounted) return;
    if (ref.read(syncProvider).error == null) {
      _snack('✓ Backup uploaded to cloud');
    }
  }

  Future<void> _restoreFromCloud() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const BackupListDialog(),
    );
  }

  Future<void> _logout() async {
    await ref.read(syncProvider.notifier).logout();
    if (!mounted) return;
    _snack('Signed out');
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

// ── Trash section ─────────────────────────────────────────────────────────────

class _TrashSection extends ConsumerWidget {
  const _TrashSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider.select((s) => s.trashedNotes));
    final nc = Theme.of(context).extension<NoteColors>();
    final destructive = nc?.destructive ?? Colors.red.shade400;
    final mutedDestructive = destructive.withValues(alpha: 0.82);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: mutedDestructive),
              const SizedBox(width: 8),
              Text(
                'Recently Deleted',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(width: 8),
                CountBadge(count: notes.length),
              ],
              const Spacer(),
              if (notes.isNotEmpty)
                TextButton(
                  onPressed: ref.read(notesProvider.notifier).emptyTrash,
                  style: TextButton.styleFrom(
                    foregroundColor: mutedDestructive,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color: mutedDestructive.withValues(alpha: 0.24)),
                    ),
                  ),
                  child: const Text('Empty',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        Divider(
            height: 1, thickness: 1, color: nc?.columnBorder ?? Theme.of(context).dividerColor),
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: nc?.destructiveSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 28,
                          color: (nc?.destructive ??
                                  Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.color)
                              ?.withValues(alpha: 0.86),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No deleted notes.',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: notes.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TrashNoteCard(
                      key: ValueKey(notes[i].id),
                      note: notes[i],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── About section ─────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.labelSmall?.color;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FlutterLogo(size: 48),
          const SizedBox(height: 16),
          Text(
            'eNotes',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('Version $_kAppVersion',
              style: TextStyle(color: muted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Shared sidebar item ───────────────────────────────────────────────────────

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nc = Theme.of(context).extension<NoteColors>();

    final bg = widget.selected
        ? scheme.primary.withValues(alpha: 0.12)
        : _hovered
            ? (nc?.controlSurfaceHover ??
                scheme.onSurface.withValues(alpha: 0.06))
            : Colors.transparent;

    final fgColor =
        widget.selected ? scheme.primary : Theme.of(context).iconTheme.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: fgColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared action tile ────────────────────────────────────────────────────────

class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool muted;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final disabled = !widget.enabled || widget.onTap == null;
    final muted = widget.muted || disabled;
    final textColor = muted
        ? Theme.of(context).textTheme.labelSmall?.color
        : Theme.of(context).textTheme.bodyMedium?.color;

    final bg = !disabled && _hovered
        ? (nc?.controlSurfaceHover ??
            Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.06))
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 17, color: textColor),
              const SizedBox(width: 12),
              Text(widget.label,
                  style: TextStyle(fontSize: 14, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Theme.of(context).textTheme.labelSmall?.color,
      ),
    );
  }
}
