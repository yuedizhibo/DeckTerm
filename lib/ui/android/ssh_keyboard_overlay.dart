import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// [Android 专用] SSH 终端软键盘输入层
///
/// 职责：在 Android 平台上为 SSH 终端提供软键盘输入能力。
/// 使用方式：用 Stack 叠加在终端视图之上。
///
/// 输入原理：
///   软键盘不产生 HardwareKeyboard 事件，字符只经过 IME/TextInputClient 管道。
///   本组件通过一个偏移到屏幕外的隐藏 TextField 接收 IME 输入，
///   再通过 delta 追踪（onChanged diff）将字符/退格转发给 xterm Terminal。
///
/// 哨兵缓冲区：
///   TextField 始终维持 ≥10 个空格作为缓冲，确保连续退格操作可被检测。
///   当内容长度低于阈值时自动重置。
///
/// 交互流程：
///   用户点击右下角键盘按钮 → TextField 获焦 → 系统软键盘弹出
///   字符输入 → onChanged → terminal.textInput()
///   回车      → onSubmitted → terminal.keyInput(TerminalKey.enter)
///   再次点击  → 收起软键盘
class SshKeyboardOverlay extends StatefulWidget {
  final Terminal terminal;

  /// 用于标识唯一 FloatingActionButton heroTag（多标签页时避免 Hero 动画冲突）
  final String sessionId;

  const SshKeyboardOverlay({
    super.key,
    required this.terminal,
    required this.sessionId,
  });

  @override
  State<SshKeyboardOverlay> createState() => _SshKeyboardOverlayState();
}

class _SshKeyboardOverlayState extends State<SshKeyboardOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _prevText = '';
  static const String _kSentinelText = '          '; // 10 个空格

  @override
  void initState() {
    super.initState();
    _prevText = _kSentinelText;
    _controller.text = _kSentinelText;
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// 切换软键盘显示 / 收起。
  void _toggle() {
    if (_focusNode.hasFocus) {
      FocusScope.of(context).unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  /// 通过 TextField 内容 diff 提取字符 / 退格，转发给 xterm Terminal。
  void _onChanged(String text) {
    final prev = _prevText;
    _prevText = text;

    if (text.length > prev.length) {
      // 新增字符（过滤换行，Enter 由 onSubmitted 专项处理）
      final newChars = text
          .substring(prev.length)
          .replaceAll('\r', '')
          .replaceAll('\n', '');
      if (newChars.isNotEmpty) widget.terminal.textInput(newChars);
    } else if (text.length < prev.length) {
      // 退格：按差值发送退格键
      for (int i = 0; i < prev.length - text.length; i++) {
        widget.terminal.keyInput(TerminalKey.backspace);
      }
    }

    // 哨兵重置：内容过短时补回缓冲区，保证退格始终可被检测
    if (text.length < 5) {
      _controller.value = TextEditingValue(
        text: _kSentinelText,
        selection: TextSelection.collapsed(offset: _kSentinelText.length),
      );
      _prevText = _kSentinelText;
    }
  }

  /// 软键盘 Send / Enter 键：发送回车并重置缓冲区，保持键盘开启。
  void _onSubmitted(String _) {
    widget.terminal.keyInput(TerminalKey.enter);
    _controller.value = TextEditingValue(
      text: _kSentinelText,
      selection: TextSelection.collapsed(offset: _kSentinelText.length),
    );
    _prevText = _kSentinelText;
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = _focusNode.hasFocus;

    return Stack(
      children: [
        // 隐藏 TextField：偏移至屏幕可视区域外，接收软键盘 IME 输入。
        // 注意：不可用 Opacity(0) 或 Visibility 隐藏，否则 IME 连接可能被中断。
        Positioned(
          left: -9999,
          top: 0,
          width: 1,
          height: 1,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            onSubmitted: _onSubmitted,
            keyboardType: TextInputType.text,
            // send：Enter 键触发 onSubmitted，不会将换行插入 onChanged
            textInputAction: TextInputAction.send,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 1, color: Colors.transparent),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),

        // 键盘浮动按钮：点击弹出 / 收起系统软键盘
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            // heroTag 需唯一，避免多个终端标签页间 Hero 动画冲突
            heroTag: 'ssh_kbd_$sessionId',
            onPressed: _toggle,
            tooltip: keyboardOpen ? '收起键盘' : '弹出键盘',
            child: Icon(
              keyboardOpen
                  ? Icons.keyboard_hide_outlined
                  : Icons.keyboard_alt_outlined,
            ),
          ),
        ),
      ],
    );
  }

  String get sessionId => widget.sessionId;
}
