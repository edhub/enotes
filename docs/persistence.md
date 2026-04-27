# Persistence

## Flow

`NotesNotifier` tracks dirty and removed ids, then flushes them with an 800 ms debounce.

- add / edit / soft-delete → `upsertNotes(...)`
- permanent delete / empty trash → `deleteNotesByIds(...)`
- import → full replace via `saveNotes(...)`

## Guarantees

- SQLite in WAL mode
- `createdAt` stored in UTC and never changed
- app lifecycle flush on `hidden` / `paused` / `detached`
- startup migration only runs when SQLite is empty and legacy JSON exists

## Non-goals

- no full-table rewrite during normal editing
- no background sync yet
