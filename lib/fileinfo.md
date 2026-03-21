# DeckTerm 项目文件结构说明

本文档详细说明 `lib` 目录下各个文件的职责与功能。

> **维护规则**：每次新增、删除或修改文件后，必须同步更新本文档。同时更新 `docs/` 目录下对应的详细文档。

---

## 文件总览

| 层级 | 文件数 | 说明 |
|------|--------|------|
| 入口 | 1 | `main.dart` |
| 功能层 (function/) | 10 | 纯业务逻辑，无 UI（含 VNC） |
| 设置层 (setting/) | 2 | 主题系统 + 设置管理 |
| UI 层 (ui/) | 21 | 界面展示（含 VNC 桌面视图） |
| **合计** | **34** | |

## 详细文档索引

每个文件在 `docs/` 目录下有对应的详细 md 文档（包含 API 说明、依赖关系、实现细节等），见下方各条目中的 `详细文档` 链接。

---

## 根目录

- **`main.dart`** — 应用程序入口文件。 [`详细文档`](../docs/main.md)
  - 初始化 Flutter 应用、配置 Material 3 暗色主题（TDesign 扩展）和 PopupMenu 样式。
  - 设置 `kTextForceVerticalCenterEnable = false` 修复 Flutter 3.16+ TDesign 字体偏移问题。
  - Windows 平台：通过 `window_manager` 初始化自定义无标题栏窗口（1280×720，最小 800×600）。
  - 包含 `PermissionCheckWrapper`：Android 平台启动时请求存储权限（`manageExternalStorage` 优先，降级到 `storage`），非 Android 平台直接跳过权限检查进入主界面。

---

## Setting (设置层)

- **`app_theme.dart`** — 统一主题系统。 [`详细文档`](../docs/setting/app_theme.md)
  - `AppColors`：`ThemeExtension`，定义 20+ 语义色彩 Token（scaffold、titleBar、accent、text1/2/3 等），深色/浅色两套预设。
  - `ThemeProvider`：全局主题状态单例（`ChangeNotifier`），持久化到 `SharedPreferences`，支持深色/浅色切换。
  - `buildAppTheme()`：根据 `Brightness` 生成完整 `ThemeData`。
  - 所有 UI 组件通过 `AppColors.of(context)` 获取当前主题色，消除硬编码色值。

- **`settings_manager.dart`** — 全局设置管理器。 [`详细文档`](../docs/setting/settings_manager.md)
  - `SettingsManager`：ChangeNotifier 单例，持久化到 `SharedPreferences`。
  - 管理终端字号、光标闪烁、回滚行数、KeepAlive 间隔、断线自动重连等设置。
  - 所有 setter 方法自动通知监听者并异步持久化。

---

## Function (核心功能层)

存放非 UI 的业务逻辑、数据管理和底层服务。

### `lib/function/android/` — Android 专用功能

- **`storage.dart`** — Android 平台文件存储服务。 [`详细文档`](../docs/function/android/storage.md)
  - `getRootDirectories()`：获取主存储根目录（`/storage/emulated/0`）。
  - `getDirectoryContent(path)`：获取目录内容，排序（文件夹在前）。
  - `getQuickAccessPaths()`：返回快速访问路径映射（`{'下载': '/storage/emulated/0/Download'}`）。
  - `getName(path)`：提取路径末尾的文件/目录名。

### `lib/function/windows/` — Windows 专用功能

- **`storage.dart`** — Windows 平台文件存储服务。 [`详细文档`](../docs/function/windows/storage.md)
  - `getDrives()`：遍历 A-Z 检测存在的磁盘驱动器。
  - `getDirectoryContent(path)`：获取目录内容，排序（文件夹在前）。
  - `getQuickAccessPaths()`：依赖 `USERPROFILE` 环境变量，返回快速访问路径映射（`{'桌面': ...\Desktop, '下载': ...\Downloads}`）。

### `lib/function/clipboard/` — 跨平台文件剪贴板

- **`clipboard_manager.dart`** — 文件剪贴板管理器（单例，`ChangeNotifier`）。 [`详细文档`](../docs/function/clipboard/clipboard_manager.md)
  - 管理跨平台（本地 Android/Windows ↔ 远程 SFTP）的文件复制、剪切状态。
  - 维护 `FileClipboardItem`（路径、来源类型、操作类型、名称、是否目录、SFTP实例）。
  - `paste()` 分发四种粘贴场景：本地→本地、本地→远程（上传）、远程→本地（下载）、远程→远程（重命名或复制）。
  - 通过 `TransferManager` 跟踪上传/下载进度；剪切操作完成后自动清空剪贴板。
  - 目录上传/下载暂未实现（抛出 `Exception`）。

### `lib/function/connect/` — 连接管理

- **`connection_manager.dart`** — 连接管理器（单例）。 [`详细文档`](../docs/function/connect/connection_manager.md)
  - 负责通过 `shared_preferences` 持久化存储、读取、添加、删除和更新用户的连接配置。

- **`connection_model.dart`** — 连接配置数据模型。 [`详细文档`](../docs/function/connect/connection_model.md)
  - 定义 `Connection`（主机、端口、用户名、密码、私钥路径、类型 SSH/VNC、认证方式）及 JSON 序列化/反序列化逻辑，包含 `copyWith` 方法。

### `lib/function/dev-file/` — 远程文件操作

- **`sftp_manager.dart`** — SFTP 管理器。 [`详细文档`](../docs/function/dev-file/sftp_manager.md)
  - 封装 `dartssh2` 的 SFTP 功能，管理独立的 SSH+SFTP 连接。
  - `listDirectory(path, {useCache})`：获取目录列表（带内存缓存，排序目录在前）。
  - `createDirectory(path)`：创建远程目录。
  - `delete(path, {isDirectory})`：删除远程文件或目录。
  - `uploadFile(remotePath, stream, {onProgress})`：流式上传，**手动追踪 `writeOffset`** 确保每个 chunk 写入正确偏移。
  - `downloadFile(remotePath, sink, {onProgress})`：流式下载。
  - `rename(oldPath, newPath)`：移动/重命名远程文件。
  - `copyRemote(src, dst, isDir)`：远程复制（暂未实现，抛出 `UnimplementedError`）。

### `lib/function/monitor/` — 设备监控

- **`device_monitor.dart`** — 设备状态监控器（单例）。 [`详细文档`](../docs/function/monitor/device_monitor.md)
  - 为每个主机维护独立的监控 SSH 连接（与终端会话连接分离）。
  - 引用计数（`Map<host, Set<sessionId>>`）：第一个会话接入时建立连接并启动 5 秒轮询，最后一个会话断开时自动清理。
  - 通过 `_reconnecting` / `_retryingPoll` Set 防止并发重连/重试积累。
  - 连接失败或命令失败后 1 秒自动重试，轮询命令读取 `/proc/stat`（CPU）和 `free`（内存）。
  - 通过 `Stream<Map<String, DeviceInfo>>` 广播状态更新。

### `lib/function/ssh/` — SSH 服务

- **`ssh_manager.dart`** — SSH 会话管理器。 [`详细文档`](../docs/function/ssh/ssh_manager.md)
  - 包含 `_TcpNoDelaySocket`：实现 `SSHSocket` 接口，设置 `TCP_NODELAY=true` 禁用 Nagle 算法，消除 ~500ms 交互延迟。
  - 封装 `dartssh2`，负责建立 SSH 连接、认证（密码），管理 Shell 会话。
  - PTY 指定 `type: 'xterm-256color'`。
  - `Utf8Decoder(allowMalformed: true)` 防止 UTF-8 序列截断异常。
  - `StreamController.broadcast(sync: true)` 同步派发输出。
  - 提供 `write(data)`、`resize(width, height)` 方法，`dispose()` 清理连接。

### `lib/function/transfer/` — 传输管理

- **`transfer_manager.dart`** — 文件传输管理器（单例，`ChangeNotifier`）。 [`详细文档`](../docs/function/transfer/transfer_manager.md)
  - 统一管理文件上传/下载任务队列（`TransferTask` 列表）。
  - `addTask()`：新增任务，状态为 `pending`。
  - `updateProgress()`：更新已传输字节数，状态变为 `running`。
  - `completeTask()`：标记完成，8 秒后自动从列表移除。
  - `failTask()`：标记失败并记录错误信息。
  - `removeTask(taskId)`：手动移除单条任务。
  - `clearCompleted()`：批量移除所有已完成或失败的任务。

### `lib/function/vnc/` — VNC 远程桌面

- **`vnc_manager.dart`** — VNC 连接管理器。 [`详细文档`](../docs/function/vnc/vnc_manager.md)
  - 实现 RFB 3.8 协议最小子集：版本握手、安全协商、VNC 认证（DES challenge-response）、帧缓冲更新。
  - 支持 Raw 和 CopyRect 编码，32bpp BGRA 像素格式。
  - `connect()`：完成 RFB 握手、认证、ServerInit，分配帧缓冲。
  - `sendKeyEvent(keysym, down)`：发送键盘事件。
  - `sendPointerEvent(x, y, buttonMask)`：发送鼠标/触摸事件。
  - `requestFrameUpdate({incremental})`：请求帧缓冲增量/完整更新。
  - 通过 `statusStream` 和 `frameStream` 广播状态变化和帧更新。
  - 内含最小 DES 实现（VNC Authentication 专用）。

---

## UI (界面展示层)

存放 Flutter Widget 和页面布局。

### `lib/ui/android/` — Android 专用 UI

- **`file_tree_android.dart`** — Android 平台的本地文件树实现。 [`详细文档`](../docs/ui/android/file_tree_android.md)
  - 展示本地存储目录树，支持懒加载，提供文件类型图标和大小格式化显示。
  - 隐藏以 `.` 开头的隐藏文件/目录。
  - 顶部显示**快速访问区**（由 `AndroidStorage.getQuickAccessPaths()` 提供路径）。
  - 集成 `ContextMenuTrigger`（右键/长按菜单）、`SelectionManager`（选中高亮）、`ClipboardManager`（复制/剪切/粘贴）。

- **`ssh_keyboard_overlay.dart`** — Android 平台 SSH 终端软键盘输入层。 [`详细文档`](../docs/ui/android/ssh_keyboard_overlay.md)
  - 右下角浮动键盘按钮（FAB），点击弹出/收起系统软键盘。
  - 通过偏移至屏幕外（left: -9999）的隐藏 TextField 接收 IME 输入，经 delta 追踪转发给 xterm Terminal。
  - 哨兵缓冲区（10个空格）确保连续退格可被检测。
  - `heroTag` 含 sessionId，避免多标签页间 Hero 动画冲突。

### `lib/ui/windows/` — Windows 专用 UI

- **`file_tree_windows.dart`** — Windows 平台的本地文件树实现。 [`详细文档`](../docs/ui/windows/file_tree_windows.md)
  - 顶部显示**快速访问区**（桌面/下载）+ **驱动器列表**（A-Z 驱动器）。
  - `_DirectoryNode` 支持 `customIcon`/`customIconColor` 参数，懒加载子目录。
  - `_FileNode` 提供文件类型图标映射，支持复制/剪切/打开/属性上下文菜单（打开/属性为占位）。
  - 集成 `ContextMenuTrigger`、`SelectionManager`、`ClipboardManager`。

### `lib/ui/common/` — 跨平台通用组件

- **`context_menu_trigger.dart`** — 上下文菜单触发器。 [`详细文档`](../docs/ui/common/context_menu_trigger.md)
  - 统一处理鼠标右键点击和触摸长按，提供一致的右键菜单体验。

- **`floating_panel.dart`** — 通用可拖拽毛玻璃浮动面板 + Android 兼容 `showPanelDialog`。 [`详细文档`](../docs/ui/common/floating_panel.md)
  - Windows：非模态浮动卡片，从按钮位置飞出到屏幕中央的动画（`originRect`），可拖拽移动。
  - Android：`showPanelDialog()` 函数用半透明 Dialog 包装，缩放 + 淡入动画。
  - 半透明毛玻璃效果（`BackdropFilter`）、圆角阴影。
  - 被 `workflow.dart` 中的 Stack 层管理 z 序和可见性。

- **`selection_manager.dart`** — 文件选择状态管理器（单例，`ChangeNotifier`）。 [`详细文档`](../docs/ui/common/selection_manager.md)
  - 管理文件树中的单选高亮状态，区分选中项来源（`local`/`remote`）。

- **`settings_panel.dart`** — 设置面板内容（非模态，嵌入 FloatingPanel / showPanelDialog 使用）。 [`详细文档`](../docs/ui/common/settings_panel.md)
  - 终端设置：字号滑块、光标闪烁开关、回滚行数。
  - 连接设置：KeepAlive 秒数、断线自动重连。
  - 关于：版本信息。
  - 后续接入 `SettingsManager` 持久化。

- **`transfer_list_dialog.dart`** — 传输列表面板（非模态，嵌入 FloatingPanel / showPanelDialog 使用）。 [`详细文档`](../docs/ui/common/transfer_list_dialog.md)
  - 提供全部/上传/下载三个 Tab 过滤视图。
  - 每条任务显示完整信息：图标、文件名、路径、进度条、大小。
  - 支持单条关闭和批量"清空已完成/失败"操作。

- **`transfer_progress_widget.dart`** — 文件传输进度条组件（**备用，当前未使用**）。 [`详细文档`](../docs/ui/common/transfer_progress_widget.md)
  - 轻量内嵌版进度条，已被 `transfer_list_dialog.dart` 替代。

### `lib/ui/connect/` — 连接管理界面

- **`connection_manager_dialog.dart`** — 连接管理面板（非模态，嵌入 FloatingPanel / showPanelDialog 使用）。 [`详细文档`](../docs/ui/connect/connection_manager_dialog.md)
  - 展示已保存的连接列表，搜索/过滤，新建/编辑/删除连接。
  - **搜索/过滤**：按"完全匹配 → 包含关键字 → 其余"三级排序，支持名称和 IP 搜索。
  - 处理新建、编辑、删除、右键菜单和发起连接的交互逻辑。
  - 创建会话时生成唯一 Runtime ID（`时间戳_connectionId`），通过 `onConnect` 回调返回。

- **`connection_form.dart`** — 连接编辑表单。 [`详细文档`](../docs/ui/connect/connection_form.md)
  - 提供名称、主机、端口、备注、认证方式（密码/私钥）输入框。
  - 使用 TDesign 组件构建，`onSave` 回调返回 `Connection` 对象。

### `lib/ui/main/` — 主工作台界面

应用程序的核心操作界面。

- **`workflow.dart`** — 主工作台页面。 [`详细文档`](../docs/ui/main/workflow.md)
  - 整体布局容器，包含自定义标题栏（Windows 窗口控制）、可调整大小的面板区域（三个 `ResizableWidget` 嵌套）和 Stack 层浮动面板系统。
  - **自定义标题栏**：Windows 使用 `DragToMoveArea` 零延迟拖拽，自绘最小化/最大化/关闭按钮。
  - **浮动面板系统**：Windows 上多面板叠加（z 序管理），Android 上使用 `showPanelDialog()` 模态 Dialog。
  - **布局持久化**：使用 `shared_preferences` 保存和恢复面板像素尺寸及锁定状态。
  - 工具栏：锁定布局、传输列表（带活跃任务数角标）、连接管理、设置。
  - `_buildFileTree()`：通过 `Platform.isWindows / Platform.isAndroid` 选择对应平台文件树组件。

#### `lib/ui/main/models/` — UI 数据模型

- **`terminal_session.dart`** — 终端会话运行时模型。 [`详细文档`](../docs/ui/main/models/terminal_session.md)
  - 表示一个正在进行的连接（id、name、type、host、port、username、password、privateKeyPath、isConnected）。
  - 包含 JSON 序列化/反序列化方法。

- **`device_info.dart`** — 设备状态数据模型。 [`详细文档`](../docs/ui/main/models/device_info.md)
  - 定义 `DeviceInfo`（IP、name、cpuUsage、memoryUsage、status）和 `DeviceStatusType` 枚举。
  - 提供 `cpuUsagePercent`、`memoryUsagePercent` 格式化属性。

#### `lib/ui/main/ssh/` — SSH 终端视图

- **`ssh_terminal_view.dart`** — SSH 终端模拟器视图（平台无关的核心逻辑）。 [`详细文档`](../docs/ui/main/ssh/ssh_terminal_view.md)
  - 基于 `xterm` 包实现完整终端渲染。
  - **物理键盘**：`hardwareKeyboardOnly: true` 跳过 IME，支持 Ctrl+A~Z、F1~F12、方向键等。
  - **光标闪烁**：聚焦时白/灰 530ms 交替，失焦时灰色描边。
  - **Android 软键盘**：通过 `if (Platform.isAndroid)` 挂载 `SshKeyboardOverlay`。
  - `AutomaticKeepAliveClientMixin`：标签页切换时保持终端后台活跃。
  - 集成 `SettingsManager`：字号、光标闪烁、回滚行数实时响应设置变更。

#### `lib/ui/main/vnc/` — VNC 桌面视图

- **`vnc_desktop_view.dart`** — VNC 远程桌面渲染视图。 [`详细文档`](../docs/ui/main/vnc/vnc_desktop_view.md)
  - 基于 `VncManager` 实现完整 VNC 桌面显示，使用 `CustomPainter` + `ui.Image` 渲染帧缓冲。
  - 键盘输入：物理键盘 → X11 keysym 映射 → VNC `sendKeyEvent`。
  - 鼠标/触摸：`Listener` 处理点击/移动/滚轮，Android 长按模拟右键。
  - 等比缩放居中显示，连接状态 UI（连接中/失败/重试）。
  - `AutomaticKeepAliveClientMixin` 保持标签页切换时后台活跃。

#### `lib/ui/main/widgets/` — 主界面组件

- **`device_status.dart`** — 设备状态监控卡片。 [`详细文档`](../docs/ui/main/widgets/device_status.md)
  - 位于左上角，TabBar/TabBarView 展示多设备实时 CPU/内存状态。
  - 进度条 `strokeWidth: 20`（加粗），颜色随使用率变化（绿/黄/红）。

- **`file_tree.dart`** — 本地文件树基础抽象与共享组件。 [`详细文档`](../docs/ui/main/widgets/file_tree.md)
  - `FileNode`：文件节点数据模型。
  - `QuickAccessEntry`：快速访问入口数据模型，供两平台共用。
  - `QuickAccessSectionHeader`：快速访问分区标题组件。
  - `FileTreeBase` / `FileTreeBaseState`：抽象基类（当前两平台均未继承，保留备用）。

- **`remote_file_manager.dart`** — 远程文件管理器（SFTP 树状结构）。 [`详细文档`](../docs/ui/main/widgets/remote_file_manager.md)
  - 展示远程服务器文件列表，支持目录懒加载，根节点默认展开。
  - 集成 `SftpManager`、`ClipboardManager`，支持创建目录、删除、复制、剪切、粘贴。

- **`resizable_widget.dart`** — 可调整大小的分割面板组件。 [`详细文档`](../docs/ui/main/widgets/resizable_widget.md)
  - 严格要求恰好 2 个子组件。
  - 支持水平和垂直方向的拖拽调整。
  - 第一个子组件固定像素尺寸，第二个 `Expanded` 占据剩余空间。
  - `isResizable: false` 时禁用拖拽（锁定布局）。

- **`terminal_tabs.dart`** — 终端标签页栏。 [`详细文档`](../docs/ui/main/widgets/terminal_tabs.md)
  - 管理多 SSH/VNC 会话标签页切换，含关闭按钮和右键菜单（关闭、关闭其他）。
  - `IndexedStack` + `GlobalKey` 缓存，确保 Tab 切换时 Shell 连接不断开。
  - 包含 `VncDesktopView`（占位实现，VNC 功能待实现）。
