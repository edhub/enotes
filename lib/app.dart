import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/notes/services/notes_service.dart';
import 'features/notes/widgets/timeline_kanban_view.dart';

/// Root widget. Wraps MaterialApp and observes app lifecycle for flush-saves.
///
/// [NotesService] and [initialNotes] are injected via [ProviderScope] overrides
/// in [main], so this widget needs no constructor parameters.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  // Cache the service so we can call dispose() after the provider scope tears
  // down (ref may no longer be usable at that point).
  late final NotesService _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(notesServiceProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  /// Flush pending saves when the app goes to background or is about to close.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(notesProvider.notifier).flushSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eNotes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(
        extensions: const [NoteColors.light],
      ),
      darkTheme: AppTheme.dark().copyWith(
        extensions: const [NoteColors.dark],
      ),
      themeMode: ThemeMode.system,
      home: const TimelineKanbanView(),
    );
  }
}
