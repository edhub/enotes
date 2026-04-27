# Testing

## Commands

```bash
flutter analyze
flutter test
```

## Coverage focus

- parser and shortcut edge cases
- note state derivation and notifier mutations
- widget-level focus / search / tab interactions

## Guidance

- prefer pure logic tests first
- add widget tests for focus routing and keyboard behavior
- keep parser docs, parser tests, and parser implementation in sync
