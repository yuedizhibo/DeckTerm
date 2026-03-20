# workflow.dart

> 路径：`lib/ui/main/workflow.dart`

## 职责

主工作台页面。整体布局容器，包含自定义标题栏（Windows 窗口控制）、可调整大小的面板区域和 Stack 层管理的浮动面板系统，是应用的核心操作界面。

## 核心内容

### `WorkflowPage` (StatefulWidget, WindowListener)

### 布局结构

```
Scaffold
├── 自定义标题栏（DragToMoveArea 包裹，Windows 可拖拽）
│   ├── Logo + "DeckTerm" 标题
│   ├── 工具栏按钮（锁定/传输/连接/设置）
│   └── 窗口控制（最小化/最大化/关闭，仅 Windows）
└── Stack
    ├── 主内容区（最小 800x600，双向滚动）
    │   └── ResizableWidget (水平)
    │       ├── ResizableWidget (垂直-左侧)
    │       │   ├── DeviceStatus (设备监控卡片)
    │       │   └── FileTree (本地文件树，按平台选择)
    │       └── ResizableWidget (垂直-右侧)
    │           ├── TerminalTabs (终端标签页)
    │           └── RemoteFileManager (远程文件管理器)
    └── 浮动面板层（FloatingPanel × N，z 序由 _panelOrder 管理）
```

### 标题栏

- Windows 平台使用 `DragToMoveArea` 包裹，实现原生拖拽移动窗口。
- Logo 区域通过 `IgnorePointer` 穿透手势给拖拽区域。
- 窗口控制按钮（`_WindowControlBtn`）：最小化、最大化/还原、关闭。
- 监听 `WindowListener` 的 `onWindowMaximize/onWindowUnmaximize` 更新图标状态。

### 工具栏按钮

| 按钮 | 图标 | 功能 |
|------|------|------|
| 锁定布局 | lock/lock_open | 切换面板拖拽锁定状态 |
| 传输列表 | swap_vert | 打开/关闭 TransferListPanel 浮动面板，活跃任务数红色角标 |
| 连接管理 | dns_outlined | 打开/关闭 ConnectionManagerPanel 浮动面板 |
| 设置 | settings_outlined | 打开/关闭 SettingsPanel 浮动面板 |

### 浮动面板系统

- **Windows**：使用 `FloatingPanel` 非模态浮动卡片，在 Stack 中叠加显示。
  - `_openPanels`（Set）跟踪已打开面板。
  - `_panelOrder`（List）管理 z 序，点击面板自动提升到最前。
  - 各按钮 `GlobalKey` 计算动画起点矩形（`_btnRect()`）。
- **Android**：使用 `showPanelDialog()` 模态 Dialog 替代浮动面板。

### 布局持久化

- 使用 `shared_preferences` 保存和恢复三个分割面板的像素尺寸及锁定状态。
- 键名：`layout_horizontal_size`、`layout_left_vertical_size`、`layout_right_vertical_size`、`layout_locked`。

### 会话管理

| 方法 | 说明 |
|------|------|
| `_addSession()` | 打开连接管理面板（Windows 浮动 / Android Dialog） |
| `_connectSession(session)` | 添加会话到列表，首个会话自动设为当前 |
| `_removeSession(sessionId)` | 移除会话，当前会话被删除时切换到最后一个 |
| `_onSessionSwitch(session)` | 切换当前活跃会话 |

### 平台文件树选择

`_buildFileTree()` 通过 `Platform.isWindows / Platform.isAndroid` 选择对应平台文件树组件，其他平台显示"当前平台不支持文件树"占位（`_PlaceholderFileTree`）。

### 设备监控

- `DeviceMonitor().statusStream` 监听，`setState` 更新 `_deviceStatuses`。

### 内部组件

| 组件 | 说明 |
|------|------|
| `_PanelDef` | 面板定义数据类（标题、尺寸、按钮Key、内容Widget） |
| `_ToolbarBtn` | 工具栏图标按钮（hover 效果、active 高亮、可选 badge） |
| `_WindowControlBtn` | 窗口控制按钮（最小化/最大化/关闭，关闭按钮 hover 红色） |
| `_PlaceholderFileTree` | 不支持平台的文件树占位组件 |

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `window_manager` | Windows 窗口控制（拖拽、最小化/最大化/关闭） |
| `DeviceMonitor` | 设备状态流 |
| `TransferManager` | 传输任务角标 |
| `SharedPreferences` | 布局持久化 |
| `ResizableWidget` | 面板分割 |
| `TerminalTabs` | 终端标签 |
| `DeviceStatus` | 设备监控卡片 |
| `RemoteFileManager` | 远程文件 |
| `FileTreeAndroid` / `FileTreeWindows` | 本地文件树 |
| `FloatingPanel` | 浮动面板容器 |
| `ConnectionManagerPanel` | 连接管理面板内容 |
| `TransferListPanel` | 传输列表面板内容 |
| `SettingsPanel` | 设置面板内容 |
