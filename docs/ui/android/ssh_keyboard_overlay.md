# ssh_keyboard_overlay.dart

> 路径：`lib/ui/android/ssh_keyboard_overlay.dart`

## 职责

Android 平台专用的 SSH 终端软键盘输入层。在 Android 上为 SSH 终端提供软键盘输入能力，通过隐藏 TextField 接收 IME 输入，转发给 xterm Terminal。

## 平台归属

**仅 Android 使用**。由 `ssh_terminal_view.dart` 通过 `if (Platform.isAndroid)` 条件挂载。

## 核心内容

### `SshKeyboardOverlay` (StatefulWidget)

参数：
- `terminal`：xterm `Terminal` 实例
- `sessionId`：用于生成唯一 `heroTag`，避免多标签页间 Hero 动画冲突

### 输入原理

软键盘不产生 `HardwareKeyboard` 事件，字符只经过 IME/TextInputClient 管道。本组件通过以下机制桥接：

1. **隐藏 TextField**：偏移至屏幕外（`left: -9999`），接收 IME 输入。不使用 `Opacity(0)` 或 `Visibility` 隐藏，否则 IME 连接可能中断。
2. **Delta 追踪**：`onChanged` 中对比 `_prevText` 和新文本：
   - 文本变长 → 提取新增字符 → `terminal.textInput()`
   - 文本变短 → 计算差值 → 循环发送 `terminal.keyInput(TerminalKey.backspace)`
3. **哨兵缓冲区**：始终维持 >=10 个空格，确保连续退格可被检测。内容低于 5 字符时自动重置。
4. **Enter 键**：`onSubmitted` 触发 `terminal.keyInput(TerminalKey.enter)`，重置缓冲区，保持焦点。

### 交互流程

- 右下角 `FloatingActionButton`（键盘图标）
- 点击：TextField 获焦 → 软键盘弹出
- 再次点击：失焦 → 软键盘收起
- 图标根据状态切换：`keyboard_alt_outlined` / `keyboard_hide_outlined`

## 依赖关系

- `xterm` — `Terminal`, `TerminalKey`
