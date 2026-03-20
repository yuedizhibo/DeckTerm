# device_info.dart

> 路径：`lib/ui/main/models/device_info.dart`

## 职责

设备状态数据模型。定义设备监控所需的状态枚举和信息结构。

## 核心内容

### `DeviceStatusType` (枚举)
- `connecting` — 连接中
- `connected` — 已连接
- `failed` — 连接失败

### `DeviceInfo` (数据类)

| 字段 | 类型 | 说明 |
|------|------|------|
| `ip` | `String` | IP 地址 |
| `name` | `String` | 设备名称（默认 "Device"） |
| `cpuUsage` | `double` | CPU 使用率（0.0 - 1.0） |
| `memoryUsage` | `double` | 内存使用率（0.0 - 1.0） |
| `status` | `DeviceStatusType` | 连接状态 |

计算属性：
- `cpuUsagePercent` → 格式化百分比字符串如 `"45.2%"`
- `memoryUsagePercent` → 格式化百分比字符串

## 被引用位置

- `DeviceMonitor` — 状态数据生产者
- `DeviceStatus` — UI 展示
- `WorkflowPage` — 状态流监听
