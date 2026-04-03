# Riverpod 3.x — 在本项目中的用法

> 版本：`flutter_riverpod ^3.3.1`  
> 本项目**不使用代码生成**（无 `riverpod_annotation` / `build_runner`），所有 provider 手写。

---

## 核心概念速查

| 概念 | 本项目用法 |
|---|---|
| `Provider<T>` | 注入基础设施（`NotesService`、初始数据） |
| `NotifierProvider<N, S>` | 业务状态（`notesProvider`） |
| `Notifier<S>` | 业务逻辑（`NotesNotifier`） |
| `@immutable` state | `NotesState`，所有字段 `final` |
| `ConsumerWidget` | 无本地状态的 widget |
| `ConsumerStatefulWidget` | 有本地状态（FocusNode、Timer 等）的 widget |
| `ConsumerState<T>` | 对应的 State 基类，`ref` 作为 getter 直接可用 |
| `WidgetRef` | widget 中访问 provider 的接口（`build` 参数或 `ConsumerState.ref`） |

---

## Provider 定义

### 基础设施 Provider（注入用，在 `ProviderScope` 覆盖）

```dart
// 定义时故意 throw，强制调用方在 ProviderScope 中 override
final notesServiceProvider = Provider<NotesService>((ref) {
  throw UnimplementedError('必须在 ProviderScope.overrides 中覆盖');
});

final initialNotesProvider = Provider<List<Note>>((ref) {
  throw UnimplementedError('必须在 ProviderScope.overrides 中覆盖');
});
```

### 业务 NotifierProvider

```dart
final notesProvider = NotifierProvider<NotesNotifier, NotesState>(
  NotesNotifier.new,  // 等价于 () => NotesNotifier()
);
```

### Notifier 模板

```dart
class NotesNotifier extends Notifier<NotesState> {
  @override
  NotesState build() {
    // build() 是初始化方法，可调用 ref.read / ref.watch / ref.onDispose
    // ref.onDispose 用于注册清理逻辑（Timer、Stream 等）
    ref.onDispose(() => _saveTimer?.cancel());

    final initialNotes = ref.read(initialNotesProvider);
    return NotesState(notes: List<Note>.from(initialNotes));
  }

  void addNote(String content) {
    // 通过 state = ... 触发所有监听者重建
    state = state.copyWith(notes: [Note.create(...), ...state.notes]);
    _scheduleSave();
  }
}
```

---

## ProviderScope 注入

在 `main.dart` 中，通过 `overrides` 将真实实例注入：

```dart
runApp(
  ProviderScope(
    overrides: [
      notesServiceProvider.overrideWithValue(service),
      initialNotesProvider.overrideWithValue(initialNotes),
    ],
    child: const App(),
  ),
);
```

- `App` 本身不需要任何构造参数
- 任何层级的 widget / notifier 通过 `ref.read(notesServiceProvider)` 获取

---

## Widget 中读取状态

### `ConsumerWidget`（无本地状态）

```dart
class DraftColumn extends ConsumerWidget {
  const DraftColumn({super.key, required this.availableHeight});
  final double availableHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .select() 精细订阅：只有 draftNotes 变化才重建此 widget
    final drafts = ref.watch(notesProvider.select((s) => s.draftNotes));
    // ...
  }
}
```

### `ConsumerStatefulWidget`（有本地状态）

```dart
class NoteCard extends ConsumerStatefulWidget {
  const NoteCard({super.key, required this.note, ...});
  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard> {
  // ref 是 ConsumerState 的 getter，无需在 build 参数中接收
  // 可在任意方法中使用（initState 除外需注意时序）

  void _flushSave() {
    ref.read(notesProvider.notifier).updateNote(widget.note.id, content);
  }
}
```

### `ref.watch` vs `ref.read`

| | `ref.watch` | `ref.read` |
|---|---|---|
| 用途 | 订阅状态，值变化时重建 | 一次性读取，不订阅 |
| 调用位置 | `build()` 方法内（含 helper 方法） | 事件回调、生命周期方法 |
| 典型场景 | 渲染数据 | 触发操作（`addNote`、`deleteNote`） |

```dart
// ✅ 正确
final columns = ref.watch(notesProvider.select((s) => s.timeColumns));
ref.read(notesProvider.notifier).deleteNote(id);   // 在 onTap 回调中

// ❌ 错误：在 onTap 等事件中使用 watch
onTap: () => ref.watch(notesProvider).addNote(...); // 不要这样
```

---

## `.select()` 精细订阅

`.select()` 让 widget 只在关心的字段变化时重建，避免无关更新触发重绘。

```dart
// 只订阅 newNoteFocusRequest，其他字段变化不触发重建
final req = ref.watch(notesProvider.select((s) => s.newNoteFocusRequest));

// 订阅某个时间列（按 bucketKey 筛选）
final col = ref.watch(
  notesProvider.select(
    (s) => s.timeColumns.firstWhere(
      (c) => c.bucketKey == widget.data.bucketKey,
      orElse: () => widget.data,
    ),
  ),
);
```

`.select()` 使用 `==` 比较前后值。对于 `List` 等引用类型，**若内容相同但引用不同，仍会触发重建**。如需深比较，需在 state 层保持引用稳定，或重写 `==`。

---

## `ref.onDispose` 清理资源

在 `Notifier.build()` 中注册，provider 销毁（或 rebuild）时自动调用：

```dart
@override
NotesState build() {
  final timer = Timer.periodic(...);
  ref.onDispose(timer.cancel);          // provider 销毁时取消 timer

  final subscription = stream.listen(...);
  ref.onDispose(subscription.cancel);   // 多个 onDispose 可叠加注册
  // ...
}
```

---

## 不可变状态（`NotesState`）

所有状态字段 `final`，变更通过 `copyWith` 产生新实例。

### 派生视图的稳定引用

`draftNotes`、`timeColumns`、`trashedNotes` 是 `final` 字段，而非 getter。
构造时通过静态 helper 一次性计算，`copyWith` 在 `notes` 不变时复用旧引用：

```dart
@immutable
class NotesState {
  // 公共构造器：立即计算三个派生视图
  NotesState({required List<Note> notes, ...})
      : this._(notes: notes,
               draftNotes: _computeDraftNotes(notes),
               timeColumns: _computeTimeColumns(notes),
               trashedNotes: _computeTrashedNotes(notes),
               ...);

  // 内部构造器：所有字段直接赋值（copyWith 用）
  const NotesState._({required this.notes,
                      required this.draftNotes, ...});

  final List<Note> notes;
  final List<Note> draftNotes;          // 稳定引用
  final List<TimeColumnData> timeColumns; // 稳定引用
  final List<Note> trashedNotes;        // 稳定引用
  final int activeDraftIndex;
  final int newNoteFocusRequest;

  NotesState copyWith({List<Note>? notes, int? activeDraftIndex, ...}) {
    if (notes == null) {
      // notes 未变：三个派生列表保持原引用 → select() 比较相等 → 跳过重建
      return NotesState._(notes: this.notes,
                          draftNotes: draftNotes,   // ← 同一引用
                          timeColumns: timeColumns, // ← 同一引用
                          trashedNotes: trashedNotes,
                          ...);
    }
    // notes 变了：重新计算所有派生视图
    return NotesState._(notes: notes,
                        draftNotes: _computeDraftNotes(notes),
                        ...);
  }
}
```

### 实际效果

| 操作 | notes 变？ | 派生列表引用 | 受影响 widget |
|---|---|---|---|
| `addNote` / `deleteNote` | ✅ | 新实例 | 所有订阅者重建 |
| `setActiveDraftIndex` | ❌ | **复用** | 只有订阅 `activeDraftIndex` 的重建 |
| `requestNewNoteFocus` | ❌ | **复用** | 只有订阅 `newNoteFocusRequest` 的重建 |

> ⚠️ 当 `notes` 变化时（如 `addNote`），三个派生列表全部重算，即使部分内容未变（例如新增普通笔记不影响 `trashedNotes`）。这是合理的简化：修复这个需要深比较，目前笔记量级不值得。

---

## 未来：跨 Feature 派生 Provider

这是选用 Riverpod 的核心原因。当 tags / tasks 加入后：

```dart
// tags feature 自己的 provider
final tagsProvider = NotifierProvider<TagsNotifier, TagsState>(TagsNotifier.new);

// 跨 Feature 派生——无需 ProxyProvider 链
final taggedNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(notesProvider.select((s) => s.notes));
  final tags  = ref.watch(tagsProvider.select((s) => s.activeTags));
  return notes.where((n) => tags.any((t) => n.tagIds.contains(t.id))).toList();
});

// 统计、搜索类 provider 同理
final statsProvider = Provider<AppStats>((ref) {
  final noteCount = ref.watch(notesProvider.select((s) => s.notes.length));
  final taskCount = ref.watch(tasksProvider.select((s) => s.tasks.length));
  return AppStats(noteCount: noteCount, taskCount: taskCount);
});
```

**Riverpod 自动追踪依赖**：任一上游变化，下游 provider 自动失效并重算。

---

## 禁用模式（Anti-patterns）

```dart
// ❌ 不用 legacy API（已移入 flutter_riverpod/legacy.dart）
ChangeNotifierProvider(...)
StateProvider(...)
StateNotifierProvider(...)

// ❌ 不用 riverpod_annotation / build_runner（无代码生成）
@riverpod
class MyNotifier extends _$MyNotifier { ... }

// ❌ 不在 build() 外使用 ref.watch
void someMethod() {
  final s = ref.watch(notesProvider); // 应改为 ref.read
}
```
