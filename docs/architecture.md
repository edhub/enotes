# Architecture

- Platform: macOS desktop first
- State: Riverpod, handwritten providers only
- Storage: SQLite (`sqlite3`), WAL, incremental upsert/delete
- Editor: custom `TextField`-based Markdown editor
- Layout: Timeline Kanban — Draft | time columns | Trash

## Slices

- `features/notes/` — note model, state, storage, timeline UI
- `features/editor/` — parser, controller, shortcuts, editor widget
- `core/` — theme, constants, env, shared utils

## Rules

- Organize by feature, not by layer
- `createdAt` is immutable and decides the time column
- UI subscribes with `select()` where possible
- Widget files stay orchestration-focused; extract reusable pieces early
