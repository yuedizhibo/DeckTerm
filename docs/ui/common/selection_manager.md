# selection_manager.dart

> 路径：`lib/ui/common/selection_manager.dart`

## 职责

文件/目录选择状态管理器（单例，`ChangeNotifier`）。管理文件树中的单选高亮状态，区分本地和远程来源，避免两侧同时高亮。

## 核心内容

### `SelectionManager` (单例, ChangeNotifier)

| 方法/属性 | 说明 |
|----------|------|
| `selectedPath` | 当前选中的路径 |
| `sourceTag` | 选中项来源标识（`local` / `remote`） |
| `isSelected(path, tag)` | 判断指定路径和来源是否被选中 |
| `select(path, tag)` | 选中指定路径，自动取消之前的选中 |
| `clear()` | 清除选中状态 |

### 设计说明

- 全局唯一选中：一次只能选中一个文件/目录。
- `sourceTag` 区分来源，防止本地文件树和远程文件树同时显示高亮造成混淆。

## 被引用位置

- `file_tree_android.dart` — Android 文件树选中
- `file_tree_windows.dart` — Windows 文件树选中
- `remote_file_manager.dart` — 远程文件管理器选中
