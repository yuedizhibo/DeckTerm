# transfer_manager.dart

> 路径：`lib/function/transfer/transfer_manager.dart`

## 职责

文件传输任务管理器（单例，`ChangeNotifier`）。统一管理文件上传/下载的任务队列和进度状态，供 UI 层监听并展示。

## 核心内容

### 枚举

| 枚举 | 值 | 说明 |
|------|-----|------|
| `TransferType` | `upload`, `download` | 传输类型 |
| `TransferStatus` | `pending`, `running`, `completed`, `failed` | 任务状态 |

### `TransferTask` (数据类)

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 基于微秒时间戳的唯一标识 |
| `name` | `String` | 文件名 |
| `sourcePath` | `String` | 源路径 |
| `destPath` | `String` | 目标路径 |
| `type` | `TransferType` | 传输类型 |
| `totalBytes` | `int` | 总字节数（0 表示未知） |
| `transferredBytes` | `int` | 已传输字节数 |
| `status` | `TransferStatus` | 当前状态 |
| `error` | `String?` | 错误信息 |
| `progress` | `double` | 计算属性：已传输/总字节 |

### `TransferManager` (单例, ChangeNotifier)

| 方法 | 说明 |
|------|------|
| `addTask(name, source, dest, type, totalBytes)` | 创建新任务，状态为 `pending` |
| `updateProgress(taskId, transferred)` | 更新已传输字节数，状态变为 `running` |
| `completeTask(taskId)` | 标记完成，8 秒后自动从列表移除 |
| `failTask(taskId, error)` | 标记失败并记录错误信息 |
| `removeTask(taskId)` | 手动移除单条任务 |
| `clearCompleted()` | 批量移除所有已完成或失败的任务 |

## 被引用位置

- `ClipboardManager` — 上传/下载时创建和更新任务
- `TransferListDialog` — UI 展示任务列表
- `TransferProgressWidget` — 内嵌进度条（备用）
- `WorkflowPage` — AppBar 角标显示活跃任务数
