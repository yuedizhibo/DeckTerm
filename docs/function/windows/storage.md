# storage.dart (Windows)

> 路径：`lib/function/windows/storage.dart`

## 职责

Windows 平台的本地文件系统访问服务。提供驱动器列表、目录内容列表和快速访问路径等静态方法。

## 平台归属

**仅 Windows 使用**。Android 平台对应文件为 `lib/function/android/storage.dart`。

## API 说明

### `WindowsStorage` (静态类)

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `getDrives()` | `Future<List<Directory>>` | 遍历 A-Z 检测存在的磁盘驱动器 |
| `getQuickAccessPaths()` | `Map<String, String>` | 依赖 `USERPROFILE` 环境变量，返回 `{'桌面': ...\Desktop, '下载': ...\Downloads}` |
| `getDirectoryContent(path)` | `Future<List<FileSystemEntity>>` | 列出目录内容，文件夹在前、文件在后排序；权限不足时返回空列表 |

## 被引用位置

- `lib/ui/windows/file_tree_windows.dart` — Windows 本地文件树 UI
