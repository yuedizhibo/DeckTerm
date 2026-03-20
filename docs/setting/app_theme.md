# app_theme.dart

> 路径：`lib/setting/app_theme.dart`

## 职责

统一的主题系统，通过 `ThemeExtension` 为全应用提供语义化色彩 Token，支持深色/浅色模式切换与持久化。

## 核心内容

### `AppColors` (ThemeExtension)

定义 20+ 语义色彩 Token，消除 UI 层硬编码色值：

| Token | 深色值 | 浅色值 | 用途 |
|-------|--------|--------|------|
| `scaffold` | `#0F1419` | `#F2F4F7` | 最底层背景 |
| `titleBar` | `#131820` | `#FFFFFF` | 标题栏背景 |
| `surface` | `#151B24` | `#FFFFFF` | 次级容器表面 |
| `panelBg` | `#1A1F2E` (92%) | `#F6F7F9` (94%) | 浮动面板背景 |
| `menuBg` | `#1E2530` | `#FFFFFF` | 弹出菜单背景 |
| `accent` | `#3B82F6` | `#3B82F6` | 主强调色 |
| `text1/2/3` | white 70/54/30% | 深色三级 | 文字层级 |

**快捷获取**：`AppColors.of(context)` 静态方法。

**插值支持**：`lerp()` 方法实现主题切换平滑过渡动画。

### `ThemeProvider` (ChangeNotifier 单例)

- `load()`：从 `SharedPreferences` 读取 `theme_is_dark`。
- `toggle()`：切换深色/浅色，通知监听者并持久化。
- `isDark` / `themeMode` getter。

### `buildAppTheme(Brightness, List<ThemeExtension>)`

工厂函数，根据亮度生成完整 `ThemeData`，包含 `AppColors` 和外部传入的扩展（如 TDesign）。

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `shared_preferences` | 主题偏好持久化 |

## 被引用

- `main.dart` — 初始化 ThemeProvider，构建 dark/light ThemeData
- `workflow.dart`、`floating_panel.dart`、`settings_panel.dart`、`transfer_list_dialog.dart`、`connection_manager_dialog.dart` — 通过 `AppColors.of(context)` 获取主题色
