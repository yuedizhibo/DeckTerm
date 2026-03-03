# DeckTerm

> 面向嵌入式开发与边缘计算的移动 SSH 终端 + 文件管理器
>
> A mobile SSH terminal & file manager for embedded development and edge computing

---

**[中文](#中文文档) · [English](#english-documentation)**

---

## 中文文档

### 项目简介

DeckTerm 是一款基于 Flutter 构建的跨平台 SSH 终端与文件管理应用，专为在移动设备（Android 平板）和 Windows PC 上提供接近桌面级的嵌入式开发调试体验而设计。

核心能力：
- 完整的 SSH 终端仿真（xterm-256color）
- 本地与远程 SFTP 文件管理
- 多会话并发，标签页切换
- 实时设备状态监控（CPU / 内存）
- 低延迟输入（TCP_NODELAY 优化，消除 Nagle 算法导致的输入回显延迟）

### 支持平台

| 平台 | 状态 |
|---|---|
| Android（手机 / 平板）| ✅ 支持 |
| Windows | ✅ 支持 |

### 功能特性

#### SSH 终端
- SSH 密码 / 私钥认证
- 完整 VT100 / VT220 / xterm-256color 终端仿真（基于 [xterm](https://pub.dev/packages/xterm) 4.x）
- 多会话标签页管理，切换时 Shell 连接保活
- 光标聚焦闪烁（选中时白/灰交替，未选中时灰色描边）
- Windows 物理键盘：全量按键支持（方向键、F1-F12、Ctrl 组合键、输入法兼容）
- Android 物理键盘：同 Windows
- Android 软键盘：右下角浮动按钮唤出系统键盘，IME 输入转发至终端
- 右键复制 / 粘贴

#### 文件管理
- **本地文件树**：Android 内部存储浏览 / Windows 驱动器浏览（平台独立实现）
- **远程 SFTP 文件管理**：目录导航、创建文件夹、删除
- **跨平台文件传输**：本地 ↔ 远程（上传 / 下载），实时进度条
- 右键 + 长按 上下文菜单（复制、剪切、粘贴、删除、刷新）
- 文件选择状态跨组件同步

#### 连接管理
- 多连接配置持久化（`shared_preferences`）
- 支持 SSH / VNC 连接类型
- 响应式管理界面（手机全屏弹窗 / Pad 及 PC 悬浮小窗）
- 同一配置支持多个并发会话（唯一 Runtime ID）

#### 设备监控
- 独立监控 SSH 连接（不占用终端会话）
- 5 秒间隔定时查询远程 CPU 和内存使用率
- 多设备仪表盘，标签页展示

#### 工作台布局
- 可拖拽调整的分割面板（水平 / 垂直）
- 面板比例自动持久化，下次启动自动恢复
- 面板锁定 / 解锁

### 技术亮点

| 特性 | 说明 |
|---|---|
| **TCP_NODELAY** | 禁用 Nagle 算法，消除 SSH 人机交互场景下 Nagle + 延迟 ACK 叠加导致的 ~500ms 输入延迟 |
| **xterm-256color PTY** | PTY 配置指定 `type: 'xterm-256color'`，服务端正确识别终端类型 |
| **流式 UTF-8 解码** | `Utf8Decoder(allowMalformed: true)` 防止字节序列跨包截断时抛异常、丢数据 |
| **同步事件派发** | `StreamController.broadcast(sync: true)` 数据到达后同步写入 xterm，消除微任务调度延迟 |
| **hardwareKeyboardOnly** | xterm 4.x 参数，跳过 TextInputClient/IME 建立，消除 Windows 下的 IME 冲突 |
| **Tab 状态保活** | `IndexedStack` + `GlobalKey` + `AutomaticKeepAliveClientMixin`，切换标签页不断开 Shell |
| **平台代码分离** | Android 专用代码位于 `ui/android/` 和 `function/android/`，Windows 专用代码位于对应目录，互不干扰 |

### 技术栈

| 库 | 版本 | 用途 |
|---|---|---|
| [tdesign_flutter](https://pub.dev/packages/tdesign_flutter) | ^0.2.7 | UI 组件库（腾讯 TDesign） |
| [dartssh2](https://pub.dev/packages/dartssh2) | ^2.2.5 | SSH / SFTP 客户端 |
| [xterm](https://pub.dev/packages/xterm) | ^4.0.0 | 终端仿真与渲染 |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | ^2.2.2 | 连接配置 / 布局状态持久化 |
| [permission_handler](https://pub.dev/packages/permission_handler) | ^12.0.1 | Android 运行时权限管理 |

### 项目结构

```
deckterm/
├── android/                        # Android 平台原生配置
├── windows/                        # Windows 平台原生配置
└── lib/
    ├── main.dart                   # 应用入口
    ├── fileinfo.md                 # 文件结构说明（新增文件须在此登记）
    ├── function/                   # 业务逻辑层（无 UI）
    │   ├── android/
    │   │   └── storage.dart        # Android 文件系统访问
    │   ├── windows/
    │   │   └── storage.dart        # Windows 驱动器列表与文件访问
    │   ├── clipboard/
    │   │   └── clipboard_manager.dart   # 跨平台文件剪贴板（单例）
    │   ├── connect/
    │   │   ├── connection_manager.dart  # 连接配置持久化
    │   │   └── connection_model.dart    # 连接数据模型
    │   ├── dev-file/
    │   │   └── sftp_manager.dart        # SFTP 文件操作
    │   ├── monitor/
    │   │   └── device_monitor.dart      # 远程设备状态监控
    │   ├── ssh/
    │   │   └── ssh_manager.dart         # SSH 会话管理（含 TCP_NODELAY）
    │   └── transfer/
    │       └── transfer_manager.dart    # 文件传输队列管理
    └── ui/                         # 界面展示层
        ├── android/
        │   ├── ssh_keyboard_overlay.dart  # Android 软键盘输入层
        │   └── file_tree_android.dart     # Android 文件树
        ├── windows/
        │   └── file_tree_windows.dart     # Windows 文件树
        ├── common/
        │   ├── context_menu_trigger.dart  # 右键 / 长按触发器
        │   ├── selection_manager.dart     # 文件选择状态管理
        │   └── transfer_progress_widget.dart  # 传输进度条
        ├── connect/
        │   ├── connection_manager_dialog.dart  # 连接管理弹窗
        │   └── connection_form.dart             # 连接编辑表单
        └── main/
            ├── workflow.dart                # 主工作台（布局容器）
            ├── models/
            │   ├── terminal_session.dart    # 终端会话运行时模型
            │   └── device_info.dart         # 设备监控数据模型
            ├── ssh/
            │   └── ssh_terminal_view.dart   # SSH 终端视图（核心）
            └── widgets/
                ├── device_status.dart       # 设备状态仪表盘
                ├── file_tree.dart           # 文件树基础抽象
                ├── remote_file_manager.dart # 远程文件管理器
                ├── resizable_widget.dart    # 可调整分割面板
                └── terminal_tabs.dart       # 终端标签页栏
```

### 快速开始

#### 环境要求

- Flutter SDK `^3.11.0`
- Android：NDK + Android SDK（API 21+）
- Windows：Visual Studio 2022（含 C++ 桌面开发负载）

#### 安装依赖

```bash
flutter pub get
```

#### 运行

```bash
# Android
flutter run -d android

# Windows
flutter run -d windows
```

#### 构建发布包

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Windows 可执行文件
flutter build windows --release
```

#### 代码分析

```bash
flutter analyze
```

### 平台适配说明

#### 键盘输入策略

| 场景 | 实现文件 | 方案 |
|---|---|---|
| Windows 物理键盘 | `ui/main/ssh/ssh_terminal_view.dart` | `event.character` 绕过 IME，直接从 HardwareKeyboard 获取字符 |
| Android 物理键盘 | `ui/main/ssh/ssh_terminal_view.dart` | 同 Windows |
| Android 软键盘 | `ui/android/ssh_keyboard_overlay.dart` | 隐藏 TextField + IME delta 追踪，完全独立封装 |

#### 文件系统策略

| 平台 | UI 文件 | 功能文件 |
|---|---|---|
| Android | `ui/android/file_tree_android.dart` | `function/android/storage.dart` |
| Windows | `ui/windows/file_tree_windows.dart` | `function/windows/storage.dart` |

#### 新增平台代码规范

- Android 专用 UI → `lib/ui/android/`
- Android 专用功能 → `lib/function/android/`
- Windows 专用 UI → `lib/ui/windows/`
- Windows 专用功能 → `lib/function/windows/`
- **新增任何文件后必须在 `lib/fileinfo.md` 中登记文件路径和职责说明**

### 开发规范

- UI 组件库：腾讯 TDesign Flutter（`tdesign_flutter ^0.2.7`），不确定的 API 先查阅本地源码目录 `tdesign-flutter-0.2.7/`
- 平台代码严格分目录，禁止在公共文件中硬编码平台特定逻辑（通过 `Platform.isXxx` 判断后引用平台组件）
- 新增文件须在 `lib/fileinfo.md` 登记

---

## English Documentation

### Overview

DeckTerm is a cross-platform SSH terminal and file manager built with Flutter, designed to bring a near-desktop debugging experience to Android tablets and Windows PCs for embedded development and edge computing scenarios.

Core capabilities:
- Full SSH terminal emulation (xterm-256color)
- Local and remote SFTP file management
- Multi-session tabs with persistent shell connections
- Real-time device monitoring (CPU / Memory)
- Low-latency input (TCP_NODELAY optimization eliminates the ~500ms echo delay caused by Nagle's algorithm)

### Supported Platforms

| Platform | Status |
|---|---|
| Android (Phone / Tablet) | ✅ Supported |
| Windows | ✅ Supported |

### Features

#### SSH Terminal
- SSH password / private key authentication
- Full VT100 / VT220 / xterm-256color terminal emulation (powered by [xterm](https://pub.dev/packages/xterm) 4.x)
- Multi-session tab management with shell connection keep-alive on tab switch
- Cursor blink animation (white/gray alternating when focused, gray outline when unfocused)
- Windows physical keyboard: full key support (arrow keys, F1–F12, Ctrl combos, IME-compatible)
- Android physical keyboard: same as Windows
- Android soft keyboard: floating button to invoke system keyboard, IME input forwarded to terminal
- Right-click copy / paste

#### File Management
- **Local file tree**: Android internal storage / Windows drive browser (platform-specific implementations)
- **Remote SFTP**: directory navigation, create folder, delete
- **Cross-platform file transfer**: local ↔ remote (upload / download) with real-time progress bar
- Right-click + long-press context menu (copy, cut, paste, delete, refresh)
- File selection state synchronized across components

#### Connection Management
- Multiple connection profiles with persistence (`shared_preferences`)
- SSH and VNC connection types
- Responsive UI (full-screen dialog on phone / floating panel on tablet & PC)
- Multiple concurrent sessions from the same profile (unique runtime ID per session)

#### Device Monitoring
- Dedicated monitoring SSH connection (independent from terminal sessions)
- Queries remote CPU and memory usage every 5 seconds
- Multi-device dashboard in tab view

#### Workspace Layout
- Draggable split panels (horizontal / vertical)
- Panel ratio auto-saved and restored on next launch
- Panel lock / unlock toggle

### Technical Highlights

| Feature | Description |
|---|---|
| **TCP_NODELAY** | Disables Nagle's algorithm, eliminating the ~500ms echo delay caused by Nagle + delayed-ACK interaction in interactive SSH sessions |
| **xterm-256color PTY** | PTY type set to `xterm-256color` so the server correctly identifies the terminal |
| **Streaming UTF-8 decode** | `Utf8Decoder(allowMalformed: true)` prevents exceptions when multi-byte sequences are split across TCP packets |
| **Synchronous event dispatch** | `StreamController.broadcast(sync: true)` delivers received data synchronously to xterm, eliminating microtask scheduling latency |
| **hardwareKeyboardOnly** | xterm 4.x flag that skips TextInputClient/IME setup, resolving the Windows IME conflict that previously broke character input |
| **Tab keep-alive** | `IndexedStack` + `GlobalKey` + `AutomaticKeepAliveClientMixin` keeps shell connections alive across tab switches |
| **Platform code separation** | Android-specific code in `ui/android/` and `function/android/`; Windows-specific in corresponding directories |

### Tech Stack

| Library | Version | Purpose |
|---|---|---|
| [tdesign_flutter](https://pub.dev/packages/tdesign_flutter) | ^0.2.7 | UI component library (Tencent TDesign) |
| [dartssh2](https://pub.dev/packages/dartssh2) | ^2.2.5 | SSH / SFTP client |
| [xterm](https://pub.dev/packages/xterm) | ^4.0.0 | Terminal emulation and rendering |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | ^2.2.2 | Connection config / layout state persistence |
| [permission_handler](https://pub.dev/packages/permission_handler) | ^12.0.1 | Android runtime permission management |

### Project Structure

```
deckterm/
├── android/                        # Android native configuration
├── windows/                        # Windows native configuration
└── lib/
    ├── main.dart                   # App entry point
    ├── fileinfo.md                 # File registry (register every new file here)
    ├── function/                   # Business logic layer (no UI)
    │   ├── android/
    │   │   └── storage.dart        # Android filesystem access
    │   ├── windows/
    │   │   └── storage.dart        # Windows drive listing & file access
    │   ├── clipboard/
    │   │   └── clipboard_manager.dart   # Cross-platform file clipboard (singleton)
    │   ├── connect/
    │   │   ├── connection_manager.dart  # Connection profile persistence
    │   │   └── connection_model.dart    # Connection data model
    │   ├── dev-file/
    │   │   └── sftp_manager.dart        # SFTP file operations
    │   ├── monitor/
    │   │   └── device_monitor.dart      # Remote device state monitor
    │   ├── ssh/
    │   │   └── ssh_manager.dart         # SSH session management (incl. TCP_NODELAY)
    │   └── transfer/
    │       └── transfer_manager.dart    # File transfer queue manager
    └── ui/                         # Presentation layer
        ├── android/
        │   ├── ssh_keyboard_overlay.dart  # Android soft keyboard input layer
        │   └── file_tree_android.dart     # Android file tree
        ├── windows/
        │   └── file_tree_windows.dart     # Windows file tree
        ├── common/
        │   ├── context_menu_trigger.dart  # Right-click / long-press trigger
        │   ├── selection_manager.dart     # File selection state
        │   └── transfer_progress_widget.dart  # Transfer progress bar
        ├── connect/
        │   ├── connection_manager_dialog.dart  # Connection manager dialog
        │   └── connection_form.dart             # Connection edit form
        └── main/
            ├── workflow.dart                # Main workspace (layout container)
            ├── models/
            │   ├── terminal_session.dart    # Runtime terminal session model
            │   └── device_info.dart         # Device monitor data model
            ├── ssh/
            │   └── ssh_terminal_view.dart   # SSH terminal view (core)
            └── widgets/
                ├── device_status.dart       # Device status dashboard
                ├── file_tree.dart           # File tree base abstraction
                ├── remote_file_manager.dart # Remote file manager
                ├── resizable_widget.dart    # Resizable split panel
                └── terminal_tabs.dart       # Terminal tab bar
```

### Getting Started

#### Requirements

- Flutter SDK `^3.11.0`
- Android: NDK + Android SDK (API 21+)
- Windows: Visual Studio 2022 with "Desktop development with C++" workload

#### Install Dependencies

```bash
flutter pub get
```

#### Run

```bash
# Android
flutter run -d android

# Windows
flutter run -d windows
```

#### Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Windows executable
flutter build windows --release
```

#### Code Analysis

```bash
flutter analyze
```

### Platform Adaptation Notes

#### Keyboard Input Strategy

| Scenario | File | Approach |
|---|---|---|
| Windows physical keyboard | `ui/main/ssh/ssh_terminal_view.dart` | `event.character` bypasses IME to get printable chars directly from HardwareKeyboard |
| Android physical keyboard | `ui/main/ssh/ssh_terminal_view.dart` | Same as Windows |
| Android soft keyboard | `ui/android/ssh_keyboard_overlay.dart` | Hidden TextField + IME delta tracking, fully self-contained |

#### Filesystem Strategy

| Platform | UI File | Logic File |
|---|---|---|
| Android | `ui/android/file_tree_android.dart` | `function/android/storage.dart` |
| Windows | `ui/windows/file_tree_windows.dart` | `function/windows/storage.dart` |

#### Conventions for Adding Platform Code

- Android-specific UI → `lib/ui/android/`
- Android-specific logic → `lib/function/android/`
- Windows-specific UI → `lib/ui/windows/`
- Windows-specific logic → `lib/function/windows/`
- **Every new file must be registered in `lib/fileinfo.md` with its path and responsibility**

### Development Guidelines

- UI component library: Tencent TDesign Flutter (`tdesign_flutter ^0.2.7`). Consult the local source directory `tdesign-flutter-0.2.7/` before using any unfamiliar API.
- Platform-specific code must live in its dedicated directory. Do not hardcode platform logic in shared files; use `Platform.isXxx` to inject the correct implementation.
- Every new file must be registered in `lib/fileinfo.md`.

### Data Flow Overview

```
Connection creation:
  ConnectionManagerDialog → TerminalSession → WorkflowPage._connectSession()
    → _sessions list → TerminalTabs renders tab

SSH terminal:
  SshTerminalView owns SshManager → registers with DeviceMonitor (ref-counted)
    → periodic CPU/memory queries → Stream → DeviceStatus widget

File operations:
  ClipboardManager (singleton) coordinates local ↔ SFTP copy/move/upload/download
    → TransferManager tracks progress → TransferProgressWidget displays it

Layout persistence:
  ResizableWidget drag end → callback → WorkflowPage saves panel ratio via shared_preferences
    → restored on next launch
```

---

*Built with Flutter · Powered by dartssh2 & xterm · UI by TDesign*
