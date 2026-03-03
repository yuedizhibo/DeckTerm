# DeckTerm 项目文件结构说明

本文档详细说明 `lib` 目录下各个文件的职责与功能。

## 根目录
- **`main.dart`**: 应用程序入口文件，负责初始化 Flutter 应用、配置主题（TDesign）和路由。

## Function (核心功能层)
存放非 UI 的业务逻辑、数据管理和底层服务。

### `lib/function/android/` (Android 功能)
- **`storage.dart`**: Android 平台文件存储服务。
  - 提供获取系统根目录（如 `/storage/emulated/0`）的方法。
  - 提供获取目录内容（文件/文件夹）的方法，并进行排序。

### `lib/function/clipboard/` (剪贴板功能)
- **`clipboard_manager.dart`**: 文件剪贴板管理器（单例）。
  - 管理跨平台（本地 Android/Windows <-> 远程 SFTP）的文件复制、剪切状态。
  - 处理不同源之间的粘贴逻辑（本地复制/移动、上传、下载）。
  - 维护剪贴板内容模型 `FileClipboardItem`。

### `lib/function/connect/` (连接管理)
- **`connection_manager.dart`**: 连接管理器。负责持久化存储、读取、添加、删除和更新用户的连接配置（使用 `shared_preferences`）。
- **`connection_model.dart`**: 连接配置的数据模型。定义了连接的属性（如主机、端口、用户名、密码、私钥路径、类型等）及其 JSON 序列化逻辑。

### `lib/function/dev-file/` (开发/远程文件)
- **`sftp_manager.dart`**: SFTP 管理器。
  - 封装 `dartssh2` 的 SFTP 功能。
  - 负责建立 SFTP 连接、获取目录列表（带缓存）、创建目录、删除文件/目录。
  - 提供上传/下载流的回调接口（通过 `TransferManager` 集成）。

### `lib/function/monitor/` (设备监控)
- **`device_monitor.dart`**: 设备状态监控器（单例）。
  - 维护独立的 SSH 连接用于监控。
  - 维护活跃 SSH 会话的引用计数。
  - 定时（每 5 秒）通过 SSH 发送命令查询远程设备的 CPU 和内存使用率。
  - 通过 Stream 向 UI 广播最新的设备状态列表。

### `lib/function/ssh/` (SSH 服务)
- **`ssh_manager.dart`**: SSH 会话管理器。
  - 封装 `dartssh2` 库，负责建立 SSH 连接、认证（密码/密钥）。
  - 管理 SSH Shell 和数据流（输入/输出）。
  - 使用 `Utf8Decoder(allowMalformed: true)` 解码流式数据，防止 UTF-8 序列边界截断抛异常。
  - `StreamController.broadcast(sync: true)` 同步派发输出，减少显示延迟。
  - PTY 配置指定 `type: 'xterm-256color'`，确保服务端正确识别终端类型。
  - 提供 `resize()` 方法通知服务端终端尺寸变化。

### `lib/function/transfer/` (传输管理)
- **`transfer_manager.dart`**: 文件传输管理器（单例）。
  - 统一管理文件上传/下载任务队列。
  - 跟踪每个任务的进度（字节数）、状态（进行中/完成/失败）和错误信息。
  - 提供 `ChangeNotifier` 机制供 UI 实时监听进度更新。

### `lib/function/windows/` (Windows 功能)
- **`storage.dart`**: Windows 平台文件存储服务。
  - 提供获取系统驱动器列表的方法。
  - 提供获取目录内容（文件/文件夹）的方法，并进行排序。

## UI (界面展示层)
存放 Flutter Widget 和页面布局。

### `lib/ui/android/` (Android 平台特定 UI)
- **`ssh_keyboard_overlay.dart`**: Android 平台 SSH 终端软键盘输入层。
  - 提供右下角浮动键盘按钮（FAB），点击后弹出 / 收起系统软键盘。
  - 通过偏移至屏幕外的隐藏 TextField 接收 IME 输入，经 delta 追踪转发给 xterm Terminal。
  - 哨兵缓冲区（10个空格）确保连续退格可被检测。
  - 完全封装 Android 软键盘逻辑，与物理键盘逻辑（ssh_terminal_view.dart）完全分离。
- **`file_tree_android.dart`**: Android 平台的本地文件树实现。
  - 适配移动端的文件浏览器 UI。
  - 支持懒加载目录结构。
  - 提供文件类型图标和大小格式化显示。
  - **集成 `ContextMenuTrigger`**：支持长按和鼠标右键触发上下文菜单。
  - **集成 `SelectionManager`**：支持点击高亮选中。
  - **集成 `ClipboardManager`**：支持本地文件复制、剪切，以及从剪贴板粘贴（含远程下载）。
  - **集成 `TransferProgressWidget`**：显示文件下载进度条。

### `lib/ui/common/` (通用组件)
- **`context_menu_trigger.dart`**: 上下文菜单触发器。
  - 统一处理鼠标右键点击 (`onSecondaryTapUp`) 和触摸长按 (`onLongPressStart`)。
  - 用于在不同输入设备（鼠标/触摸屏）上提供一致的右键菜单体验。
- **`selection_manager.dart`**: 文件选择状态管理器（单例）。
  - 管理文件树（本地和远程）中的单选高亮状态。
  - 区分选中项来源（local/remote），支持点击选中和右键选中。
- **`transfer_progress_widget.dart`**: 文件传输进度条组件（轻量内嵌版，已不在主界面使用）。
  - 监听 `TransferManager` 状态，实时展示上传/下载任务列表。
  - 显示文件名、传输类型图标（上传/下载）、进度百分比/大小、以及进度条。
  - 自动过滤显示特定类型（Upload/Download）的任务。
- **`transfer_list_dialog.dart`**: 传输列表对话框（全功能版）。
  - 从 AppBar 传输按钮（带活跃任务数角标）点击打开。
  - 提供全部/上传/下载三个 Tab 过滤视图。
  - 每条任务显示：文件名、路径、进度条、已传输/总大小。
  - 支持单条关闭（已完成/失败任务）和批量"清空已完成/失败"操作。
  - 通过 `ListenableBuilder` 实时响应 `TransferManager` 状态变化。

### `lib/ui/connect/` (连接管理界面)
- **`connection_manager_dialog.dart`**: 连接管理主窗口（悬浮窗）。
  - 展示已保存的连接列表。
  - 提供响应式布局（手机端全屏 dialog，Pad/PC 端悬浮小窗）。
  - 处理新建、编辑、删除和发起连接的交互逻辑。
  - 创建会话时生成唯一的 Runtime ID，避免同配置会话冲突。
- **`connection_form.dart`**: 连接编辑表单。
  - 提供输入框供用户填写连接信息（IP、端口、认证方式等）。
  - 使用 TDesign 组件构建。

### `lib/ui/main/` (主工作流界面)
应用程序的核心操作界面。

- **`workflow.dart`**: 主工作台页面。
  - 整体布局容器，包含顶部导航栏和可调整大小的面板区域。
  - **布局持久化**：使用 `shared_preferences` 保存和恢复面板比例及锁定状态。
  - 负责协调各个子模块（设备状态、文件树、终端 Tabs、远程文件）。
  - 处理“连接管理”弹窗的调用和新会话的创建。

#### `lib/ui/main/models/` (UI 数据模型)
- **`terminal_session.dart`**: 终端会话模型。
  - 运行时状态模型，表示一个正在进行的连接（包含连接配置 + 连接状态）。
- **`device_info.dart`**: 设备状态模型。
  - 定义设备监控数据的结构（IP、CPU 使用率、内存使用率、连接状态）。

#### `lib/ui/main/ssh/` (SSH 视图)
- **`ssh_terminal_view.dart`**: SSH 终端模拟器视图（平台无关的核心逻辑）。
  - 基于 `xterm` 包（`Terminal` + `TerminalView`）实现完整 VT100/VT220/xterm-256color 渲染。
  - **物理键盘输入**（Windows / Linux / macOS / Android 物理键盘均走此路径）：
    - `hardwareKeyboardOnly: true` 跳过 TextInputClient/IME，消除 Windows IME 冲突。
    - `TerminalView.onKeyEvent + event.character` 绕过 IME 管道直接获取可打印字符。
  - **光标闪烁**：聚焦时白/灰 530ms 交替闪烁，失焦时灰色描边，通过动态 TerminalTheme.cursor 实现。
  - **Android 软键盘**：通过 `if (Platform.isAndroid)` 挂载 `SshKeyboardOverlay`（ui/android/），本文件不含任何 Android IME 代码。
  - 利用 `AutomaticKeepAliveClientMixin` 在标签页切换时保持终端后台活跃。
  - 在 `initState` 中向 `DeviceMonitor` 注册监控任务。

#### `lib/ui/main/widgets/` (主界面组件)
- **`device_status.dart`**: 设备状态监控卡片。
  - 位于左上角，使用标签页（Tab）形式展示多个活跃连接设备的实时状态（CPU/内存仪表盘）。
  - 提供统一的占位 UI（等待连接状态）。
  - 进度条样式已加粗优化。
- **`file_tree.dart`**: 本地文件树的基础抽象。
  - 定义 `FileNode` 数据模型（名称、路径、是否目录、大小等）。
  - 定义 `FileTreeBase` 和 `FileTreeBaseState`，提供文件树的通用状态管理和加载逻辑。
- **`remote_file_manager.dart`**: 远程文件管理器。
  - (SFTP) 展示远程服务器的文件列表，支持目录导航。
  - 集成 `SftpManager` 进行文件操作（创建文件夹、删除）。
  - 集成 `ClipboardManager` 和 `TransferProgressWidget` 支持文件上传/下载及进度显示。
  - 支持上下文菜单（刷新、新建、删除、复制、粘贴）。
- **`resizable_widget.dart`**: 可调整大小的分割面板组件。
  - 支持水平和垂直方向的拖拽调整。
  - 支持最大/最小比例限制（例如限制设备监控面板的高度）。
  - 提供调整结束的回调，用于保存布局状态。
- **`terminal_tabs.dart`**: 终端标签页栏。
  - 管理多个 SSH/VNC 会话的切换。
  - 使用 `IndexedStack` 和 `GlobalKey` 缓存机制，确保切换 Tab 或删除前面的 Tab 时，后续 Tab 的状态（Shell 连接）不会丢失或重建。

### `lib/ui/windows/` (Windows 平台特定 UI)
- **`file_tree_windows.dart`**: Windows 平台的本地文件树实现。
  - 使用 TDesign 组件构建的树状文件浏览器。
  - 支持懒加载和文件图标显示。
