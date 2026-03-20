# file_tree.dart

> 路径：`lib/ui/main/widgets/file_tree.dart`

## 职责

本地文件树的基础抽象与通用共享组件。提供文件节点数据模型和跨平台共享的快速访问区组件。

## 核心内容

### `QuickAccessEntry` (数据类)

快速访问入口数据模型，供 Windows 和 Android 平台文件树共用。

| 字段 | 类型 | 说明 |
|------|------|------|
| `label` | `String` | 显示名称 |
| `icon` | `IconData` | 图标 |
| `iconColor` | `Color?` | 图标颜色 |
| `path` | `String` | 完整路径 |

### `QuickAccessSectionHeader` (StatelessWidget)

快速访问分区标题组件。默认文字"快速访问"，11px 灰色文字，可自定义标题。统一两平台文件树的视觉风格。

### `FileNode` (数据类)

文件节点数据模型：名称、路径、是否目录、子节点列表、文件大小。提供 `formattedSize` 格式化字符串。

### `FileTreeBase` / `FileTreeBaseState` (抽象基类)

文件树抽象组件基类，包含加载逻辑和占位 UI。**当前两平台实现均未继承此基类，保留备用。**

## 被引用位置

- `file_tree_android.dart` — 使用 `QuickAccessEntry` 和 `QuickAccessSectionHeader`
- `file_tree_windows.dart` — 使用 `QuickAccessEntry` 和 `QuickAccessSectionHeader`
