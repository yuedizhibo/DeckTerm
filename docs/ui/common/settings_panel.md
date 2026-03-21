# settings_panel.dart

> 路径：`lib/ui/common/settings_panel.dart`

## 职责

设置面板内容组件，嵌入 FloatingPanel（Windows）或 showPanelDialog（Android）中使用。提供外观、终端、连接、关于四个分区的设置项。

## 核心内容

### `SettingsPanel` (StatefulWidget)

以 `ListView` 呈现设置项，分为四个卡片区域：

#### 外观设置

| 设置项 | 控件 | 说明 |
|--------|------|------|
| 主题模式 | `_ThemeRow` 按钮组 | 深色/浅色切换，通过 `ThemeProvider.instance.toggle()` 实时生效并持久化 |

#### 终端设置

| 设置项 | 控件 | 范围/说明 |
|--------|------|-----------|
| 字号 | `_SliderRow` | 10~24，步进 1 |
| 光标闪烁 | `_SwitchRow` | 开/关 |
| 回滚行数 | `_SliderRow` | 1000~100000，步进 1000，显示为 K 格式（如 `10K`） |

#### 连接设置

| 设置项 | 控件 | 范围/说明 |
|--------|------|-----------|
| KeepAlive 间隔 | `_SliderRow` | 0~120，步进 5，显示为 `Ns` |
| 断线自动重连 | `_SwitchRow` | 开/关 |

#### 关于

| 项目 | 值 |
|------|------|
| 版本 | v1.0.0（蓝色 accent 标签） |
| 平台 | Flutter · Dart |
| SSH | dartssh2 |
| 终端 | xterm-256color |
| Logo | 蓝紫渐变图标 + "SSH 终端 + 文件管理器" 描述 |

### 内部组件

| 组件 | 说明 |
|------|------|
| `_ThemeRow` | 主题模式切换行，包含深色/浅色双按钮（`_ThemeChip`），选中态蓝色高亮 |
| `_ThemeChip` | 主题按钮（图标 + 文字），选中时 accent 15% 背景 |
| `_SettingsCard` | 分组设置卡片容器（图标 + 标题 + 内容列表，圆角 10px + 细边框） |
| `_SwitchRow` | 开关设置行（标签 + 缩小版 Switch，高度 20px） |
| `_SliderRow` | 滑块设置行（标签 + accent 数值标签 + 纤细滑块，轨道高度 2px） |

### 状态说明

当前终端和连接设置值为临时本地状态（`_fontSize`、`_cursorBlink` 等），后续将接入 `SettingsManager` 实现持久化。外观主题切换已通过 `ThemeProvider` 实现持久化。

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `setting/app_theme.dart` | `AppColors.of(context)` 获取主题色，`ThemeProvider.instance` 主题切换 |

## 被引用

- `workflow.dart` — 作为设置面板内容嵌入 FloatingPanel / showPanelDialog
