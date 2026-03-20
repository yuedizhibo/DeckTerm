# clipboard_manager.dart

> 路径：`lib/function/clipboard/clipboard_manager.dart`

## 职责

跨平台（本地 Android/Windows <-> 远程 SFTP）文件剪贴板管理器。管理文件的复制、剪切状态，并在粘贴时分发到对应的执行路径。

## 核心内容

### 枚举

| 枚举 | 值 | 说明 |
|------|-----|------|
| `FileSourceType` | `local`, `remote` | 文件来源类型 |
| `ClipboardAction` | `copy`, `cut` | 剪贴板操作类型 |

### `FileClipboardItem` (数据类)
存储剪贴板中的文件信息：路径、来源类型、操作类型、文件名、是否目录、SFTP 实例（仅 remote 需要）。

### `FileClipboardManager` (单例, ChangeNotifier)

| 方法 | 说明 |
|------|------|
| `copyLocal(path, name, isDirectory)` | 复制本地文件到剪贴板 |
| `cutLocal(path, name, isDirectory)` | 剪切本地文件到剪贴板 |
| `copyRemote(path, name, isDirectory, sftpManager)` | 复制远程文件到剪贴板 |
| `cutRemote(path, name, isDirectory, sftpManager)` | 剪切远程文件到剪贴板 |
| `clear()` | 清空剪贴板 |
| `paste(targetPath, targetType, {targetSftp})` | 执行粘贴操作 |

### 粘贴场景分发

| 源 → 目标 | 实现 |
|-----------|------|
| 本地 → 本地 | `File.copy/rename` / `Directory` 递归复制 |
| 本地 → 远程 | 通过 `SftpManager.uploadFile` 上传，`TransferManager` 追踪进度 |
| 远程 → 本地 | 通过 `SftpManager.downloadFile` 下载，`TransferManager` 追踪进度 |
| 远程 → 远程 | 剪切用 `rename`，复制暂未实现（抛 `UnimplementedError`） |

### 已知限制
- 目录上传/下载暂未实现（抛出 `Exception`）。
- 不支持跨服务器远程粘贴。

## 依赖关系

- `SftpManager` — SFTP 文件操作
- `TransferManager` — 传输进度追踪
