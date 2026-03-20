# remote_file_manager.dart

> 路径：`lib/ui/main/widgets/remote_file_manager.dart`

## 职责

远程文件管理器组件。展示远程服务器的 SFTP 文件树，支持目录懒加载导航、文件操作（创建/删除/复制/剪切/粘贴）。

## 核心内容

### `RemoteFileManager` (StatefulWidget)

| 参数 | 类型 | 说明 |
|------|------|------|
| `session` | `TerminalSession?` | 当前活跃会话，null 时显示"未连接"占位 |

- 会话切换时自动重新初始化 SFTP 连接（`didUpdateWidget`）。
- 标题栏提供"重连"和"在根目录新建"按钮。

### 显示状态

| 状态 | UI |
|------|-----|
| 无会话 | 断连图标 + "未连接到设备" |
| 连接中 | TDLoading + "连接中..." |
| 连接失败 | 错误图标 + 错误信息 + "重试"按钮 |
| 已连接 | SFTP 文件树 |

### `_SftpDirectoryNode` (StatefulWidget)

- 根节点默认展开，显示为 `/`。
- 点击展开/折叠，懒加载子目录内容。
- 选中高亮（`SelectionManager`）。
- **上下文菜单**：刷新、粘贴（剪贴板有内容时显示，支持从本地上传）。

### `_SftpFileNode` (StatelessWidget)

- 文件类型图标（基于扩展名）+ 文件名 + 格式化大小。
- **上下文菜单**：复制、剪切、删除。

## 集成组件

| 组件 | 用途 |
|------|------|
| `SftpManager` | SFTP 文件操作 |
| `ContextMenuTrigger` | 右键/长按触发菜单 |
| `SelectionManager` | 文件选中高亮 |
| `FileClipboardManager` | 文件复制/剪切/粘贴 |
| `TransferManager` | 传输进度追踪 |
