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

  // ScaffoldMessenger key lets us show SnackBars from `ref.listen` callbacks
  // without needing a BuildContext below the MaterialApp boundary.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

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

  /// Flush pending saves when the app is hidden, paused, or about to close.
  ///
  /// We deliberately skip [AppLifecycleState.inactive] — on macOS it fires
  /// every time the window loses focus (e.g. ⌘-Tab to another app), which is
  /// far too aggressive for a save-on-blur model and would force a flush
  /// every few seconds during normal multitasking.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(notesProvider.notifier).flushSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Surface persistence errors as non-blocking SnackBars. We listen here
    // rather than inside the home widget so the message is shown regardless
    // of which screen is currently visible.
    ref.listen<String?>(saveErrorProvider, (prev, next) {
      if (next == null || next == prev) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(next),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () => ref.read(saveErrorProvider.notifier).clear(),
          ),
        ),
      );
    });

    return MaterialApp(
      title: 'eNotes',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const TimelineKanbanView(),
    );
  }
}
