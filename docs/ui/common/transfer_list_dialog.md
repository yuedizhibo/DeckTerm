# transfer_list_dialog.dart

> 路径：`lib/ui/common/transfer_list_dialog.dart`

## 职责

传输列表面板内容组件（非模态），嵌入 FloatingPanel（Windows）或 showPanelDialog（Android）中使用。显示所有上传/下载任务的实时进度。

## 核心内容

### `TransferListPanel` (StatefulWidget)

- **三 Tab 过滤**：全部 / 上传 / 下载，使用 `TabController` + `TabBarView`。
- **实时更新**：`ListenableBuilder` 监听 `TransferManager` 状态变化。

### 任务卡片展示

每条任务显示：
- 类型图标（上传/下载）+ 文件名 + 状态文字（等待中/百分比/已完成/失败）
- 源路径 → 目标路径（10px 灰色文字）
- 进度条（3px，运行中或等待中时显示）
- 已传输/总大小（进度条下方）
- 错误信息（失败时，红色文字）
- 关闭按钮（已完成/失败任务可单条移除）

### 底部操作

- "清空已完成/失败"按钮：有已结束任务时显示，调用 `TransferManager().clearCompleted()`。

### 特殊处理

- `totalBytes==0` 且正在运行时视为大小未知，显示不确定进度条（`LinearProgressIndicator(value: null)`）。
- `_formatBytes()` 辅助方法：B → KB → MB → GB 自动格式化。

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `TransferManager` | 任务数据源（单例 ChangeNotifier） |

## 被引用

- `workflow.dart` — 作为传输列表面板内容嵌入 FloatingPanel / showPanelDialog
