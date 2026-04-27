import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/features/notes/providers/search_provider.dart';
import 'package:enotes/features/notes/widgets/note_search_bar.dart';

void main() {
  testWidgets('typing updates query after debounce; ESC clears it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: NoteSearchBar())),
      ),
    );

    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.enterText(field, 'hello world');
    await tester.pump(const Duration(milliseconds: 80));
    expect(container.read(searchQueryProvider).query, '');

    await tester.pump(const Duration(milliseconds: 80));
    expect(container.read(searchQueryProvider).query, 'hello world');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(searchQueryProvider).query, '');
    expect(find.text('hello world'), findsNothing);
  });
}
