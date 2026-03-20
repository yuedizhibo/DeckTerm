# file_tree_android.dart

> 路径：`lib/ui/android/file_tree_android.dart`

## 职责

Android 平台的本地文件树 UI 组件。展示本地存储目录树，支持懒加载、快速访问、上下文菜单和文件剪贴板操作。

## 平台归属

**仅 Android 使用**。Windows 平台对应文件为 `lib/ui/windows/file_tree_windows.dart`。

## 核心内容

### `FileTreeAndroid` (StatefulWidget)
- 顶部显示"本地存储"标题和刷新按钮。
- **快速访问区**：由 `AndroidStorage.getQuickAccessPaths()` 提供路径，过滤不存在的目录，使用 `QuickAccessSectionHeader` 标题。
- 快速访问区下方显示内部存储根目录 (`/storage/emulated/0`)。
- 监听 `FileClipboardManager` 和 `SelectionManager` 状态变化触发 UI 更新。

### `_DirectoryNode` (StatefulWidget)
- 支持 `customIcon`/`customIconColor` 参数（快速访问入口图标定制）。
- 点击展开/折叠，首次展开时懒加载子目录内容。
- 选中高亮通过 `SelectionManager.isSelected()` 判断。
- 隐藏以 `.` 开头的文件/目录。
- **上下文菜单**（`ContextMenuTrigger`，右键/长按）：刷新、粘贴（剪贴板有内容时显示）。

### `_FileNode` (StatelessWidget)
- 显示文件名、文件类型图标（基于扩展名映射）和格式化大小。
- **上下文菜单**：复制、剪切。
- 选中高亮。

## 集成组件

| 组件 | 用途 |
|------|------|
| `ContextMenuTrigger` | 统一右键/长按触发菜单 |
| `SelectionManager` | 文件选中高亮管理 |
| `FileClipboardManager` | 文件复制/剪切/粘贴 |
| `AndroidStorage` | 文件系统数据获取 |
| `QuickAccessEntry` / `QuickAccessSectionHeader` | 快速访问区共享组件 |
