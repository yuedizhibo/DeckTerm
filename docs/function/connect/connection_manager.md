# connection_manager.dart

> 路径：`lib/function/connect/connection_manager.dart`

## 职责

连接配置的持久化管理器（单例）。负责通过 `shared_preferences` 存储、读取、添加、删除和更新用户的 SSH/VNC 连接配置。

## 核心内容

### `ConnectionManager` (单例)

| 方法 | 说明 |
|------|------|
| `loadConnections()` | 从 `shared_preferences` 读取 JSON 数据并反序列化为 `Connection` 列表 |
| `saveConnection(connection)` | 保存或更新连接配置（按 `id` 匹配） |
| `deleteConnection(id)` | 删除指定连接配置 |

- 存储键：`saved_connections`
- 序列化格式：JSON 数组

## 依赖关系

- `shared_preferences` — 本地持久化
- `connection_model.dart` — `Connection` 数据模型
