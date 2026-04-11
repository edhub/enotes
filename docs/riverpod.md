# Riverpod — 项目约定

> `flutter_riverpod ^3.3.1`，**不使用代码生成**（无 `riverpod_annotation` / `build_runner`）。

---

## 约定

- 所有 provider 手写，放在对应 feature 的 `providers/` 目录
- 基础设施 provider（`notesServiceProvider` 等）用 `throw` 作默认值，在 `main()` 的 `ProviderScope.overrides` 中注入
- 状态类标注 `@immutable`，所有字段 `final`，变更通过 `copyWith`
- `build()` 方法内用 `ref.watch`（订阅）；事件回调 / 生命周期用 `ref.read`（不订阅）
- 用 `.select()` 精细订阅，减少不必要的 widget 重建

## `select()` 陷阱

`.select()` 用 `==` 比较。`List` 等引用类型即使内容相同，引用不同仍会触发重建。

**对策：** `NotesState.copyWith` 在 `notes` 未变时复用 `draftNotes` / `timeColumns` / `trashedNotes` 的旧引用，使 `select()` 能正确跳过重建。新增字段如果是 `List` 类型，必须遵循同样模式。

## 跨 Provider 派生

已有案例：`filteredTimeColumnsProvider` 同时 `ref.watch` `searchQueryProvider` 和 `notesProvider`，Riverpod 自动追踪依赖。未来 tags / tasks 用同样模式。

## 禁用

```dart
// ❌ 不用 legacy API
ChangeNotifierProvider / StateProvider / StateNotifierProvider

// ❌ 不用 riverpod_annotation / build_runner
@riverpod class MyNotifier extends _$MyNotifier { ... }

// ❌ 不在 build() 外 ref.watch
void someMethod() { ref.watch(...); } // → 改 ref.read
```
