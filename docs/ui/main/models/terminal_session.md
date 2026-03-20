# terminal_session.dart

> 路径：`lib/ui/main/models/terminal_session.dart`

## 职责

终端会话运行时数据模型。表示一个正在进行的 SSH 或 VNC 连接会话。

## 核心内容

### `TerminalType` (枚举)
- `ssh` — SSH 连接
- `vnc` — VNC 连接

### `TerminalSession` (数据类)

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 会话唯一标识（运行时生成） |
| `name` | `String` | 会话名称（标签显示用） |
| `type` | `TerminalType` | 会话类型 |
| `host` | `String` | 主机地址 |
| `port` | `int` | 端口（默认 22） |
| `username` | `String?` | 用户名 |
| `password` | `String?` | 密码 |
| `privateKeyPath` | `String?` | 私钥路径 |
| `isConnected` | `bool` | 是否已连接 |

计算属性：
- `connectionString` → `"host:port"`
- `typeDisplay` → `"SSH"` / `"VNC"`

支持 `toJson()` / `fromJson()` 序列化。

## 与 `Connection` 的关系

`Connection`（`connection_model.dart`）是持久化的配置模板，`TerminalSession` 是运行时的会话实例。同一个 `Connection` 可以创建多个 `TerminalSession`（通过不同的运行时 ID）。
