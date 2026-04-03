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
| 持久化 | SQLite（`sqlite3`），启动前完成初始化 |
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
│   │   │   ├── notes_service.dart   # SQLite 读写
│   │   │   ├── migration_service.dart  # JSON → SQLite 一次性迁移
│   │   │   └── export_service.dart  # JSON/Markdown 导入导出
│   │   ├── providers/
│   │   │   └── notes_provider.dart  # NotesState + NotesNotifier + 基础设施 providers
│   │   └── widgets/
│   │       ├── timeline_kanban_view.dart   # 根布局：横向滚动 + 列编排
│   │       ├── draft_column.dart           # 草稿列（600px），Chrome 风格 tab 栏
│   │       ├── time_column.dart            # 时间分组列（500px）含新建笔记 Composer
│   │       ├── trash_column.dart           # 回收站列（最右侧）
│   │       ├── note_card.dart              # 单条笔记卡片（inline MarkdownEditor）
│   │       └── column_header.dart          # 吸顶列标题
│   │
│   └── editor/                      # 编辑器 Feature（自研 Markdown 编辑器）
│       ├── controllers/
│       │   └── markdown_controller.dart    # TextEditingController 子类，内联高亮
│       ├── parsers/
│       │   └── markdown_parser.dart        # Markdown → TextSpan 解析器
│       ├── services/
│       │   └── markdown_shortcuts.dart     # Cmd+B/L 快捷键（纯函数）
│       └── widgets/
│           └── markdown_editor.dart        # 基于 TextField 的编辑器 widget
│
└── core/
    ├── constants/
    │   └── layout_constants.dart    # 列宽、间距等魔法数字
    ├── env/
    │   └── app_env.dart             # DB 文件名（dev/release 分离）
    └── theme/
        └── app_theme.dart           # 颜色、文字样式（NoteColors ThemeExtension）
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

---

## 布局

```
Scaffold → Stack
  ├── Scrollbar + SingleChildScrollView(horizontal)   ← 横向主轴
  │     └── SizedBox(height) → Row
  │           ├── DraftColumn (600px)
  │           ├── TimeColumn × N (500px each)
  │           └── TrashColumn
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
- `Cmd+B/L`、`Shift+Cmd+L`、`ESC` 快捷键

---

## 开发约定

1. **精确修改**：用 `edit` 做局部替换，不整体重写已有文件
2. **Feature 内聚**：新能力在对应 feature 目录内扩展
3. **常量提取**：像素值 → `layout_constants.dart`，颜色 → `app_theme.dart`
4. **Notifier 方法无副作用**：`NotesState` 的计算 getter 只做计算，不触发 IO
5. **日期 UTC 存储，本地显示**：展示时用 `createdAt.toLocal()`
6. **日志**：只用 `dart:developer` 的 `log()`，不用 `print()`
7. **Null safety**：不用 `!` 强制解包

---

## 关键设计决策

| 决策 | 理由 |
|---|---|
| SQLite 而非 JSON 文件 | WAL 模式写入安全，支持未来 tags/tasks 表关联 |
| `createdAt` 不可变 | 笔记不会因编辑而跳列，实现"物理记忆" |
| `CustomScrollView` + `SliverPersistentHeader` | 原生吸顶，无需第三方包 |
| Riverpod 而非 ChangeNotifier | 为 notes/tags/tasks 跨 Feature 状态依赖做准备（见 `docs/riverpod.md`） |
| 草稿列独立 | 灵感缓冲区与时间轴逻辑完全解耦 |
| 编辑器自研 | 零依赖，对 inline Markdown 高亮完全可控 |

---

## 如何运行

```bash
flutter pub get
flutter run -d macos   # 主目标
flutter run -d chrome  # 调试布局
flutter analyze        # 静态检查（应 0 issues）
```
