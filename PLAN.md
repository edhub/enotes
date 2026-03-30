# eNotes — PLAN.md

> Timeline Kanban 功能完整实现计划。包含关键技术决策、实现方案与分阶段 Todo。

---

## 一、关键技术决策 (Technical Decisions)

### TD-01 横向滚动与纵向滚动共存

**问题**：外层横向 `ScrollView` + 每列独立纵向 `ScrollView`，鼠标滚轮如何不冲突？

**分析**：Flutter desktop 的滚动事件路由基于**方向分离**原则——`CustomScrollView`（vertical）只消费 dy 事件，`SingleChildScrollView(horizontal)` 只消费 dx 事件。两者方向正交，天然不冲突，无需手动拦截。

**macOS Trackpad**：双指横划生成 dx 事件 → 横向滚动自然响应。  
**Shift + 鼠标滚轮**：滚轮只生成 dy，需在外层包 `Listener`，检测 `HardwareKeyboard.instance.isShiftPressed`，手动将 dy 转发给横向 `ScrollController`。

**决策** ✅：`SingleChildScrollView(horizontal)` + 每列 `CustomScrollView`，顶层 `Listener` 处理 Shift+Wheel。

---

### TD-02 各列高度填满视口

**问题**：列在 `Row` 内，如何让 `CustomScrollView` 获得确定高度、不 unbounded？

**方案 A**：每列用 `SizedBox(height: availableHeight)`，`availableHeight = screenHeight - topPadding`  
**方案 B**：用 `IntrinsicHeight` 包裹 `Row`（性能差，layout 要两次）  
**方案 C**：`LayoutBuilder` 获取约束高度

**决策** ✅：方案 A。在 `TimelineKanbanView` 用 `LayoutBuilder` 拿到 `constraints.maxHeight`，传给每一列作为显式高度。稳定、无性能开销。

```
Scaffold
└── LayoutBuilder(constraints)
    └── Stack
        ├── Scrollbar(horizontal)
        │   └── SingleChildScrollView(horizontal)
        │       └── SizedBox(height: constraints.maxHeight)  // ← 关键
        │           └── Row(columns...)
        └── FAB / JumpButton (fixed)
```

---

### TD-03 草稿卡片沉浸式高度

**需求**：草稿卡片高度"顶满窗口"，呈现沉浸式输入体验。

**决策** ✅：每张草稿 `NoteCard` 用 `ConstrainedBox(minHeight: columnHeight - headerHeight - cardMargin)`，内容超长时卡片自然撑高（在列内可垂直滚动浏览）。不强制 maxHeight，不截断。

---

### TD-04 吸顶列标题

**方案 A**：`SliverPersistentHeader(pinned: true)` ← 原生，无依赖  
**方案 B**：`Stack` + `Positioned` 手动计算偏移（复杂、fragile）  
**方案 C**：`sticky_headers` 第三方包（增加依赖）

**决策** ✅：方案 A。每列结构：

```dart
CustomScrollView(slivers: [
  SliverPersistentHeader(pinned: true, delegate: ColumnHeaderDelegate(...)),
  SliverPadding(sliver: SliverList(...)),
])
```

---

### TD-05 笔记列表位置稳定性（核心约束）

**问题**：编辑笔记后，笔记不能在列内移动。新笔记出现在"今天"列顶部。

**实现原则**：
- `_notes: List<Note>` 按**插入顺序**存储，新笔记 `insert(0, note)`（prepend）
- 展示某列笔记时，从 `_notes` 按 group 过滤，**保留原始列表顺序**（不重新排序）
- `updateNote` 只 `_notes[idx] = updated`，原地替换，不移动 index

**错误做法（禁止）**：在 getter 中按 `updatedAt` / `createdAt` 重新排序 `regularNotes`。

**决策** ✅：插入顺序 = 显示顺序，`update` 原地替换，`pinnedNotes` 单独按 `pinnedOrder` 排序。

---

### TD-06 置顶排序策略

**问题**：同一列多条笔记置顶时，谁在最上？

**方案 A**：置顶时记录时间戳，越晚置顶越靠上（"最后操作优先"）  
**方案 B**：置顶保持原始插入顺序（一旦置顶就固定）  
**方案 C**：用户可拖拽排序置顶笔记（复杂，后续优化）

**决策** ✅：方案 A。`pinnedOrder = DateTime.now().millisecondsSinceEpoch`，排序：`b.pinnedOrder.compareTo(a.pinnedOrder)`（越大越靠前）。直觉友好。

---

### TD-07 持久化写入策略

**方案 A**：每次变更立即同步写（阻塞 UI）❌  
**方案 B**：每次变更异步 fire-and-forget（并发写可能乱序）  
**方案 C**：防抖（800ms 无变更后写一次）✅

**决策** ✅：方案 C。`Timer` 防抖 800ms。Provider 每次 `notifyListeners()` 后调用 `_scheduleSave()`。app 退出前在 `WidgetsBindingObserver.didChangeAppLifecycleState` 强制立即写入。

---

### TD-08 时间分组算法

**今天 / 昨天**：直接比较本地日历日期 (`DateUtils.isSameDay`)  
**本周 / 上周**：计算 ISO 周数 (Monday-based)，用 `date.subtract(Duration(days: date.weekday - 1))` 得到该周 Monday  
**更早**：格式化为 `"2026 W06"`

```dart
// ISO 周计算（不依赖 intl，纯 Dart）
int isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final jan1 = DateTime(thursday.year, 1, 1);
  return ((thursday.difference(jan1).inDays) / 7).floor() + 1;
}
```

**跳跃逻辑**：`timeColumns` getter 只返回有笔记的分组，空组不创建列。

**决策** ✅：纯 Dart 手写，不引入 `intl` 的复杂 API（`intl` 仅用于时间显示格式化）。

---

### TD-09 笔记卡片 Hover 交互

**方案 A**：`MouseRegion` + `StatefulWidget._isHovered` bool + `AnimatedOpacity`  
**方案 B**：`InkWell` 自带 hover 状态（只改变墨水颜色，不能显示按钮）

**决策** ✅：方案 A。`NoteCard` 为 `StatefulWidget`，`MouseRegion` 驱动 `_isHovered`，操作按钮行（Pin / Edit / Delete）用 `AnimatedOpacity(opacity: _isHovered ? 1.0 : 0.0)` 淡入淡出。

---

### TD-10 新建 / 编辑笔记交互

**方案 A**：Modal 对话框（`showDialog`）  
**方案 B**：行内展开编辑（列内插入编辑区）  
**方案 C**：底部抽屉 (`showBottomSheet`)

**决策** ✅：方案 A，Modal 对话框。新建和编辑复用同一 `NoteEditorDialog`，区分 `isEditing` 参数。简洁、一致、易于实现。行内编辑作为后续优化项。

---

### TD-11 Draft ↔ Timeline 切换行为

当草稿切换为 Timeline：`createdAt` 不变 → 笔记进入其自然时间列（可能是"上周"）。  
当 Timeline 切换为草稿：笔记从时间列消失，进入草稿列。

**决策** ✅：仅更新 `isDraft` 字段，`createdAt` 永远不变。这是"物理记忆"原则的延伸。

---

### TD-12 "回到今天"快速导航

固定在 `Stack` 左下角 `Positioned(left: 24, bottom: 24)`，不随横向滚动移动。  
监听 `_horizontalController.offset > draftColumnWidth + columnGap`（即已滚过草稿列）时，用 `AnimatedOpacity` 显示按钮。  
点击：`_horizontalController.animateTo(0, duration: 300ms, curve: Curves.easeInOut)`。

---

### TD-13 内容显示方式

**决策** ✅：`SelectableText`（支持用户复制内容）。无最大高度限制，卡片随内容自然伸展。不做 title/body 分割，全文展示。

---

## 二、文件结构（最终确认）

```
lib/
├── main.dart
├── app.dart
├── features/
│   └── notes/
│       ├── models/
│       │   ├── note.dart
│       │   └── time_group.dart
│       ├── services/
│       │   └── notes_service.dart
│       ├── providers/
│       │   └── notes_provider.dart
│       └── widgets/
│           ├── timeline_kanban_view.dart
│           ├── draft_column.dart
│           ├── time_column.dart
│           ├── note_card.dart
│           ├── column_header.dart
│           ├── note_editor_dialog.dart
│           └── add_note_fab.dart
└── core/
    ├── constants/
    │   └── layout_constants.dart
    └── theme/
        └── app_theme.dart
```

---

## 三、分阶段实现 Todo

### Phase 1 — 基础层（Foundation）
> 目标：数据模型、持久化、状态管理可运行，无 UI。

- [ ] `pubspec.yaml`：添加 `provider`, `path_provider`, `intl`, `uuid`，执行 `flutter pub get`
- [ ] `core/constants/layout_constants.dart`：定义 `draftColumnWidth=600`, `timeColumnWidth=500`, `columnGap=20`, `pageHPad=24`, `pageVPad=16`
- [ ] `core/theme/app_theme.dart`：定义 `AppTheme.light()` 和 `AppTheme.dark()`，使用 `ColorScheme.fromSeed`，定义卡片/背景/文字颜色 token
- [ ] `features/notes/models/note.dart`：`Note` 数据类，`copyWith`，`toJson`，`fromJson`
- [ ] `features/notes/models/time_group.dart`：`TimeGroup` 枚举，`TimeGroupHelper.of(DateTime)`，`TimeGroupHelper.label(TimeGroup, DateTime)`，ISO 周计算函数
- [ ] `features/notes/services/notes_service.dart`：`loadNotes()` / `saveNotes()`，读写 `{appDocDir}/enotes/notes.json`
- [ ] `features/notes/providers/notes_provider.dart`：`NotesProvider`，含 `draftNotes` / `timeColumns` getter，`addNote` / `updateNote` / `togglePin` / `toggleDraft` / `deleteNote`，防抖 save
- [ ] `main.dart`：`await NotesService.init()` 加载数据，`runApp(App(initialNotes: ...))`
- [ ] `app.dart`：`MultiProvider` 注入 `NotesProvider`，`MaterialApp` 配置 `ThemeMode.system`

**验收**：能写入/读取 `notes.json`，Provider 状态变更正确，`flutter analyze` 无报错。

---

### Phase 2 — 布局骨架（Layout Skeleton）
> 目标：横向多列布局可见，各列独立纵向滚动可用。

- [ ] `widgets/timeline_kanban_view.dart`：`LayoutBuilder` 获取高度，`Listener`（Shift+Wheel），`Scrollbar` + `SingleChildScrollView(horizontal)`，`SizedBox(height)` + `Row`，`_horizontalController`
- [ ] `widgets/draft_column.dart`：占位骨架，固定宽度 600px，独立 `CustomScrollView`，`SliverPersistentHeader` 占位标题
- [ ] `widgets/time_column.dart`：占位骨架，固定宽度 500px，独立 `CustomScrollView`，`SliverPersistentHeader` 占位标题
- [ ] `widgets/column_header.dart`：实现 `SliverPersistentHeaderDelegate`，渲染列标题（label + 笔记数量），定义 `minExtent` / `maxExtent`

**验收**：多列横向可见，列内纵向滚动独立，不互相干扰，trackpad 横划流畅。

---

### Phase 3 — 笔记卡片（Note Card）
> 目标：卡片正确渲染内容，Hover 交互可用。

- [ ] `widgets/note_card.dart`：用 `CodeEditor`（re_editor）替换 `SelectableText`，`langMarkdown` 高亮，`FocusNode` 检测编辑状态，防抖自动保存，`Cmd+S` 显式保存，禁用内部垂直滚动，开启 word wrap
- [ ] 置顶标识：`isPinned == true` 时显示角标或图钉图标
- [ ] 草稿卡片变体：`ConstrainedBox(minHeight: columnBodyHeight)`，视觉样式区分（边框颜色或背景色）

**验收**：卡片内容完整展示不截断，Hover 平滑淡入按钮，置顶可识别。

---

### Phase 4 — 列渲染（Column Implementation）
> 目标：草稿列和时间列从 Provider 读取真实数据并渲染。

- [ ] `draft_column.dart`：接入 `Consumer<NotesProvider>`，渲染 `draftNotes`，卡片间距 12px
- [ ] `draft_column.dart`：列为空时显示空状态（占位文案 + 淡色提示图标）
- [ ] `time_column.dart`：接入 `TimeColumnData`，先渲染 `pinnedNotes`（含分隔线），再渲染 `regularNotes`
- [ ] `timeline_kanban_view.dart`：接入 `Consumer<NotesProvider>`，动态生成列列表，空时间段跳过不显示

**验收**：用假数据能正确分组显示，今天列在最左，更早的列依次向右。

---

### Phase 5 — 交互（Interactions）
> 目标：新建、编辑、删除、置顶、Draft 切换全部可用。

- [ ] 新建笔记：FAB → `provider.addNote` 插入空笔记 → `GlobalKey` 定位到卡片 → `FocusNode.requestFocus()` 自动聚焦，无需对话框
- [ ] `note_card.dart`：Delete 按钮 → `showDialog(ConfirmDeleteDialog)` → `provider.deleteNote(id)`
- [ ] `note_card.dart`：Pin 按钮 → `provider.togglePin(id)`
- [ ] `note_card.dart`：Draft 切换 → `provider.toggleDraft(id)`（放在 hover 操作栏）
- [ ] **`NoteEditorDialog` 废弃**，删除或仅保留历史归档

**验收**：完整 CRUD 流程可用，新笔记出现在 Today 列顶部，编辑后位置不变。

---

### Phase 6 — 持久化验证（Persistence）
> 目标：重启应用后数据完整恢复。

- [ ] 验证 `notes.json` 文件正确创建于 `appDocumentsDirectory`
- [ ] 验证 `createdAt` / `updatedAt` UTC 存储、本地显示
- [ ] 验证防抖：快速连续编辑只触发一次写入
- [ ] `WidgetsBindingObserver`：`didChangeAppLifecycleState(inactive)` → 强制立即 save（取消 Timer，立即写）
- [ ] 错误处理：文件损坏时 catch JSON 解析异常，降级为空列表 + `log()` 报错

**验收**：kill app 重启，所有笔记和置顶状态完整恢复。

---

### Phase 7 — 滚动与导航打磨（Scroll Polish）
> 目标：滚动体验流畅，导航便捷。

- [ ] Shift+Wheel 横向滚动：`Listener.onPointerSignal` 转发 `dy` → `_horizontalController`
- [ ] "回到今天"按钮：`_horizontalController` 监听器 → 偏移超过草稿列宽度时 `AnimatedOpacity` 显示，点击 `animateTo(0)`
- [ ] 列内滚动独立验证：在 A 列滚到底部，B 列位置不受影响
- [ ] `ScrollbarTheme`：自定义横向滚动条粗细和颜色，与主题一致

**验收**：trackpad / 鼠标滚轮行为符合预期，回今天按钮出现/消失时机正确。

---

### Phase 8 — 视觉打磨（Visual Polish）
> 目标：达到"Wow" factor，不是默认蓝色 Material 风格。

- [ ] `app_theme.dart`：完善 Light / Dark 两套主题，卡片背景、边框、投影精心设计
- [ ] 卡片设计：`BoxDecoration` 含圆角 `12px`，Light 模式轻投影，Dark 模式微发光边框
- [ ] 列标题样式：大号字重，颜色与背景形成层次
- [ ] 时间戳：小字、低对比度，不抢主内容视觉权重
- [ ] 笔记数量 badge：列标题旁显示当前列笔记数
- [ ] 空状态：无笔记时草稿列 / 时间列显示精美占位（引导文案 + 轻描插图或 icon）
- [ ] 过渡动画：新笔记插入时 `AnimatedList` 或简单 `AnimatedOpacity` 入场

**验收**：视觉符合 Material 3 premium 风格，深浅模式均美观。

---

## 四、已知风险 & 应对

| 风险 | 可能性 | 应对 |
|------|--------|------|
| `LayoutBuilder` 嵌套导致 height unbounded 报错 | 中 | 在 `TimelineKanbanView` 最外层用 `LayoutBuilder`，向内传递 `availableHeight`，不依赖 `Expanded` |
| 列数多时横向 `Row` 内存占用 | 低 | 笔记数量有限；如列超过 20 则改用 `ListView(scrollDirection: horizontal)` + `itemBuilder` |
| macOS 与 Web 的滚动事件差异 | 中 | 优先保证 macOS，Web 降级为原生滚动条 |
| JSON 文件并发写（多窗口）| 低 | 单窗口 app，暂不处理；后续可加文件锁 |
| `SliverPersistentHeaderDelegate` 高度抖动 | 低 | `minExtent == maxExtent`，禁用收缩效果 |

---

## 五、依赖清单（最终）

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2        # 状态管理
  path_provider: ^2.1.5   # 获取文档目录
  intl: ^0.20.2           # 时间格式化显示
  uuid: ^4.5.1            # Note ID 生成
  re_editor: ^0.8.0       # Inline CodeEditor + Markdown 高亮 + Cmd+S
```

**无代码生成，无 build_runner，`flutter pub get` 即可开始。**
