# settings_panel.dart

> 路径：`lib/ui/common/settings_panel.dart`

## 职责

设置面板内容组件，嵌入 FloatingPanel（Windows）或 showPanelDialog（Android）中使用。提供终端、连接、关于三个分区的设置项。

## 核心内容

### `SettingsPanel` (StatefulWidget)

以 `ListView` 呈现设置项，分为三个区域：

#### 终端设置

| 设置项 | 控件 | 范围/说明 |
|--------|------|-----------|
| 字号 | Slider | 10~24，步进 1 |
| 光标闪烁 | Switch | 开/关 |
| 回滚行数 | Slider | 1000~100000，步进 1000 |

#### 连接设置

| 设置项 | 控件 | 范围/说明 |
|--------|------|-----------|
| KeepAlive (秒) | Slider | 0~120，步进 5 |
| 断线自动重连 | Switch | 开/关 |

#### 关于

| 项目 | 值 |
|------|------|
| 版本 | 1.0.0 |
| 框架 | Flutter |

### 内部组件

| 组件 | 说明 |
|------|------|
| `_SectionHeader` | 分区标题（小号灰色大写字母风格） |
| `_SwitchTile` | 开关设置行（图标 + 标签 + Switch） |
| `_SliderTile` | 滑块设置行（图标 + 标签 + 数值标签 + Slider） |
| `_InfoTile` | 只读信息行（图标 + 标签 + 值） |
| `_TileContainer` | 统一的设置行容器（3% 白色背景 + 圆角 + 细边框） |

### 状态说明

当前所有设置值为临时本地状态（`_fontSize`、`_cursorBlink` 等），后续将接入 `SettingsManager` 实现持久化。

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `flutter/material.dart` | Widget 基础 |

## 被引用

- `workflow.dart` — 作为设置面板内容嵌入 FloatingPanel / showPanelDialog
