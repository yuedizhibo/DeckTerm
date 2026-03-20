# connection_model.dart

> 路径：`lib/function/connect/connection_model.dart`

## 职责

定义连接配置的数据模型和相关枚举类型。

## 核心内容

### 枚举

| 枚举 | 值 | 说明 |
|------|-----|------|
| `ConnectionType` | `ssh`, `vnc` | 连接类型 |
| `AuthMethod` | `password`, `privateKey` | 认证方式 |

### `Connection` (数据类)

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 唯一标识 |
| `name` | `String` | 连接名称 |
| `type` | `ConnectionType` | 连接类型 |
| `host` | `String` | 主机地址 |
| `port` | `int` | 端口号 |
| `note` | `String?` | 备注 |
| `authMethod` | `AuthMethod` | 认证方式 |
| `username` | `String?` | 用户名 |
| `password` | `String?` | 密码 |
| `privateKeyPath` | `String?` | 私钥路径 |

支持 `toJson()`、`fromJson()`、`copyWith()` 方法。
