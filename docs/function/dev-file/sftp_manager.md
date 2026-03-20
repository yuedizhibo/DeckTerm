# sftp_manager.dart

> 路径：`lib/function/dev-file/sftp_manager.dart`

## 职责

SFTP 文件操作管理器。封装 `dartssh2` 的 SFTP 功能，管理独立的 SSH+SFTP 连接，提供远程文件的增删改查操作。

## 核心内容

### `SftpManager`

| 方法 | 说明 |
|------|------|
| `connect()` | 建立独立 SSH 连接并初始化 SFTP 会话 |
| `listDirectory(path, {useCache})` | 获取目录列表，支持内存缓存，目录在前文件在后排序 |
| `clearCache(path)` | 清除指定路径的缓存 |
| `createDirectory(path)` | 创建远程目录，清除全部缓存 |
| `delete(path, {isDirectory})` | 删除远程文件或目录 |
| `uploadFile(remotePath, stream, {onProgress})` | 流式上传文件 |
| `downloadFile(remotePath, sink, {onProgress})` | 流式下载文件 |
| `rename(oldPath, newPath)` | 移动/重命名远程文件 |
| `copyRemote(src, dst, isDir)` | 远程复制（**未实现**，抛 `UnimplementedError`） |
| `dispose()` | 断开连接，清除缓存 |

### 关键实现细节

- **上传偏移追踪**：`dartssh2` 的 `writeBytes` 默认 `offset=0`，必须手动维护 `writeOffset` 递增，否则所有 chunk 写入同一位置导致文件内容丢失。
- **目录缓存**：`Map<String, List<SftpName>>`，`listDirectory` 默认使用缓存，写操作（create/delete/rename/upload）后清除全部缓存。
- **连接自动恢复**：每个操作前检查 `isConnected`，断开时自动重连。

## 依赖关系

- `dartssh2` — SSH/SFTP 客户端
- `TerminalSession` — 连接配置信息
