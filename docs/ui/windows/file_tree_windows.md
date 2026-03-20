# file_tree_windows.dart

> 路径：`lib/ui/windows/file_tree_windows.dart`

## 职责

Windows 平台的本地文件树 UI 组件。展示驱动器列表和文件目录树，支持懒加载、快速访问、上下文菜单和文件剪贴板操作。

## 平台归属

**仅 Windows 使用**。Android 平台对应文件为 `lib/ui/android/file_tree_android.dart`。

## 核心内容

### `FileTreeWindows` (StatefulWidget)
- 顶部显示"此电脑"标题。
- **快速访问区**：由 `WindowsStorage.getQuickAccessPaths()` 提供路径，过滤不存在的目录。桌面图标 `TDIcons.desktop`，下载图标 `TDIcons.download`。
- **驱动器列表**：A-Z 驱动器，使用 `TDIcons.server` 图标。
- 监听 `FileClipboardManager` 和 `SelectionManager` 状态变化。

### `_DirectoryNode` (StatefulWidget)
- 支持 `customIcon`/`customIconColor` 参数。
- 点击展开/折叠，首次展开时懒加载子目录内容。
- 选中高亮通过 `SelectionManager.isSelected()` 判断。
- **上下文菜单**（`ContextMenuTrigger`，鼠标右键）：刷新、粘贴。

### `_FileNode` (StatelessWidget)
- 文件类型图标映射（代码、图片、文档、音视频、压缩包等）。
- **上下文菜单**：复制、剪切、打开（**占位**）、属性（**占位**）。
- 选中高亮。

## 集成组件

| 组件 | 用途 |
|------|------|
| `ContextMenuTrigger` | 鼠标右键触发菜单 |
| `SelectionManager` | 文件选中高亮管理 |
| `FileClipboardManager` | 文件复制/剪切/粘贴 |
| `WindowsStorage` | 文件系统数据获取 |
| `QuickAccessEntry` / `QuickAccessSectionHeader` | 快速访问区共享组件 |
