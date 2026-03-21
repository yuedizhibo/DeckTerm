# settings_manager.dart

> 路径：`lib/setting/settings_manager.dart`

## 职责

全局设置管理器（单例，`ChangeNotifier`）。管理终端和连接相关的用户偏好设置，持久化到 `SharedPreferences`，各 UI 组件通过监听实时响应变更。

## 核心内容

### `SettingsManager` (单例, ChangeNotifier)

| 设置项 | 类型 | 默认值 | 持久化键 |
|--------|------|--------|----------|
| `fontSize` | `double` | 14.0 | `setting_font_size` |
| `cursorBlink` | `bool` | true | `setting_cursor_blink` |
| `scrollbackLines` | `int` | 10000 | `setting_scrollback_lines` |
| `keepAliveSeconds` | `int` | 30 | `setting_keep_alive_seconds` |
| `autoReconnect` | `bool` | true | `setting_auto_reconnect` |

| 方法 | 说明 |
|------|------|
| `load()` | 从 SharedPreferences 读取所有设置，通知监听者 |
| `setFontSize(v)` | 更新字号，通知监听者，异步持久化 |
| `setCursorBlink(v)` | 更新光标闪烁，通知监听者，异步持久化 |
| `setScrollbackLines(v)` | 更新回滚行数，通知监听者，异步持久化 |
| `setKeepAliveSeconds(v)` | 更新 KeepAlive 间隔，通知监听者，异步持久化 |
| `setAutoReconnect(v)` | 更新断线自动重连，通知监听者，异步持久化 |

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `shared_preferences` | 设置持久化 |

## 被引用位置

- `main.dart` — 启动时 `load()` 加载设置
- `settings_panel.dart` — 设置面板 UI 读写
- `ssh_terminal_view.dart` — 终端字号、光标闪烁、回滚行数
