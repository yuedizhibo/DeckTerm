# connection_manager_dialog.dart

> 路径：`lib/ui/connect/connection_manager_dialog.dart`

## 职责

连接管理面板内容组件（非模态），嵌入 FloatingPanel（Windows）或 showPanelDialog（Android）中使用。展示已保存的连接列表，提供搜索、新建、编辑、删除和发起连接的完整交互。

## 核心内容

### `ConnectionManagerPanel` (StatefulWidget)

**参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `onConnect` | `ValueChanged<TerminalSession>?` | 发起连接回调，由 WorkflowPage 处理会话创建 |

- 双视图切换（`AnimatedSwitcher`）：连接列表 ↔ 编辑表单。

### 搜索功能

- `TextField` 搜索框 + `onChanged` 实时触发。
- 三级排序：完全匹配（名称或 IP） → 包含关键字 → 其余。
- 同时搜索名称和主机地址。
- 搜索为空时显示全部。

### 连接列表

每条连接显示：
- 类型图标（SSH 蓝色渐变 / VNC 紫色渐变）+ 名称 + `user@host:port`
- 编辑按钮（`_SmallIconBtn`）、删除按钮（hover 红色）、连接按钮（`_ActionChip` 蓝色主题）
- 右键菜单（`ContextMenuTrigger`）：连接、编辑、删除

### 发起连接

`_connect()` 方法生成唯一运行时 ID（`时间戳_connectionId`），创建 `TerminalSession` 并通过 `onConnect` 回调返回给 `WorkflowPage`。

### 删除确认

`AlertDialog`："确认删除" → 确认后执行删除 → 刷新列表。

### 内部组件

| 组件 | 说明 |
|------|------|
| `_SmallIconBtn` | 小图标操作按钮（28×28，hover 效果，可选 hover 颜色） |
| `_ActionChip` | 操作芯片按钮（图标+文字，支持 primary 蓝色主题） |

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `ConnectionManager` | 连接数据 CRUD |
| `ConnectionForm` | 编辑表单 |
| `TerminalSession` | 返回的会话对象 |
| `ContextMenuTrigger` | 右键菜单 |
| `TDesign` | TDLoading 加载动画 |

## 被引用

- `workflow.dart` — 作为连接管理面板内容嵌入 FloatingPanel / showPanelDialog
