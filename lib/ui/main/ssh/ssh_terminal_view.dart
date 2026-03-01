import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../../function/ssh/ssh_manager.dart';
import '../models/terminal_session.dart';
import '../../../function/monitor/device_monitor.dart';
// [Android 专用] 软键盘输入层，仅在 Platform.isAndroid 时使用
import '../../android/ssh_keyboard_overlay.dart';

/// SSH 终端 UI 组件（xterm 渲染 + 多平台键盘适配 + 光标闪烁）
///
/// ══════════════════════════════════════════════════════════════════════
/// 文件职责说明
/// ══════════════════════════════════════════════════════════════════════
///
/// 本文件（ssh_terminal_view.dart）
///   负责平台无关的终端核心逻辑：
///   • xterm Terminal 渲染（TerminalView）
///   • 光标闪烁控制（聚焦时白/灰交替，失焦时灰色描边）
///   • 物理键盘输入（HardwareKeyboard → onKeyEvent → terminal）
///     Windows、Linux、macOS、Android 物理键盘均走此路径
///
/// ui/android/ssh_keyboard_overlay.dart（Android 专用）
///   负责 Android 软键盘支持：
///   • 右下角浮动键盘按钮（FAB）
///   • 隐藏 TextField 接收 IME 输入 → delta 追踪 → terminal
///   • 本文件通过 if (Platform.isAndroid) 挂载该组件
///
/// function/ssh/ssh_manager.dart（平台无关）
///   • SSH 连接管理（dartssh2）
///   • TCP_NODELAY Socket（消除 Nagle 算法导致的输入延迟）
///   • 流式 UTF-8 解码、同步广播 StreamController
///
/// ══════════════════════════════════════════════════════════════════════
/// 键盘输入策略（物理键盘，此文件实现）
/// ══════════════════════════════════════════════════════════════════════
///
///   hardwareKeyboardOnly: true
///     TerminalView 跳过 TextInputClient/IME，所有键盘事件经 onKeyEvent 处理。
///     避免 Windows 下 IME 管道与 TerminalView 的冲突（历史 bug 根因）。
///
///   event.character（KeyDownEvent 字段）
///     由 OS 从原始 WM_CHAR（Windows）/ 键盘驱动（Linux/macOS）填充，
///     正确反映当前键盘布局，无需 TextInputClient 即可获取可打印字符。
///     Android 物理键盘同样支持此字段。
///
/// ══════════════════════════════════════════════════════════════════════
/// 光标行为
/// ══════════════════════════════════════════════════════════════════════
///
///   聚焦时：白色实心块，每 530ms 在白（#FFFFFF）/ 灰（#AEAFAD）间闪烁
///   失焦时：灰色描边块，不闪烁
///
///   xterm painter 逻辑：
///     hasFocus = true  → PaintingStyle.fill（实心）→ theme.cursor 颜色
///     hasFocus = false → PaintingStyle.stroke（描边）→ theme.cursor 颜色
///   因此动态切换 TerminalTheme.cursor 颜色即可实现白/灰闪烁效果。
///
class SshTerminalView extends StatefulWidget {
  final TerminalSession session;

  const SshTerminalView({super.key, required this.session});

  @override
  State<SshTerminalView> createState() => _SshTerminalViewState();
}

class _SshTerminalViewState extends State<SshTerminalView>
    with AutomaticKeepAliveClientMixin {
  // ── 终端核心（所有平台共用）────────────────────────────────────────────
  late final SshManager _sshManager;
  late final Terminal _terminal;
  final TerminalController _terminalController = TerminalController();
  final FocusNode _focusNode = FocusNode();

  // ── 光标颜色 / 闪烁（所有平台共用）────────────────────────────────────
  static const Color _kCursorGray = Color(0xFFAEAFAD);
  static const Color _kCursorWhite = Color(0xFFFFFFFF);
  Color _cursorColor = _kCursorGray;
  Timer? _blinkTimer;

  // ── 特殊键映射（所有平台共用）──────────────────────────────────────────
  static final Map<LogicalKeyboardKey, TerminalKey> _specialKeyMap = {
    LogicalKeyboardKey.enter: TerminalKey.enter,
    LogicalKeyboardKey.numpadEnter: TerminalKey.enter,
    LogicalKeyboardKey.backspace: TerminalKey.backspace,
    LogicalKeyboardKey.escape: TerminalKey.escape,
    LogicalKeyboardKey.tab: TerminalKey.tab,
    LogicalKeyboardKey.delete: TerminalKey.delete,
    LogicalKeyboardKey.arrowUp: TerminalKey.arrowUp,
    LogicalKeyboardKey.arrowDown: TerminalKey.arrowDown,
    LogicalKeyboardKey.arrowLeft: TerminalKey.arrowLeft,
    LogicalKeyboardKey.arrowRight: TerminalKey.arrowRight,
    LogicalKeyboardKey.home: TerminalKey.home,
    LogicalKeyboardKey.end: TerminalKey.end,
    LogicalKeyboardKey.pageUp: TerminalKey.pageUp,
    LogicalKeyboardKey.pageDown: TerminalKey.pageDown,
    LogicalKeyboardKey.f1: TerminalKey.f1,
    LogicalKeyboardKey.f2: TerminalKey.f2,
    LogicalKeyboardKey.f3: TerminalKey.f3,
    LogicalKeyboardKey.f4: TerminalKey.f4,
    LogicalKeyboardKey.f5: TerminalKey.f5,
    LogicalKeyboardKey.f6: TerminalKey.f6,
    LogicalKeyboardKey.f7: TerminalKey.f7,
    LogicalKeyboardKey.f8: TerminalKey.f8,
    LogicalKeyboardKey.f9: TerminalKey.f9,
    LogicalKeyboardKey.f10: TerminalKey.f10,
    LogicalKeyboardKey.f11: TerminalKey.f11,
    LogicalKeyboardKey.f12: TerminalKey.f12,
  };

  // ── Ctrl 组合键映射（A-Z，所有平台共用）────────────────────────────────
  static final Map<LogicalKeyboardKey, TerminalKey> _ctrlKeyMap = {
    LogicalKeyboardKey.keyA: TerminalKey.keyA,
    LogicalKeyboardKey.keyB: TerminalKey.keyB,
    LogicalKeyboardKey.keyC: TerminalKey.keyC,
    LogicalKeyboardKey.keyD: TerminalKey.keyD,
    LogicalKeyboardKey.keyE: TerminalKey.keyE,
    LogicalKeyboardKey.keyF: TerminalKey.keyF,
    LogicalKeyboardKey.keyG: TerminalKey.keyG,
    LogicalKeyboardKey.keyH: TerminalKey.keyH,
    LogicalKeyboardKey.keyI: TerminalKey.keyI,
    LogicalKeyboardKey.keyJ: TerminalKey.keyJ,
    LogicalKeyboardKey.keyK: TerminalKey.keyK,
    LogicalKeyboardKey.keyL: TerminalKey.keyL,
    LogicalKeyboardKey.keyM: TerminalKey.keyM,
    LogicalKeyboardKey.keyN: TerminalKey.keyN,
    LogicalKeyboardKey.keyO: TerminalKey.keyO,
    LogicalKeyboardKey.keyP: TerminalKey.keyP,
    LogicalKeyboardKey.keyQ: TerminalKey.keyQ,
    LogicalKeyboardKey.keyR: TerminalKey.keyR,
    LogicalKeyboardKey.keyS: TerminalKey.keyS,
    LogicalKeyboardKey.keyT: TerminalKey.keyT,
    LogicalKeyboardKey.keyU: TerminalKey.keyU,
    LogicalKeyboardKey.keyV: TerminalKey.keyV,
    LogicalKeyboardKey.keyW: TerminalKey.keyW,
    LogicalKeyboardKey.keyX: TerminalKey.keyX,
    LogicalKeyboardKey.keyY: TerminalKey.keyY,
    LogicalKeyboardKey.keyZ: TerminalKey.keyZ,
  };

  // ─────────────────────────────────────────────────────────────────────
  // 生命周期
  // ─────────────────────────────────────────────────────────────────────

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _terminal = Terminal(maxLines: 10000);
    _sshManager = SshManager(session: widget.session);
    DeviceMonitor().addDevice(widget.session);

    _terminal.onOutput = _sshManager.write;
    _terminal.onResize = (w, h, pw, ph) => _sshManager.resize(w, h);
    _sshManager.output.listen(_terminal.write);

    _focusNode.addListener(_onFocusChanged);

    _connect();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _terminalController.dispose();
    DeviceMonitor().removeDevice(widget.session.id);
    _sshManager.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await _sshManager.connect();
  }

  // ─────────────────────────────────────────────────────────────────────
  // 光标闪烁（所有平台共用）
  // ─────────────────────────────────────────────────────────────────────

  void _onFocusChanged() {
    _focusNode.hasFocus ? _startBlinking() : _stopBlinking();
  }

  /// 获得焦点 → 立即显示白色光标，随后每 530ms 白/灰交替。
  void _startBlinking() {
    _blinkTimer?.cancel();
    if (mounted) setState(() => _cursorColor = _kCursorWhite);
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (!mounted) return;
      setState(() {
        _cursorColor =
            (_cursorColor == _kCursorWhite) ? _kCursorGray : _kCursorWhite;
      });
    });
  }

  /// 失去焦点 → 停止闪烁，恢复灰色描边光标。
  void _stopBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (mounted) setState(() => _cursorColor = _kCursorGray);
  }

  // ─────────────────────────────────────────────────────────────────────
  // 物理键盘输入（所有平台共用）
  // ─────────────────────────────────────────────────────────────────────

  /// 处理物理键盘按键，由 TerminalView.onKeyEvent 调用。
  ///
  /// 适用平台：Windows、Linux、macOS、Android（接入物理键盘时）。
  /// Android 软键盘输入由 [SshKeyboardOverlay]（ui/android/）独立处理。
  ///
  /// 返回 true  → 事件已消费，TerminalView 不执行默认处理
  /// 返回 false → 事件未消费，TerminalView 继续默认处理
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;

    debugPrint('[SSH-Input] key=${key.keyLabel} char="${event.character}" '
        'ctrl=$ctrl shift=$shift alt=$alt '
        'at=${DateTime.now().millisecondsSinceEpoch}ms');

    // 1. Ctrl+V → 剪贴板粘贴
    if (ctrl && key == LogicalKeyboardKey.keyV) {
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        if (data?.text != null) _terminal.paste(data!.text!);
      });
      return true;
    }

    // 2. Ctrl+A~Z 组合键
    if (ctrl) {
      final termKey = _ctrlKeyMap[key];
      if (termKey != null) {
        _terminal.keyInput(termKey, ctrl: true, shift: shift, alt: alt);
        return true;
      }
    }

    // 3. 特殊键（Enter、Backspace、方向键、F1-F12 等）
    final termKey = _specialKeyMap[key];
    if (termKey != null) {
      _terminal.keyInput(termKey, shift: shift, alt: alt);
      return true;
    }

    // 4. 可打印字符
    //    event.character 由 OS 在 KeyDownEvent 上填充（Windows：WM_CHAR；
    //    Linux/macOS：键盘驱动），正确反映当前键盘布局，无需 TextInputClient。
    //    Android 软键盘字符不经此路径（软键盘不产生 HardwareKeyboard 事件）。
    final char = event.character;
    if (char != null && char.isNotEmpty && !ctrl && !alt) {
      final code = char.codeUnitAt(0);
      if (code >= 0x20 && code != 0x7F) {
        _terminal.textInput(char);
        return true;
      }
    }

    return false;
  }

  // ─────────────────────────────────────────────────────────────────────
  // 右键菜单（所有平台共用）
  // ─────────────────────────────────────────────────────────────────────

  void _handleSecondaryTap(TapDownDetails details, CellOffset offset) {
    final selection = _terminalController.selection;
    if (selection != null) {
      Clipboard.setData(
          ClipboardData(text: _terminal.buffer.getText(selection)));
      _terminalController.clearSelection();
    } else {
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        if (data?.text != null) _terminal.paste(data!.text!);
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 终端核心视图（所有平台共用）
    //
    // focusNode: _focusNode
    //   直接传入，TerminalView 据此判断 hasFocus，
    //   控制光标填充（聚焦）或描边（失焦）样式。
    //
    // hardwareKeyboardOnly: true
    //   跳过 TextInputClient/IME（CustomTextEdit），
    //   仅通过 onKeyEvent 处理物理键盘，消除 Windows IME 冲突。
    //
    // theme.cursor: _cursorColor（动态）
    //   聚焦时由 _blinkTimer 驱动白/灰交替，失焦时固定灰色。
    final terminalView = TerminalView(
      _terminal,
      controller: _terminalController,
      focusNode: _focusNode,
      autofocus: !Platform.isAndroid,
      hardwareKeyboardOnly: true,
      onKeyEvent: (_, event) => _handleKeyEvent(event)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      onSecondaryTapDown: _handleSecondaryTap,
      theme: TerminalTheme(
        cursor: _cursorColor,
        selection: const Color(0x80FFFFFF),
        foreground: const Color(0xFFCCCCCC),
        background: const Color(0xFF1E1E1E),
        black: const Color(0xFF000000),
        red: const Color(0xFFCD3131),
        green: const Color(0xFF0DBC79),
        yellow: const Color(0xFFE5E510),
        blue: const Color(0xFF2472C8),
        magenta: const Color(0xFFBC3FBC),
        cyan: const Color(0xFF11A8CD),
        white: const Color(0xFFE5E5E5),
        brightBlack: const Color(0xFF666666),
        brightRed: const Color(0xFFF14C4C),
        brightGreen: const Color(0xFF23D18B),
        brightYellow: const Color(0xFFF5F543),
        brightBlue: const Color(0xFF3B8EEA),
        brightMagenta: const Color(0xFFD670D6),
        brightCyan: const Color(0xFF29B8DB),
        brightWhite: const Color(0xFFFFFFFF),
        searchHitBackground: const Color(0xFFFF8000),
        searchHitBackgroundCurrent: const Color(0xFFFF8000),
        searchHitForeground: const Color(0xFFFFFFFF),
      ),
    );

    // ── Android：叠加软键盘层（来自 ui/android/ssh_keyboard_overlay.dart）──
    //
    // SshKeyboardOverlay 完全封装了 Android 软键盘逻辑，
    // 本文件不包含任何 Android IME / TextField 代码。
    if (Platform.isAndroid) {
      return Stack(
        children: [
          Positioned.fill(child: terminalView),
          SshKeyboardOverlay(
            terminal: _terminal,
            sessionId: widget.session.id,
          ),
        ],
      );
    }

    // ── Windows / Linux / macOS（桌面端）: 直接返回终端视图 ────────────────
    return terminalView;
  }
}
