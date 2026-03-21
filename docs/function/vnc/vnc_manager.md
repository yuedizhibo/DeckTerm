# vnc_manager.dart

> 路径：`lib/function/vnc/vnc_manager.dart`

## 职责

VNC 连接管理器。纯 Dart 实现 RFB 3.8 协议最小子集，提供 VNC 远程桌面的连接、认证、帧缓冲接收和输入事件发送功能。

## 核心内容

### `VncManager`

| 方法/属性 | 说明 |
|----------|------|
| `connect()` | 完成 RFB 握手、安全协商、认证、ServerInit，分配帧缓冲 |
| `sendKeyEvent(keysym, down)` | 发送 RFB KeyEvent（X11 keysym） |
| `sendPointerEvent(x, y, buttonMask)` | 发送 RFB PointerEvent（鼠标/触摸） |
| `requestFrameUpdate({incremental})` | 发送 FramebufferUpdateRequest |
| `statusStream` | `Stream<VncStatus>` 连接状态广播 |
| `frameStream` | `Stream<void>` 帧更新通知 |
| `frameBuffer` | `Uint8List?` 当前帧缓冲数据（BGRA 格式） |
| `fbWidth` / `fbHeight` | 帧缓冲尺寸 |
| `dispose()` | 关闭 Socket，释放资源 |

### RFB 协议实现

| 阶段 | 说明 |
|------|------|
| 版本握手 | 发送 `RFB 003.008\n`，解析服务器版本 |
| 安全协商 | 支持 None(1) 和 VNC Authentication(2) |
| VNC 认证 | DES challenge-response，内置 `_DES` 加密实现 |
| ClientInit | shared=true，允许多客户端 |
| ServerInit | 解析屏幕尺寸和名称 |
| SetPixelFormat | 请求 32bpp BGRA |
| SetEncodings | Raw(0) + CopyRect(1) |
| 消息循环 | 处理 FramebufferUpdate、Bell、ServerCutText |

### 帧缓冲编码

| 编码 | 说明 |
|------|------|
| Raw(0) | 直接像素数据，逐行复制到帧缓冲 |
| CopyRect(1) | 服务器端矩形复制，使用临时缓冲区避免重叠问题 |

### `VncStatus` 枚举

- `disconnected` — 未连接
- `connecting` — 连接中
- `connected` — 已连接
- `failed` — 连接失败

### `_DES` (内部类)

最小 DES ECB 加密实现，仅用于 VNC Authentication 的 16 字节 challenge-response。包含完整的 S-box、置换表和 Feistel 网络。VNC 密码的每字节位序反转（`_reverseBits`）。

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `dart:io` | TCP Socket |
| `dart:typed_data` | 字节操作 |
| `TerminalSession` | 连接配置信息 |

## 被引用位置

- `vnc_desktop_view.dart` — VNC 桌面渲染视图
