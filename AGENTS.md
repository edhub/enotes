# eNotes — AGENTS.md

> AI 编码代理的工作指南。详细专题见 `docs/` 目录。

---

## 项目概览

**eNotes** 是一款专为 16 寸大屏笔记本优化的 Flutter 桌面笔记应用，核心是 **Timeline Kanban** 布局：笔记按时间分组横向排列成多列，充分利用宽屏空间。

| 项 | 值 |
|---|---|
| 平台 | macOS Desktop |
| Flutter | 3.41.6（Dart SDK ^3.11.4）|
| 状态管理 | `flutter_riverpod ^3.3.1` — 见 [`docs/riverpod.md`](docs/riverpod.md) |
| 持久化 | SQLite（`sqlite3`），WAL 模式，增量写入 |
| 编辑器 | 完全自研，基于 `TextField`，零第三方依赖 |

---

## 代码组织（Vertical Slicing）

> 所有代码按 Feature 组织，不按技术层。

```
lib/
├── main.dart                        # 入口：初始化 SQLite + runApp + ProviderScope
├── app.dart                         # MaterialApp + Theme + 生命周期 flush
│
├── features/
│   ├── notes/                       # 笔记核心 Feature
│   │   ├── models/
│   │   │   ├── note.dart            # Note 数据类（不可变 createdAt）
│   │   │   └── time_group.dart      # TimeGroup 枚举 + 分组逻辑
│   │   ├── services/
│   │   │   ├── notes_service.dart   # SQLite 读写（全量 + 增量）
│   │   │   ├── migration_service.dart  # JSON → SQLite 一次性迁移
│   │   │   └── export_service.dart  # JSON/Markdown 导入导出
│   │   ├── providers/
│   │   │   ├── notes_provider.dart  # NotesState + NotesNotifier + 基础设施 providers
│   │   │   └── search_provider.dart # SearchState + filteredTimeColumnsProvider
│   │   └── widgets/
│   │       ├── timeline_kanban_view.dart   # 根布局：横向滚动 + 列编排
│   │       ├── draft_column.dart           # 草稿列（450px），Chrome 风格 tab 栏
│   │       ├── time_column.dart            # 时间分组列（380px）含新建笔记 Composer
│   │       ├── trash_column.dart           # 回收站列（最右侧）
│   │       ├── note_card.dart              # 单条笔记卡片（inline MarkdownEditor）
│   │       ├── note_card_container.dart    # 共享卡片装饰（border/shadow/hover）
│   │       ├── note_info_menu.dart         # 笔记信息弹窗（时间戳 + 删除）
│   │       ├── trash_note_card.dart        # 回收站只读卡片（恢复/永久删除）
│   │       ├── note_search_bar.dart        # 搜索栏（Cmd+F 触发）
│   │       └── column_header.dart          # 吸顶列标题 + CountBadge
│   │
│   └── editor/                      # 编辑器 Feature（自研 Markdown 编辑器）
│       ├── controllers/
│       │   └── markdown_controller.dart    # TextEditingController 子类，内联高亮
│       ├── parsers/
│       │   └── markdown_parser.dart        # Markdown → TextSpan 解析器
│       ├── services/
│       │   └── markdown_shortcuts.dart     # Cmd+B/L 快捷键 + handleKeyEvent 共享入口
│       └── widgets/
│           └── markdown_editor.dart        # 基于 TextField 的编辑器 widget
│
└── core/
    ├── constants/
    │   └── layout_constants.dart    # 列宽、间距等魔法数字
    ├── env/
    │   └── app_env.dart             # DB 文件名（dev/release 分离）
    ├── theme/
    │   └── app_theme.dart           # 颜色、文字样式（NoteColors ThemeExtension）
    └── utils/
        └── date_formatter.dart      # 共享相对/绝对时间格式化
```

---

## 数据模型

### `Note`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | UUID v4，创建时生成 |
| `content` | `String` | 笔记正文 |
| `createdAt` | `DateTime` | **不可变**，决定所属时间列 |
| `updatedAt` | `DateTime` | 每次编辑更新，不影响列位置 |
| `isDraft` | `bool` | true → 草稿列 |
| `deletedAt` | `DateTime?` | 软删除时间戳；null 表示活跃 |

> `createdAt` 一经创建永不修改，确保笔记不因编辑而跳列。

### 时间分组优先级

```
today > yesterday > thisWeek > lastWeek > isoWeek(2026W06…)
```

某时间段无笔记则该列不显示（today 列永远存在）。

---

## 状态管理

详见 [`docs/riverpod.md`](docs/riverpod.md)。

**速查：**

```dart
// 订阅（精细，推荐）
ref.watch(notesProvider.select((s) => s.timeColumns))

// 操作（不订阅）
ref.read(notesProvider.notifier).addNote(content)
```

`NotesState` 计算属性：`draftNotes` / `timeColumns` / `trashedNotes` / `allNotes`

搜索：`searchQueryProvider` → `filteredTimeColumnsProvider`（跨 provider 派生）

---

## 持久化

```
NotesNotifier
  ├── addNote / updateNote / deleteNote → _markDirty(id) → _scheduleSave()
  ├── permanentlyDeleteNote / emptyTrash → _markRemoved(id) → _scheduleSave()
  └── flushSave() → _persistDirty()
        ├── upsertNotes(dirtyNotes)      ← INSERT OR REPLACE
        └── deleteNotesByIds(removedIds) ← DELETE WHERE id = ?
```

- 增量保存：只写变更的笔记，不做全表 DELETE + INSERT
- 800ms 防抖；失焦立即 flush；生命周期 inactive/detached 时 flush
- `importNotes` 例外：全量 DELETE + INSERT（完整替换）

---

## 布局

```
Scaffold → Stack
  ├── Scrollbar + SingleChildScrollView(horizontal)   ← 横向主轴
  │     └── SizedBox(height) → Row
  │           ├── DraftColumn (450px)
  │           ├── TimeColumn × N (380px each)
  │           └── TrashColumn (380px)
  └── Positioned：Jump button（左下）、DataMenuButton（右上）
```

每列是独立的 `CustomScrollView`，`SliverPersistentHeader(pinned)` 实现吸顶标题。
`Shift + 滚轮` 在 `Listener` 层拦截，转发给横向 `ScrollController`。

---

## 核心 UX：展示即编辑（Inline Editing）

> ⚠️ 最高优先级 UX 决策：**笔记卡片永远不弹出对话框**，点击即原地输入。

- `MarkdownController extends TextEditingController`：`buildTextSpan` 实时 Markdown 高亮
- `TextField(maxLines: null)`：随内容自然撑高，无内部滚动
- 失焦立即保存；600ms 防抖处理频繁输入
- `Cmd+B/L`、`Shift+Cmd+L`、`ESC` 快捷键（通过 `MarkdownShortcuts.handleKeyEvent` 共享）

---

## 共享组件

| 组件 | 位置 | 用途 |
|---|---|---|
| `NoteCardContainer` | `widgets/note_card_container.dart` | 统一卡片 border/shadow/hover 装饰 |
| `NoteInfoMenu` / `NoteInfoButton` | `widgets/note_info_menu.dart` | 笔记信息弹窗（时间戳、删除） |
| `CountBadge` | `widgets/column_header.dart` | 列标题数字角标 |
| `DateFormatter` | `core/utils/date_formatter.dart` | 相对/绝对时间格式化 |
| `MarkdownShortcuts.handleKeyEvent` | `editor/services/markdown_shortcuts.dart` | 快捷键统一入口 |

---

## 开发约定

1. **精确修改**：用 `edit` 做局部替换，不整体重写已有文件
2. **Feature 内聚**：新能力在对应 feature 目录内扩展
3. **常量提取**：像素值 → `layout_constants.dart`，颜色 → `app_theme.dart`（`NoteColors`）
4. **Notifier 方法无副作用**：`NotesState` 的计算 getter 只做计算，不触发 IO
5. **日期 UTC 存储，本地显示**：展示时用 `createdAt.toLocal()`
6. **日志**：只用 `dart:developer` 的 `log()`，不用 `print()`
7. **Null safety**：不用 `!` 强制解包
8. **DRY**：卡片装饰用 `NoteCardContainer`；时间格式化用 `DateFormatter`；快捷键用 `MarkdownShortcuts.handleKeyEvent`

---

## 关键设计决策

| 决策 | 理由 |
|---|---|
| SQLite + 增量写入 | WAL 模式写入安全；`upsertNotes` / `deleteNotesByIds` 避免全量重写 |
| `createdAt` 不可变 | 笔记不会因编辑而跳列，实现"物理记忆" |
| `CustomScrollView` + `SliverPersistentHeader` | 原生吸顶，无需第三方包 |
| Riverpod 而非 ChangeNotifier | 为 notes/tags/tasks 跨 Feature 状态依赖做准备（见 `docs/riverpod.md`） |
| 草稿列独立 | 灵感缓冲区与时间轴逻辑完全解耦 |
| 编辑器自研 | 零依赖，对 inline Markdown 高亮完全可控 |
| 全局 Overlay 弹窗 | `NoteInfoMenu` 用静态单例确保同时只有一个弹窗，避免 focus 干扰 |

---

## 如何运行

```bash
flutter pub get
flutter run -d macos   # 主目标
flutter run -d chrome  # 调试布局
flutter analyze        # 静态检查（应 0 issues）
flutter test           # 单元测试
```
