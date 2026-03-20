# device_monitor.dart

> 路径：`lib/function/monitor/device_monitor.dart`

## 职责

设备状态监控器（单例）。为每个已连接主机维护独立的监控 SSH 连接，定时轮询 CPU 和内存使用率，通过 Stream 广播状态更新。

## 核心内容

### `DeviceMonitor` (单例)

| 方法 | 说明 |
|------|------|
| `addDevice(session)` | 注册设备监控，首个会话触发连接建立和轮询启动 |
| `removeDevice(sessionId)` | 注销会话引用，最后一个会话断开时自动清理连接 |
| `statusStream` | `Stream<Map<String, DeviceInfo>>` 广播状态更新 |
| `dispose()` | 关闭所有连接和定时器 |

### 引用计数机制
- `Map<host, Set<sessionId>>`：同一主机的多个会话共享一个监控连接。
- 第一个会话接入时建立独立 SSH 连接并启动 5 秒轮询。
- 最后一个会话断开时自动停止轮询并关闭连接。

### 轮询实现
- 执行命令读取 `/proc/stat`（CPU 使用率）和 `free`（内存使用率）。
- 解析命令输出为百分比数值。

### 容错机制

| 场景 | 行为 |
|------|------|
| 连接失败 | 标记 `failed` 状态，1 秒后自动重连 |
| 命令执行失败 | 标记 `failed` 状态，1 秒后重试单次查询 |
| 连接断开 | 停止轮询，触发重连流程 |

- `_reconnecting` Set：防止对同一 host 并发发起多次连接。
- `_retryingPoll` Set：防止在 5 秒轮询窗口内重复积累重试。

## 依赖关系

- `dartssh2` — 独立的监控 SSH 连接
- `DeviceInfo` — 状态数据模型
- `TerminalSession` — 连接配置信息
