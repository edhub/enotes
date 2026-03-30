import 'package:flutter/material.dart';

import 'app.dart';
import 'features/notes/services/notes_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = NotesService();
  final initialNotes = await service.loadNotes();
  runApp(App(service: service, initialNotes: initialNotes));
}
