# eNotes

A distraction-free note-taking app for macOS, built with Flutter.

## What it does

eNotes uses a **Timeline Kanban** layout: notes are grouped by creation date into
columns (Today, Yesterday, This Week, Last Week, …) and arranged side-by-side
across a wide screen. A permanent Draft column on the left provides a scratch
space with 5 persistent tabs.

Key features:

- **Inline editing** — click any note to start typing. No dialogs, no modals.
- **Markdown syntax highlighting** — custom parser/controller with headings, lists, links, code, strike, and `==highlight==`
- **Timeline columns** — notes are placed by creation date; editing never moves them
- **Draft tabs** — 5 Chrome-style persistent draft slots
- **Full-text search** — Cmd+F to filter notes across all columns with highlighted matches
- **Soft-delete / Trash** — deleted notes move to a Trash column; restore or
  permanently remove from there
- **Auto-save** — debounced 800 ms incremental write, with an immediate flush on app close
- **Import / Export** — JSON full backup and Markdown plain-text export
- **Dark / Light mode** — follows macOS system preference

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+K` | Focus the new-note composer in the Today column |
| `Cmd+F` | Focus the search bar (filter all columns) |
| `Cmd+1` … `Cmd+5` | Switch to draft tab 1–5 and focus its editor |
| `Cmd+B` | Toggle bold (`*…*`) around the selection |
| `Cmd+L` | Toggle unordered list (`- `) on selected lines |
| `Shift+Cmd+L` | Toggle ordered list (`1. `, `2. `…) |
| `Enter` (in a list / quote line) | Continue the prefix; on an empty list line, terminate it |
| `ESC` | Unfocus the editor (also clears the search bar) |
| `Shift + mouse wheel` | Scroll horizontally across columns |

## Platform

macOS Desktop (primary target). Flutter 3.x, Dart SDK `^3.11.4`.

## Running

```bash
flutter pub get
flutter run -d macos
```

## Docs

- [Architecture](docs/architecture.md)
- [Persistence](docs/persistence.md)
- [Editor & Markdown](docs/editor-markdown.md)
- [Testing](docs/testing.md)
- [Riverpod conventions](docs/riverpod.md)
- [UI Visual Spec](docs/ui-visual-spec.md)

## Build & deploy

```bash
just deploy   # build release → copy to /Applications → launch
just build    # release build only
just install  # stop running instance + copy to /Applications
just run      # open /Applications/enotes.app
```

## Data storage

Notes are persisted in SQLite (WAL mode) at:

```
~/Library/Application Support/com.example.enotes/enotes.db       # Release
~/Library/Application Support/com.example.enotes/enotes_dev.db   # Debug
```

A one-time migration from the legacy JSON format runs automatically on first launch.
