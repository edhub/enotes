# eNotes

A distraction-free note-taking app for macOS, built with Flutter.

## What it does

eNotes uses a **Timeline Kanban** layout: notes are grouped by creation date into
columns (Today, Yesterday, This Week, Last Week, …) and arranged side-by-side
across a wide screen. A permanent Draft column on the left provides a scratch
space with 5 persistent tabs.

Key features:

- **Inline editing** — click any note to start typing. No dialogs, no modals.
- **Markdown syntax highlighting** via `re_editor`
- **Timeline columns** — notes are placed by creation date; editing never moves them
- **Draft tabs** — 5 Chrome-style persistent draft slots
- **Soft-delete / Trash** — deleted notes move to a Trash column; restore or
  permanently remove from there
- **Auto-save** — debounced 800 ms write, with an immediate flush on app close
- **Dark / Light mode** — follows macOS system preference

## Platform

macOS Desktop (primary target). Flutter 3.x, Dart SDK `^3.11.4`.

## Running

```bash
flutter pub get
flutter run -d macos
```

## Build & deploy

```bash
just deploy   # build release → copy to /Applications → launch
just build    # release build only
just install  # stop running instance + copy to /Applications
just run      # open /Applications/enotes.app
```

## Data storage

Notes are persisted as JSON at:

```
~/Documents/enotes/notes.json
```
