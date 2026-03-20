# context_menu_trigger.dart

> 路径：`lib/ui/common/context_menu_trigger.dart`

## 职责

统一的上下文菜单触发器组件。封装鼠标右键点击和触摸长按两种触发方式，在不同输入设备上提供一致的右键菜单体验。

## 核心内容

### `ContextMenuTrigger` (StatelessWidget)

| 参数 | 类型 | 说明 |
|------|------|------|
| `child` | `Widget` | 被包裹的子组件 |
| `onTrigger` | `Function(Offset position)` | 菜单触发回调，参数为全局坐标 |

### 触发方式

| 输入方式 | 实现 | 说明 |
|---------|------|------|
| 鼠标右键 | `Listener.onPointerDown` + `kSecondaryMouseButton` | 检测鼠标右键按下 |
| 触摸长按 | `GestureDetector.onLongPressStart` | 触摸屏长按 |
| 其他设备 secondary tap | `onSecondaryTapUp` | 兼容触控板等非鼠标设备 |

## 被引用位置

- `file_tree_android.dart` — Android 文件树
- `file_tree_windows.dart` — Windows 文件树
- `remote_file_manager.dart` — 远程文件管理器
- `terminal_tabs.dart` — 标签页右键菜单
- `connection_manager_dialog.dart` — 连接列表右键菜单
