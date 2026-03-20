# connection_form.dart

> 路径：`lib/ui/connect/connection_form.dart`

## 职责

连接编辑表单组件。提供 SSH/VNC 连接配置的新建和编辑界面，使用 TDesign 组件构建。

## 核心内容

### `ConnectionForm` (StatefulWidget)

| 参数 | 类型 | 说明 |
|------|------|------|
| `connection` | `Connection?` | 编辑模式传入已有配置，新建时为 null |
| `onSave` | `ValueChanged<Connection>` | 保存回调，返回 `Connection` 对象 |

### 表单字段

| 分区 | 字段 | 说明 |
|------|------|------|
| 常规 | 类型 | 下拉选择 SSH/VNC |
| 常规 | 名称 | 连接名称（必填） |
| 常规 | 主机 + 端口 | IP/域名 + 端口号（默认 22） |
| 常规 | 备注 | 多行文本 |
| 认证 | 方法 | 下拉选择 密码/私钥 |
| 认证 | 用户名 | |
| 认证 | 密码 | 密码模式时显示（obscureText） |
| 认证 | 私钥路径 | 私钥模式时显示 + "浏览..."按钮（**未实现**） |

### 验证

- 名称和主机为必填，为空时 `TDToast.showText` 提示。
- 新建时 `id` 使用 `DateTime.now().millisecondsSinceEpoch` 生成。

## 依赖关系

- `Connection` — 数据模型
- `TDesign` — UI 组件（TDInput, TDButton, DropdownButton）
