# ssh_terminal_view.dart

> 路径：`lib/ui/main/ssh/ssh_terminal_view.dart`

## 职责

SSH 终端模拟器视图。基于 `xterm` 包实现完整 VT100/VT220/xterm-256color 渲染，处理物理键盘输入和光标闪烁控制。

## 核心内容

### `SshTerminalView` (StatefulWidget + AutomaticKeepAliveClientMixin)

- `wantKeepAlive: true` — 标签页切换时保持终端后台活跃。
- `initState` 中向 `DeviceMonitor` 注册监控，`dispose` 中注销。

### 键盘输入策略

**物理键盘**（本文件实现，所有平台通用）：
- `hardwareKeyboardOnly: true`：跳过 TextInputClient/IME，避免 Windows IME 冲突。
- `event.character`：由 OS 填充，正确反映键盘布局，无需 TextInputClient。
- 支持：Ctrl+V 粘贴、Ctrl+A~Z 组合键、F1~F12、方向键、Enter、Backspace、Tab 等。

**Android 软键盘**（由 `SshKeyboardOverlay` 独立处理）：
- 通过 `if (Platform.isAndroid)` 在 Stack 中挂载。
- 本文件不含任何 Android IME/TextField 代码。

### 光标闪烁

| 状态 | 行为 |
|------|------|
| 聚焦 | 白色实心块，530ms 间隔白(#FFFFFF)/灰(#AEAFAD)交替 |
| 失焦 | 灰色描边块，不闪烁 |

通过动态修改 `TerminalTheme.cursor` 颜色实现，xterm painter 根据 `hasFocus` 选择 fill/stroke 样式。

### 右键菜单

- 有选中文字 → 复制到剪贴板
- 无选中文字 → 从剪贴板粘贴

### 终端主题

VS Code Dark 风格配色方案（背景 #1E1E1E，前景 #CCCCCC，完整 16 色定义）。

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `xterm` | Terminal + TerminalView 渲染 |
| `SshManager` | SSH 连接和数据传输 |
| `DeviceMonitor` | 注册/注销设备监控 |
| `SshKeyboardOverlay` | Android 软键盘支持 |
