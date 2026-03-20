# storage.dart (Android)

> 路径：`lib/function/android/storage.dart`

## 职责

Android 平台的本地文件系统访问服务。提供根目录获取、目录内容列表、快速访问路径和文件名提取等静态方法。

## 平台归属

**仅 Android 使用**。Windows 平台对应文件为 `lib/function/windows/storage.dart`。

## API 说明

### `AndroidStorage` (静态类)

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `getRootDirectories()` | `Future<List<FileSystemEntity>>` | 返回主存储根目录 `/storage/emulated/0`，不存在时返回空列表 |
| `getQuickAccessPaths()` | `Map<String, String>` | 返回快速访问路径映射，如 `{'下载': '/storage/emulated/0/Download'}` |
| `getDirectoryContent(path)` | `Future<List<FileSystemEntity>>` | 列出指定目录内容，文件夹在前、文件在后，按名称排序；权限不足时返回空列表 |
| `getName(path)` | `String` | 提取路径末尾的文件/目录名 |

## 被引用位置

- `lib/ui/android/file_tree_android.dart` — Android 本地文件树 UI
