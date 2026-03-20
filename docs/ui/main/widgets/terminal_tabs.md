# terminal_tabs.dart

> 路径：`lib/ui/main/widgets/terminal_tabs.dart`

## 职责

终端标签页栏组件。管理多个 SSH/VNC 会话的标签页切换，包含 VNC 占位实现。

## 核心内容

### `TerminalTabs` (StatefulWidget + TickerProviderStateMixin)

| 参数 | 类型 | 说明 |
|------|------|------|
| `sessions` | `List<TerminalSession>` | 会话列表 |
| `onAddSession` | `VoidCallback?` | 添加会话回调 |
| `onRemoveSession` | `Function(String)?` | 移除会话回调（传入 sessionId） |
| `onSessionSwitch` | `Function(TerminalSession)?` | 切换会话回调 |

### 核心机制

- **IndexedStack + GlobalKey 缓存**：确保切换 Tab 或删除前置 Tab 时，后续 Tab 的 Shell 连接不断开。`_tabKeys` Map 为每个会话维护 `GlobalKey`，Widget 状态在重建时保留。
- **TabController 动态更新**：`didUpdateWidget` 中检测会话列表变化，重建 TabController 并保持索引安全。

### Tab 栏

- 可滚动 Tab（`isScrollable: true`）。
- 每个 Tab：会话名称 + 关闭按钮（X）。
- 右键菜单（`ContextMenuTrigger`）：关闭标签、关闭其他。
- 末尾"+"按钮：添加新会话。

### `VncDesktopView` (StatelessWidget)

VNC 远程桌面占位实现。仅显示连接信息和"连接/断开"按钮，VNC 功能待实现。

### `_AddSessionDialog` (StatelessWidget)

添加会话类型选择弹窗（SSH/VNC），目前未被直接使用。

## 依赖关系

- `SshTerminalView` — SSH 终端渲染
- `TerminalSession` — 会话数据模型
- `ContextMenuTrigger` — 右键菜单
