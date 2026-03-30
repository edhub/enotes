import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/notes/models/note.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/notes/services/notes_service.dart';
import 'features/notes/widgets/timeline_kanban_view.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    required this.service,
    required this.initialNotes,
  });

  final NotesService service;
  final List<Note> initialNotes;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final NotesProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = NotesProvider(
      service: widget.service,
      initialNotes: widget.initialNotes,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.dispose();
    super.dispose();
  }

  /// Flush pending saves when the app goes to background or is about to close.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _provider.flushSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotesProvider>.value(
      value: _provider,
      child: MaterialApp(
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
      ),
    );
  }
}
