# eNotes UI Visual Spec

目标：在**不改变 Timeline Kanban 布局**的前提下，统一桌面端视觉语言，提升 light / dark 双主题的一致性与质感。

## 1. 设计原则

1. **布局不动，视觉升级**：不调整列宽、信息结构、主交互路径。
2. **桌面优先**：强调 hover、focus、轻阴影、清晰分层。
3. **语义化 token**：颜色和状态统一走主题，不在组件里散落硬编码。
4. **克制而稳定**：弱化夸张 Material 感，保持编辑器型工具的安静气质。

## 2. Surface 层级

从外到内：

1. `scaffoldBackgroundColor`：应用画布
2. `NoteColors.columnSurface`：时间列 / 回收站列面板
3. `NoteColors.columnHeader`：吸顶列头
4. `cardTheme.color` / `draftCardBackground`：笔记卡片与草稿区内容面
5. `controlSurface`：搜索框、悬浮按钮、顶部工具按钮

规则：

- 面板通过 **边框 + 轻阴影** 区分，不依赖厚重背景色差。
- 卡片默认弱阴影，hover / focus 再提升。
- Popover 阴影强于卡片，但仍保持柔和。

## 3. 颜色 token

`NoteColors` 当前包含：

- Card: `cardBorder` / `cardBorderHover` / `cardBorderFocused`
- Column: `columnHeader` / `columnSurface` / `columnBorder`
- Draft: `draftCardBackground`
- Badge: `badgeBackground` / `badgeForeground`
- Interaction: `hoverTint` / `controlSurface` / `controlSurfaceHover`
- Editor: `editorText` / `editorHint` / `editorCursor`
- Search: `searchBarFill` / `searchBarBorder`
- Overlay: `popoverShadow`
- Destructive: `destructive` / `destructiveSoft`

## 4. 圆角规范

- 8–10：小型标签、tab、紧凑操作
- 12：工具按钮、搜索框容器
- 14：卡片、菜单、对话框
- 18：列面板
- 999：badge / pill / 圆角操作胶囊

## 5. 阴影规范

- 卡片静止：弱阴影
- 卡片 hover：中等阴影
- 卡片 focus：中等阴影 + accent ring
- 面板：比卡片更弱，但覆盖更大
- Popover：最大 blur 与更深阴影

## 6. 文字层级

- 列标题：15 / 600
- 正文：14 / 1.62
- 次级正文：13 / 1.55
- 元信息：11 / 500
- 小操作 / badge：12 / 600

## 7. 组件约束

### Column Header
- 必须有底部分隔线
- 标题与 badge 垂直居中
- Trash header 使用 destructive icon，但正文仍走正常标题色

### Note Card
- 保持 inline editing，不新增模态
- hover 和 focus 使用统一边框提升逻辑
- info 按钮作为次级控制，仅在 hover / focus 可见

### Search Bar
- 使用 pill 形态
- hover / focus 提升 surface
- focus 边框使用主色，默认边框走 `searchBarBorder`

### Popover / Menus
- 与卡片共享圆角体系
- 用 `popoverShadow`
- destructive row 统一使用 `destructive` / `destructiveSoft`

## 8. 后续扩展

未来新增 tags / tasks / inspector 时，沿用相同规则：

- 新 surface 优先复用已有 token
- 新状态先抽象语义，再落到组件
- 不把 feature-specific 颜色直接写进 widget
