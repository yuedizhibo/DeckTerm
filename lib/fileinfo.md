# DeckTerm 项目文件结构说明

本文档详细说明 `lib` 目录下各个文件的职责与功能。

## 根目录
- **`main.dart`**: 应用程序入口文件。
  - 初始化 Flutter 应用、配置 Material 主题（TDesign 扩展）和 PopupMenu 样式。
  - 设置 `kTextForceVerticalCenterEnable = false` 修复 Flutter 3.16+ TDesign 字体偏移问题。
  - 包含 `PermissionCheckWrapper`：Android 平台启动时请求存储权限（`manageExternalStorage` 优先，降级到 `storage`），非 Android 平台直接跳过权限检查进入主界面。

## Function (核心功能层)
存放非 UI 的业务逻辑、数据管理和底层服务。

### `lib/function/android/` (Android 功能)
- **`storage.dart`**: Android 平台文件存储服务（仅 Android 使用）。
  - `getRootDirectories()`：获取主存储根目录（`/storage/emulated/0`）。
  - `getDirectoryContent(path)`：获取目录内容，排序（文件夹在前）。
  - `getQuickAccessPaths()`：返回快速访问路径映射（`{'下载': '/storage/emulated/0/Download'}`）。
  - `getName(path)`：提取路径末尾的文件/目录名。

### `lib/function/clipboard/` (剪贴板功能)
- **`clipboard_manager.dart`**: 文件剪贴板管理器（单例，`ChangeNotifier`）。
  - 管理跨平台（本地 Android/Windows ↔ 远程 SFTP）的文件复制、剪切状态。
  - 维护 `FileClipboardItem`（路径、来源类型、操作类型、名称、是否目录、SFTP实例）。
  - `paste()` 分发四种粘贴场景：本地→本地、本地→远程（上传）、远程→本地（下载）、远程→远程（重命名或复制）。
  - 通过 `TransferManager` 跟踪上传/下载进度；剪切操作完成后自动清空剪贴板。
  - 目录上传/下载暂未实现（抛出 `UnimplementedError`）。

### `lib/function/connect/` (连接管理)
- **`connection_manager.dart`**: 连接管理器（单例）。负责通过 `shared_preferences` 持久化存储、读取、添加、删除和更新用户的连接配置。
- **`connection_model.dart`**: 连接配置数据模型。定义 `Connection`（主机、端口、用户名、密码、私钥路径、类型 SSH/VNC、认证方式）及 JSON 序列化/反序列化逻辑，包含 `copyWith` 方法。

### `lib/function/dev-file/` (远程文件)
- **`sftp_manager.dart`**: SFTP 管理器。
  - 封装 `dartssh2` 的 SFTP 功能，管理独立的 SSH+SFTP 连接。
  - `listDirectory(path, {useCache})`：获取目录列表（带内存缓存，排序目录在前）。
  - `createDirectory(path)`：创建远程目录。
  - `delete(path, {isDirectory})`：删除远程文件或目录。
  - `uploadFile(remotePath, stream, {onProgress})`：流式上传，**手动追踪 `writeOffset`** 确保每个 chunk 写入正确偏移（dartssh2 `writeBytes` 默认 offset=0，不追踪会导致文件内容丢失）。
  - `downloadFile(remotePath, sink, {onProgress})`：流式下载。
  - `rename(oldPath, newPath)`：移动/重命名远程文件。
  - `copyRemote(src, dst, isDir)`：远程复制（暂未实现，抛出 `UnimplementedError`）。

### `lib/function/monitor/` (设备监控)
- **`device_monitor.dart`**: 设备状态监控器（单例）。
  - 为每个主机维护独立的监控 SSH 连接（与终端会话连接分离）。
  - 引用计数（`Map<host, Set<sessionId>>`）：第一个会话接入时建立连接并启动 5 秒轮询，最后一个会话断开时自动清理。
  - 通过 `_reconnecting` / `_retryingPoll` Set 防止并发重连/重试积累。
  - 连接失败或命令失败后 1 秒自动重试，轮询命令读取 `/proc/stat`（CPU）和 `free`（内存）。
  - 通过 `Stream<Map<String, DeviceInfo>>` 广播状态更新。

### `lib/function/ssh/` (SSH 服务)
- **`ssh_manager.dart`**: SSH 会话管理器。
  - 包含 `_TcpNoDelaySocket`：实现 `SSHSocket` 接口，设置 `TCP_NODELAY=true` 禁用 Nagle 算法，消除 Nagle + 延迟 ACK 叠加导致的 ~500ms 交互延迟。
  - 封装 `dartssh2`，负责建立 SSH 连接、认证（密码），管理 Shell 会话。
  - PTY 指定 `type: 'xterm-256color'`，确保服务端正确识别终端类型。
  - `Utf8Decoder(allowMalformed: true)` 防止流式数据在 UTF-8 序列边界截断时抛异常。
  - `StreamController.broadcast(sync: true)` 同步派发输出，消除微任务调度延迟。
  - 提供 `write(data)`、`resize(width, height)` 方法，`dispose()` 清理连接。

### `lib/function/transfer/` (传输管理)
- **`transfer_manager.dart`**: 文件传输管理器（单例，`ChangeNotifier`）。
  - 统一管理文件上传/下载任务队列（`TransferTask` 列表）。
  - `addTask()`：新增任务，状态为 `pending`。
  - `updateProgress()`：更新已传输字节数，状态变为 `running`。
  - `completeTask()`：标记完成，8 秒后自动从列表移除（保留足够时间在 UI 展示完成状态）。
  - `failTask()`：标记失败并记录错误信息。
  - `removeTask(taskId)`：手动移除单条任务（供 UI 关闭按钮调用）。
  - `clearCompleted()`：批量移除所有已完成或失败的任务。

### `lib/function/windows/` (Windows 功能)
- **`storage.dart`**: Windows 平台文件存储服务（仅 Windows 使用）。
  - `getDrives()`：遍历 A-Z 检测存在的磁盘驱动器。
  - `getDirectoryContent(path)`：获取目录内容，排序（文件夹在前）。
  - `getQuickAccessPaths()`：依赖 `USERPROFILE` 环境变量，返回快速访问路径映射（`{'桌面': ...\Desktop, '下载': ...\Downloads}`）。

## UI (界面展示层)
存放 Flutter Widget 和页面布局。

### `lib/ui/android/` (Android 平台特定 UI)
- **`ssh_keyboard_overlay.dart`**: Android 平台 SSH 终端软键盘输入层。
  - 提供右下角浮动键盘按钮（FAB），点击后弹出 / 收起系统软键盘。
  - 通过偏移至屏幕外（left: -9999）的隐藏 TextField 接收 IME 输入，经 delta 追踪转发给 xterm Terminal。
  - 哨兵缓冲区（10个空格）确保连续退格可被检测；内容低于阈值时自动重置。
  - `heroTag` 含 sessionId，避免多标签页间 Hero 动画冲突。
  - 完全封装 Android 软键盘逻辑，与物理键盘逻辑（`ssh_terminal_view.dart`）完全分离。
- **`file_tree_android.dart`**: Android 平台的本地文件树实现。
  - 展示本地存储目录树，支持懒加载，提供文件类型图标和大小格式化显示。
  - 隐藏以 `.` 开头的隐藏文件/目录。
  - 顶部显示**快速访问区**（由 `AndroidStorage.getQuickAccessPaths()` 提供路径），使用 `QuickAccessSectionHeader` 标题，`_DirectoryNode` 支持 `customIcon`/`customIconColor` 参数。
  - **集成 `ContextMenuTrigger`**：支持长按和鼠标右键触发上下文菜单（刷新、粘贴）。
  - **集成 `SelectionManager`**：支持点击高亮选中。
  - **集成 `ClipboardManager`**：支持本地文件复制、剪切，以及向目录粘贴（含从远程下载）。

### `lib/ui/common/` (通用组件)
- **`context_menu_trigger.dart`**: 上下文菜单触发器。
  - 统一处理鼠标右键点击（`Listener.onPointerDown` + `kSecondaryMouseButton`）和触摸长按（`onLongPressStart`）。
  - 用于在不同输入设备（鼠标/触摸屏）上提供一致的右键菜单体验。
- **`selection_manager.dart`**: 文件选择状态管理器（单例，`ChangeNotifier`）。
  - 管理文件树（本地和远程）中的单选高亮状态。
  - 区分选中项来源（`local`/`remote`），避免两侧同时高亮造成混淆。
- **`transfer_progress_widget.dart`**: 文件传输进度条组件（轻量内嵌版，**当前无任何地方引用，保留备用**）。
  - 监听 `TransferManager` 状态，实时展示指定类型（Upload/Download）的任务列表。
  - 显示文件名、传输类型图标（上传/下载）、进度百分比/大小、进度条。
- **`transfer_list_dialog.dart`**: 传输列表对话框（全功能版，替代上面的内嵌组件）。
  - 从 AppBar 传输按钮（带活跃任务数角标）点击打开。
  - 提供全部/上传/下载三个 Tab 过滤视图。
  - 每条任务显示：图标、文件名、源路径→目标路径、进度条（4px）、已传输/总大小。
  - 支持单条关闭（已完成/失败任务）和批量"清空已完成/失败"操作。
  - 通过 `ListenableBuilder` 实时响应 `TransferManager` 状态变化；响应式尺寸（宽<600 时全屏比例，否则 600×560）。

### `lib/ui/connect/` (连接管理界面)
- **`connection_manager_dialog.dart`**: 连接管理主窗口（悬浮窗）。
  - 展示已保存的连接列表，提供响应式布局（手机端 90%×80%，PC 端 600×700）。
  - **搜索/过滤**：`TextEditingController` 绑定搜索框，`onChanged`/`onSubmitted` 实时触发，按"完全匹配 → 包含关键字 → 其余"三级排序，同时支持名称和 IP 搜索，搜索为空时显示全部。
  - 处理新建、编辑、**删除**（先 `Navigator.pop` 关闭确认框再执行删除）、右键菜单和发起连接的交互逻辑。
  - 创建会话时生成唯一 Runtime ID（`时间戳_connectionId`），避免同配置多会话冲突。
- **`connection_form.dart`**: 连接编辑表单。
  - 提供名称、主机、端口、备注、认证方式（密码/私钥）输入框。
  - 使用 TDesign 组件构建，`onSave` 回调返回 `Connection` 对象。

### `lib/ui/main/` (主工作流界面)
应用程序的核心操作界面。

- **`workflow.dart`**: 主工作台页面。
  - 整体布局容器，包含顶部导航栏和可调整大小的面板区域（三个 `ResizableWidget` 嵌套）。
  - **布局持久化**：使用 `shared_preferences` 保存和恢复三个分割面板的像素尺寸及锁定状态。
  - AppBar 包含：锁定布局按钮、**传输列表按钮**（`ListenableBuilder` 包裹，有活跃任务时显示红色数量角标，点击打开 `TransferListDialog`）、连接管理按钮、设置按钮（占位）。
  - `_buildFileTree()`：通过 `Platform.isWindows / Platform.isAndroid` 选择对应平台文件树组件，其他平台显示占位。
  - 监听 `DeviceMonitor.statusStream` 更新设备状态卡片。

#### `lib/ui/main/models/` (UI 数据模型)
- **`terminal_session.dart`**: 终端会话运行时模型。
  - 表示一个正在进行的连接（id、name、type、host、port、username、password、privateKeyPath、isConnected）。
  - 包含 JSON 序列化/反序列化方法。
- **`device_info.dart`**: 设备状态数据模型。
  - 定义 `DeviceInfo`（IP、name、cpuUsage、memoryUsage、status）和 `DeviceStatusType`（connecting/connected/failed）枚举。
  - 提供 `cpuUsagePercent`、`memoryUsagePercent` 格式化字符串属性。

#### `lib/ui/main/ssh/` (SSH 视图)
- **`ssh_terminal_view.dart`**: SSH 终端模拟器视图（平台无关的核心逻辑）。
  - 基于 `xterm` 包（`Terminal` + `TerminalView`）实现完整 VT100/VT220/xterm-256color 渲染。
  - **物理键盘输入**（Windows / Linux / macOS / Android 物理键盘均走此路径）：`hardwareKeyboardOnly: true` 跳过 IME，`onKeyEvent + event.character` 直接获取可打印字符；支持 Ctrl+A~Z、F1~F12、方向键等特殊键；右键有文字时复制，无文字时粘贴。
  - **光标闪烁**：聚焦时白/灰 530ms 交替闪烁，失焦时灰色描边，通过动态 `TerminalTheme.cursor` 实现。
  - **Android 软键盘**：通过 `if (Platform.isAndroid)` 挂载 `SshKeyboardOverlay`（`ui/android/`），本文件不含任何 Android IME 代码。
  - `AutomaticKeepAliveClientMixin`：标签页切换时保持终端后台活跃。
  - `initState` 中向 `DeviceMonitor` 注册，`dispose` 中注销。

#### `lib/ui/main/widgets/` (主界面组件)
- **`file_tree.dart`**: 本地文件树的基础抽象与通用共享组件。
  - `FileNode`：文件节点数据模型（名称、路径、是否目录、大小、子节点）。
  - `FileTreeBase` / `FileTreeBaseState`：文件树抽象基类（目前两平台实现均未继承，保留备用）。
  - **`QuickAccessEntry`**：快速访问入口数据模型（label/icon/iconColor/path），供 Windows 和 Android 平台共用。
  - **`QuickAccessSectionHeader`**：快速访问分区标题组件（小号灰色文字，默认文字"快速访问"，可自定义），统一两平台文件树的视觉风格。
- **`device_status.dart`**: 设备状态监控卡片。
  - 位于左上角，使用 `TabBar`/`TabBarView` 展示多个活跃连接设备的实时 CPU/内存状态。
  - 提供统一的占位 UI（等待连接状态，CPU/内存均显示 0%）。
  - 进度条使用 `strokeWidth: 20`（加粗），颜色随使用率变化（绿/黄/红）。
- **`remote_file_manager.dart`**: 远程文件管理器（SFTP 树状结构）。
  - 展示远程服务器文件列表，支持目录懒加载导航，根节点默认展开。
  - 集成 `SftpManager` 进行文件操作（创建目录、删除文件/目录、刷新缓存）。
  - 集成 `ClipboardManager`：支持远程文件复制、剪切，以及向目录粘贴（含本地上传）。
  - `_SftpFileNode` 支持文件复制/剪切/删除上下文菜单；文件大小格式化显示。
- **`resizable_widget.dart`**: 可调整大小的分割面板组件（严格要求恰好 2 个子组件）。
  - 支持水平和垂直方向的拖拽调整，鼠标指针随方向切换。
  - 第一个子组件固定像素尺寸，第二个子组件 `Expanded` 占据剩余空间。
  - 拖拽结束时触发 `onResizeEnd` 回调（返回第一个子组件的像素尺寸），供 `workflow.dart` 保存布局。
  - `isResizable: false` 时禁用拖拽，锁定布局。
- **`terminal_tabs.dart`**: 终端标签页栏。
  - 管理多个 SSH/VNC 会话的标签页切换，含关闭按钮和右键菜单（关闭、关闭其他）。
  - 使用 `IndexedStack` + `GlobalKey` 缓存机制，确保切换 Tab 或删除前置 Tab 时，后续 Tab 的 Shell 连接不断开。
  - 包含 `VncDesktopView`（占位实现，仅显示连接信息，VNC 功能待实现）。

### `lib/ui/windows/` (Windows 平台特定 UI)
- **`file_tree_windows.dart`**: Windows 平台的本地文件树实现。
  - 顶部显示**快速访问区**（由 `WindowsStorage.getQuickAccessPaths()` 提供路径，过滤不存在目录），使用 `QuickAccessSectionHeader` 标题，桌面图标用 `TDIcons.desktop`，下载图标用 `TDIcons.download`。
  - 快速访问区之后显示**驱动器列表**（A-Z 驱动器，使用 `TDIcons.server` 图标）。
  - `_DirectoryNode` 支持 `customIcon`/`customIconColor` 参数，懒加载子目录内容。
  - `_FileNode` 提供文件类型图标映射，支持复制/剪切/打开/属性上下文菜单（打开/属性为占位）。
  - **集成 `ContextMenuTrigger`**：支持鼠标右键触发上下文菜单（刷新、粘贴）。
  - **集成 `SelectionManager`**：支持点击高亮选中。
  - **集成 `ClipboardManager`**：支持本地文件复制、剪切，以及向目录粘贴。
