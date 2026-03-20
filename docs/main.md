# main.dart

> 路径：`lib/main.dart`

## 职责

应用程序入口文件，负责初始化 Flutter 应用、Windows 窗口管理器配置、全局主题设定和 Android 权限检查。

## 核心内容

### `main()` 函数
- 设置 `kTextForceVerticalCenterEnable = false`，修复 Flutter 3.16+ 下 TDesign 组件文字垂直偏移问题。
- **Windows 平台**：通过 `window_manager` 初始化自定义无标题栏窗口（`TitleBarStyle.hidden`），默认尺寸 1280×720，最小尺寸 800×600，居中显示。
- 调用 `runApp(MyApp())` 启动应用。

### `MyApp` (StatelessWidget)
- 配置 `MaterialApp`，标题为 "DeckTerm"，关闭 Debug 横幅。
- 主题配置：
  - `ColorScheme.fromSeed(seedColor: Color(0xFF3B82F6), brightness: Brightness.dark)` + Material 3 暗色主题。
  - 脚手架背景色 `0xFF0F1419`。
  - 自定义 `PopupMenuThemeData`：10px 圆角、8% 白色边框、深色背景 `0xFF1E2530`。
  - `ThemeExtension`：挂载 `TDThemeData.defaultData()` 使 `TDTheme.of(context)` 全局可用。
- 首页为 `PermissionCheckWrapper`。

### `PermissionCheckWrapper` (StatefulWidget)
- **非 Android 平台**：直接跳过权限检查，进入 `WorkflowPage`。
- **Android 平台**：
  1. 优先检查/请求 `manageExternalStorage` 权限（Android 11+ 全文件访问）。
  2. 降级检查/请求 `storage` 权限（Android 10 及以下）。
  3. 权限获取失败时显示引导页面：错误图标 + 说明文字 + "去授权"按钮（跳转系统设置）。
  4. 权限检查中显示 TDesign 加载动画。

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `permission_handler` | Android 存储权限请求 |
| `tdesign_flutter` | UI 组件（TDLoading, TDButton, TDText 等）+ 字体修复 |
| `window_manager` | Windows 自定义无标题栏窗口管理 |
| `ui/main/workflow.dart` | 权限通过后进入的主界面 |

## 平台适配

| 平台 | 行为 |
|------|------|
| Android | 执行存储权限检查流程 |
| Windows | 初始化 window_manager 自定义窗口，跳过权限检查 |
| 其他 | 跳过权限检查，直接进入主界面 |
