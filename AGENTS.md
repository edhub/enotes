# eNotes — AGENTS.md

> 本文件是 AI 编码代理的工作指南，说明项目架构、约定和关键决策。

---

## 项目概览

**eNotes** 是一款专为 16 寸大屏笔记本优化的 Flutter 桌面笔记应用，核心功能是 **Timeline Kanban（时间轴画板）** 布局：将笔记按时间分组横向排列成多列，充分利用宽屏空间。

- **平台目标**：macOS Desktop
- **Flutter 版本**：3.41.6（Dart SDK ^3.11.4）
- **状态管理**：`provider` (ChangeNotifier)
- **持久化**：`path_provider` + JSON 文件（无代码生成）

---

## 代码组织原则

> **Vertical Slicing（按功能切片）**：所有代码按 Feature 组织，而不是按技术层。

```
lib/
├── main.dart                        # 入口：初始化 + runApp
├── app.dart                         # MaterialApp + Theme + Provider 注入
│
├── features/
│   ├── notes/                       # 笔记核心 Feature
│   │   ├── models/
│   │   │   ├── note.dart            # Note 数据类（不可变 createdAt）
│   │   │   └── time_group.dart      # TimeGroup 枚举 + 时间分组逻辑
│   │   ├── services/
│   │   │   └── notes_service.dart   # JSON 读写（path_provider）
│   │   ├── providers/
│   │   │   └── notes_provider.dart  # ChangeNotifier：全量业务逻辑
│   │   └── widgets/
│   │       ├── timeline_kanban_view.dart   # 根布局：横向滚动 + 列编排（含 _AddNoteFab）
│   │       ├── draft_column.dart           # 草稿列（600px），Chrome 风格 tab 栏
│   │       ├── time_column.dart            # 时间分组列（450px）
│   │       ├── trash_column.dart           # 回收站列（400px，最右侧）
│   │       ├── note_card.dart              # 单条笔记卡片（inline MarkdownEditor）
│   │       └── column_header.dart          # 吸顶列标题
│   │
│   └── editor/                      # 编辑器 Feature（自研 Markdown 编辑器）
│       ├── controllers/
│       │   └── markdown_controller.dart    # TextEditingController 子类，内联 Markdown 高亮
│       ├── parsers/
│       │   └── markdown_parser.dart        # 自研 Markdown → TextSpan 解析器
│       ├── services/
│       │   └── markdown_shortcuts.dart     # Cmd+B/L 快捷键逻辑（纯函数）
│       └── widgets/
│           └── markdown_editor.dart        # 基于 TextField 的编辑器 widget
│
└── core/
    ├── constants/
    │   └── layout_constants.dart    # 列宽、间距等魔法数字
    └── theme/
        └── app_theme.dart           # 颜色、文字样式
```

---

## 数据模型

### `Note`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | UUID v4，创建时生成 |
| `content` | `String` | 笔记正文，无长度限制 |
| `createdAt` | `DateTime` | **不可变**，决定所属时间列 |
| `updatedAt` | `DateTime` | 每次编辑更新，但不影响位置 |
| `isDraft` | `bool` | true → 显示在草稿列 |
| `deletedAt` | `DateTime?` | 软删除时间戳；null 表示活跃 |

> **关键约束**：`createdAt` 一经创建永不修改；编辑笔记只更新 `content` 和 `updatedAt`。

### 时间分组优先级（`TimeGroup`）

```
today > yesterday > thisWeek > lastWeek > isoWeek(2026W06...)
```

- **today**：`createdAt.date == now.date`
- **yesterday**：`createdAt.date == now.date - 1`
- **thisWeek**：同 ISO 周，但非 today/yesterday
- **lastWeek**：上一个 ISO 周
- **isoWeek**：更早，格式为 `2026W06`

**跳跃逻辑**：某时间段无笔记则该列不显示。

---

## 状态管理（NotesProvider）

```dart
class NotesProvider extends ChangeNotifier {
  // 对外暴露
  List<Note> get draftNotes           // 草稿（createdAt 升序，固定 5 个 tab）
  int get activeDraftIndex            // 当前激活的草稿 tab 索引
  List<TimeColumnData> get timeColumns   // 分组后的时间列数据
  List<Note> get trashedNotes         // 软删除笔记（deletedAt 倒序）
  String? get pendingFocusNoteId      // 待聚焦笔记 ID（新建后使用）

  // 操作
  void addNote(String content)                  // 新建笔记 → today 顶部
  void updateNote(String id, String content)    // 更新内容，不改位置
  void deleteNote(String id)                    // 软删除（草稿不可删）
  void restoreNote(String id)                   // 从回收站恢复
  void permanentlyDeleteNote(String id)         // 永久删除（仅回收站）
  void emptyTrash()                             // 清空回收站
  void setActiveDraftIndex(int index)           // 切换草稿 tab
  void flushSave()                              // 立即写入（生命周期调用）
  void clearPendingFocus()                      // 清除待聚焦状态
}
```

`TimeColumnData` 结构：
```dart
class TimeColumnData {
  final String bucketKey;   // 'today' | 'yesterday' | 'this_week' | 'last_week' | 'week_YYYY_M_D'
  final TimeGroup group;
  final String label;       // "Today", "Yesterday", "2026 W11"…
  final List<Note> notes;   // 该列所有活跃笔记（插入顺序，稳定，不重新排序）
  final int sortOrder;      // 越小越靠左（today=0）
  int get totalCount;       // notes.length
}
```

---

## 布局实现要点

### 横向滚动

```
Scaffold
└── Stack
    ├── ScrollbarTheme + Scrollbar(horizontal)
    │   └── SingleChildScrollView(horizontal)
    │       └── IntrinsicHeight Row
    │           ├── [gap 24px]
    │           ├── DraftColumn (600px)
    │           ├── [gap 24px]
    │           ├── TimeColumn × N (500px each, gap 20px)
    │           └── [gap 24px]
    └── AddNoteFAB (Positioned bottom-right, 不随横向滚动)
```

### 列内纵向滚动

每列是一个独立的 `CustomScrollView`（拥有独立 `ScrollController`）：

```
CustomScrollView
├── SliverPersistentHeader(pinned: true)  → 吸顶标题
└── SliverList                             → 笔记卡片列表
```

### 鼠标滚轮行为

- 在列内悬停：滚轮 → 该列纵向滚动（Flutter 默认行为）
- 全局 `Listener`：检测 `Shift + PointerScrollEvent` → 转发至横向 ScrollController

### 草稿列高度

草稿卡片高度 = `MediaQuery.of(context).size.height - verticalPadding`，使用 `SizedBox` 强制设定，呈现沉浸感。

---

## 持久化

- 文件路径：`{appDocumentsDir}/enotes/notes.json`
- 格式：JSON array，每个元素对应一个 Note
- 策略：每次 Provider 变更后异步写入（`unawaited` fire-and-forget，不阻塞 UI）
- 启动时：`main()` 中 `await notesService.loadNotes()` 后再 `runApp`

---

## 依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.5+1
  path_provider: ^2.1.5
  intl: ^0.20.2
  uuid: ^4.5.3
```

无代码生成依赖，无复杂构建步骤。编辑器完全自研，零额外依赖。

---

## 核心交互原则：展示即编辑（Inline Editing）

> ⚠️ 这是 eNotes 最重要的 UX 决策，优先级高于所有其他交互模式。

**笔记卡片永远不弹出编辑对话框。** 点击内容即可直接原地输入，显示与编辑是同一个状态。

### 实现方案

编辑器完全自研，基于 Flutter 原生 `TextField`，**不依赖任何第三方编辑器库**。

- 每张 `NoteCard` 使用 `MarkdownEditor` widget（`features/editor/widgets/markdown_editor.dart`）
- `MarkdownController extends TextEditingController`：重写 `buildTextSpan`，通过 `MarkdownParser` 将文本实时解析为带样式的 `TextSpan` 树，实现 editor-mode Markdown 高亮（语法符号保留可见，光标位置始终准确）
- `MarkdownParser`：纯 Dart 自研解析器，支持标题、引用、列表、水平线、粗体、删除线、高亮、行内代码、链接，解析结果按 `(text, isDark)` 缓存
- `TextField(maxLines: null)`：卡片随内容高度自然撑开，无内部滚动
- `FocusNode` 用于检测编辑状态，聚焦时卡片边框高亮，失焦时触发立即保存
- 文字变动时 600ms 防抖自动保存（调用 `provider.updateNote`）
- `MarkdownShortcuts`（纯函数）处理快捷键：
  - `Cmd+B`：Toggle bold（`*...*`）
  - `Cmd+L`：Toggle unordered list（`- `）
  - `Shift+Cmd+L`：Toggle ordered list（`1. `）
  - `ESC`：失焦

### 选区行为说明

- 多行选区中，**中间完整选中的行**，高亮背景会延伸到最长行的宽度，形成矩形选区块
- 这是 Flutter `TextField` engine 级别的渲染行为，**符合预期，非 bug**

### 新建笔记流程

- 点击 FAB → 在 Today 列顶部插入一条空笔记 → 自动滚动到该笔记 → 自动聚焦 `MarkdownEditor`
- 草稿同理：插入草稿列第一槽，自动聚焦

---

## 开发约定

1. **只用 `edit` 做精确修改**，不整体重写已有文件
2. **Feature 内聚**：新增能力只在 `features/notes/` 内扩展
3. **常量提取**：所有像素值进 `layout_constants.dart`，颜色进 `app_theme.dart`
4. **无副作用 getter**：Provider 的 getter 只做计算，不触发 IO
5. **日期以 UTC 存储，以本地显示**：`createdAt.toLocal()` 用于展示

---

---

## Flutter 官方 AI 编码规范（1k 精简版）

> 原文：https://raw.githubusercontent.com/flutter/flutter/refs/heads/main/docs/rules/rules_1k.md  
> ⚠️ **项目级 Override**：`go_router` 不引入（单页无路由）；`json_serializable` 不引入（手写序列化，无代码生成）。

**Role:** Expert Dev. Premium, beautiful code.  
**Tools:** `dart format`, `dart fix`, `flutter analyze`.

**Stack:** State: `ValueNotifier` / `ChangeNotifier`. NO Riverpod/GetX. UI: Material 3, `ColorScheme.fromSeed`, Dark Mode.

**Code:** SOLID. Layers: Pres/Domain/Data. Naming: PascalTypes, camelMembers, snake_files. Async: `async/await` + try-catch. Log: `dart:developer` ONLY. Null: Sound safety, no `!`.

**Perf:** `const` everywhere. `ListView.builder`. `compute()` for heavy tasks.

**Testing:** `flutter test`, `integration_test`. A11y: 4.5:1 contrast, Semantics.

**Design:** "Wow" factor. Glassmorphism, shadows. Public API `///`. Explain "Why".

---

## 如何运行

```bash
# 安装依赖
flutter pub get

# 运行（macOS Desktop）
flutter run -d macos

# 运行（Chrome，用于调试布局）
flutter run -d chrome
```

---

## 关键设计决策 & 理由

| 决策 | 理由 |
|------|------|
| 用 JSON 文件而非 SQLite/Hive | 无代码生成，零依赖复杂度，笔记数量有限 |
| `createdAt` 不可变 | 确保笔记不会因编辑而跳列，实现"物理记忆" |
| `CustomScrollView` + `SliverPersistentHeader` | 原生吸顶，无需第三方包 |
| Provider 而非 Riverpod/Bloc | 项目规模不需要复杂状态，保持轻量 |
| 草稿列独立存在 | 灵感缓冲区与时间轴逻辑完全解耦 |
