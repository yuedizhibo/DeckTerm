import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../function/vnc/vnc_manager.dart';
import '../../../setting/app_theme.dart';
import '../models/terminal_session.dart';

/// VNC 远程桌面视图
class VncDesktopView extends StatefulWidget {
  final TerminalSession session;

  const VncDesktopView({super.key, required this.session});

  @override
  State<VncDesktopView> createState() => _VncDesktopViewState();
}

class _VncDesktopViewState extends State<VncDesktopView>
    with AutomaticKeepAliveClientMixin {
  late final VncManager _vnc;
  ui.Image? _currentImage;
  StreamSubscription? _frameSub;
  StreamSubscription? _statusSub;
  VncStatus _status = VncStatus.disconnected;
  String? _error;
  final FocusNode _focusNode = FocusNode();

  // 触摸/鼠标状态
  int _buttonMask = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _vnc = VncManager(widget.session);
    _statusSub = _vnc.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _frameSub = _vnc.frameStream.listen((_) => _updateImage());
    _connect();
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    _statusSub?.cancel();
    _focusNode.dispose();
    _vnc.dispose();
    _currentImage?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _status = VncStatus.connecting;
      _error = null;
    });
    try {
      await _vnc.connect();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _updateImage() async {
    final fb = _vnc.frameBuffer;
    if (fb == null || _vnc.fbWidth == 0 || _vnc.fbHeight == 0) return;

    // 将 BGRA 转换为 RGBA（Flutter ui.Image 需要 RGBA）
    final rgba = Uint8List(fb.length);
    for (int i = 0; i < fb.length; i += 4) {
      rgba[i] = fb[i + 2];     // R <- B位置的值实际是R（SetPixelFormat里red-shift=16）
      rgba[i + 1] = fb[i + 1]; // G
      rgba[i + 2] = fb[i];     // B <- R位置的值实际是B
      rgba[i + 3] = fb[i + 3]; // A
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      _vnc.fbWidth,
      _vnc.fbHeight,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );

    final img = await completer.future;
    if (mounted) {
      _currentImage?.dispose();
      setState(() => _currentImage = img);
    } else {
      img.dispose();
    }
  }

  // ── 键盘事件 → VNC keysym ──

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final keysym = _logicalKeyToKeysym(event.logicalKey);
      if (keysym != null) {
        _vnc.sendKeyEvent(keysym, true);
        // 可打印字符也要发 key-up
        if (event is KeyDownEvent) {
          Future.microtask(() => _vnc.sendKeyEvent(keysym, false));
        }
        return true;
      }
    } else if (event is KeyUpEvent) {
      final keysym = _logicalKeyToKeysym(event.logicalKey);
      if (keysym != null) {
        _vnc.sendKeyEvent(keysym, false);
        return true;
      }
    }
    return false;
  }

  int? _logicalKeyToKeysym(LogicalKeyboardKey key) {
    // 常用键映射到 X11 keysym
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) return 0xff0d;
    if (key == LogicalKeyboardKey.backspace) return 0xff08;
    if (key == LogicalKeyboardKey.tab) return 0xff09;
    if (key == LogicalKeyboardKey.escape) return 0xff1b;
    if (key == LogicalKeyboardKey.delete) return 0xffff;
    if (key == LogicalKeyboardKey.arrowUp) return 0xff52;
    if (key == LogicalKeyboardKey.arrowDown) return 0xff54;
    if (key == LogicalKeyboardKey.arrowLeft) return 0xff51;
    if (key == LogicalKeyboardKey.arrowRight) return 0xff53;
    if (key == LogicalKeyboardKey.home) return 0xff50;
    if (key == LogicalKeyboardKey.end) return 0xff57;
    if (key == LogicalKeyboardKey.pageUp) return 0xff55;
    if (key == LogicalKeyboardKey.pageDown) return 0xff56;
    if (key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight) return 0xffe1;
    if (key == LogicalKeyboardKey.controlLeft || key == LogicalKeyboardKey.controlRight) return 0xffe3;
    if (key == LogicalKeyboardKey.altLeft || key == LogicalKeyboardKey.altRight) return 0xffe9;
    if (key == LogicalKeyboardKey.space) return 0x20;

    // F 键
    if (key.keyId >= LogicalKeyboardKey.f1.keyId && key.keyId <= LogicalKeyboardKey.f12.keyId) {
      return 0xffbe + (key.keyId - LogicalKeyboardKey.f1.keyId);
    }

    // ASCII 可打印字符
    if (key.keyLabel.length == 1) {
      return key.keyLabel.codeUnitAt(0);
    }

    return null;
  }

  // ── 鼠标/触摸事件 → VNC ──

  Offset _toVncCoords(Offset local, Size widgetSize) {
    if (_vnc.fbWidth == 0 || _vnc.fbHeight == 0) return Offset.zero;
    final scaleX = _vnc.fbWidth / widgetSize.width;
    final scaleY = _vnc.fbHeight / widgetSize.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final renderW = _vnc.fbWidth / scale;
    final renderH = _vnc.fbHeight / scale;
    final offsetX = (widgetSize.width - renderW) / 2;
    final offsetY = (widgetSize.height - renderH) / 2;
    return Offset(
      ((local.dx - offsetX) * scale).clamp(0, _vnc.fbWidth - 1),
      ((local.dy - offsetY) * scale).clamp(0, _vnc.fbHeight - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);

    if (_status == VncStatus.connecting) {
      return Container(
        color: c.scaffold,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              const SizedBox(height: 16),
              Text('连接 VNC 服务器...', style: TextStyle(color: c.text2, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_status == VncStatus.failed || _status == VncStatus.disconnected) {
      return Container(
        color: c.scaffold,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.desktop_access_disabled_rounded, size: 48, color: c.text3),
              const SizedBox(height: 16),
              Text(
                _error ?? (_status == VncStatus.failed ? 'VNC 连接失败' : '未连接'),
                style: TextStyle(color: c.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _connect,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.accent.withOpacity(0.3)),
                  ),
                  child: Text('重试', style: TextStyle(color: c.accent, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 已连接 - 显示桌面
    return Focus(
      focusNode: _focusNode,
      autofocus: !Platform.isAndroid,
      onKeyEvent: (_, event) => _handleKeyEvent(event)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Listener(
            onPointerDown: (e) {
              _focusNode.requestFocus();
              final pos = _toVncCoords(e.localPosition, constraints.biggest);
              if (e.buttons & 0x01 != 0) _buttonMask |= 1; // 左键
              if (e.buttons & 0x02 != 0) _buttonMask |= 4; // 右键
              if (e.buttons & 0x04 != 0) _buttonMask |= 2; // 中键
              _vnc.sendPointerEvent(pos.dx.toInt(), pos.dy.toInt(), _buttonMask);
            },
            onPointerMove: (e) {
              final pos = _toVncCoords(e.localPosition, constraints.biggest);
              _vnc.sendPointerEvent(pos.dx.toInt(), pos.dy.toInt(), _buttonMask);
            },
            onPointerUp: (e) {
              final pos = _toVncCoords(e.localPosition, constraints.biggest);
              _buttonMask = 0;
              _vnc.sendPointerEvent(pos.dx.toInt(), pos.dy.toInt(), 0);
            },
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                final pos = _toVncCoords(e.localPosition, constraints.biggest);
                // 滚轮：button 4(上) / 5(下)
                final btn = e.scrollDelta.dy < 0 ? 8 : 16;
                _vnc.sendPointerEvent(pos.dx.toInt(), pos.dy.toInt(), btn);
                _vnc.sendPointerEvent(pos.dx.toInt(), pos.dy.toInt(), 0);
              }
            },
            child: GestureDetector(
              // Android 长按模拟右键
              onLongPressStart: Platform.isAndroid ? (d) {
                final pos = _toVncCoords(d.localPosition, constraints.biggest);
                _vnc.sendPointerEvent(pos.dx.toInt(), pos.dy.toInt(), 4);
                _vnc.sendPointerEvent(pos.dx.toInt(), pos.dy.toInt(), 0);
              } : null,
              child: Container(
                color: Colors.black,
                child: _currentImage != null
                    ? CustomPaint(
                        size: constraints.biggest,
                        painter: _VncPainter(_currentImage!),
                      )
                    : Center(
                        child: Text(
                          '等待画面...',
                          style: TextStyle(color: c.text3, fontSize: 13),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// VNC 帧缓冲渲染器
class _VncPainter extends CustomPainter {
  final ui.Image image;

  _VncPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    // 等比缩放居中
    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final renderW = image.width * scale;
    final renderH = image.height * scale;
    final offsetX = (size.width - renderW) / 2;
    final offsetY = (size.height - renderH) / 2;

    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(offsetX, offsetY, renderW, renderH);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_VncPainter oldDelegate) => oldDelegate.image != image;
}
