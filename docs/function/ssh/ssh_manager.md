# ssh_manager.dart

> 路径：`lib/function/ssh/ssh_manager.dart`

## 职责

SSH Shell 会话管理器。封装 `dartssh2`，负责建立 SSH 连接、认证、管理 Shell 会话，提供输入输出流接口。

## 核心内容

### `_TcpNoDelaySocket` (SSHSocket 实现)

自定义 TCP Socket，设置 `TCP_NODELAY=true` 禁用 Nagle 算法。

**问题根因**：Nagle 算法 + TCP 延迟 ACK 的叠加效应导致 ~500ms 交互延迟。
- 用户输入 'a' → 立即发出（无在途数据）
- 服务器 echo 回来 → 客户端 OS 延迟 ACK（40~500ms）
- 用户输入 'b' → Nagle 检测到有未确认数据 → 憋住不发
- 延迟 ACK 超时后才发 ACK → Nagle 放行 'b'

**修复**：`TCP_NODELAY=true` 彻底绕开 Nagle，每个字节立即发送。

### `SshManager`

| 方法/属性 | 说明 |
|----------|------|
| `connect()` | 建立 SSH 连接、认证、打开 Shell 会话 |
| `write(data)` | 向 Shell 写入数据 |
| `resize(width, height)` | 调整终端窗口大小 |
| `output` | `Stream<String>` SSH 输出流 |
| `dispose()` | 关闭 Shell 和连接 |

### 关键技术细节

- **PTY 类型**：`xterm-256color`，确保服务端正确识别终端能力。
- **UTF-8 容错**：`Utf8Decoder(allowMalformed: true)` 防止流式数据在字节序列边界截断时抛异常。
- **同步广播**：`StreamController.broadcast(sync: true)` 同步派发输出，消除微任务调度延迟。
- **调试日志**：发送和接收数据时打印时间戳，便于排查延迟问题。

## 依赖关系

- `dartssh2` — SSH 客户端
- `TerminalSession` — 连接配置信息
