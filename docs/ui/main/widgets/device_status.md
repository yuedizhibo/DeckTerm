# device_status.dart

> 路径：`lib/ui/main/widgets/device_status.dart`

## 职责

设备状态监控卡片组件。位于主界面左上角，使用 TabBar/TabBarView 展示多个活跃连接设备的实时 CPU/内存状态。

## 核心内容

### `DeviceStatus` (StatefulWidget + TickerProviderStateMixin)

| 参数 | 类型 | 说明 |
|------|------|------|
| `devices` | `Map<String, DeviceInfo>` | 设备状态映射（IP → DeviceInfo） |

### 显示状态

| 状态 | UI |
|------|-----|
| 无设备 | 占位页面：等待连接、CPU/内存均 0% |
| connecting | TDLoading 加载动画 + "连接中..." |
| failed | 错误图标 + "状态查询失败" |
| connected | IP 地址行 + CPU 进度条 + 内存进度条 |

### 进度条样式

- `strokeWidth: 20`（加粗）
- 颜色随使用率变化：
  - <50%：绿色（success）
  - 50%~75%：黄色（warning）
  - >75%：红色（error）

### Tab 管理

- 按设备 IP 排序生成 Tab。
- `didUpdateWidget` 中检测设备列表变化，动态更新 `TabController`。

## 依赖关系

- `DeviceInfo` — 数据模型
- `TDesign` — TDProgress, TDLoading, TDText 等
