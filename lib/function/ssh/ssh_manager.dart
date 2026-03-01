import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import '../../ui/main/models/terminal_session.dart';

import 'package:flutter/foundation.dart';

// ── TCP_NODELAY Socket ────────────────────────────────────────────────────────
//
// 问题根因：Nagle 算法 + TCP 延迟 ACK 的叠加效应
//
// 默认情况下 Dart Socket 启用 Nagle 算法：
//   1. 用户输入 'a' → 立即发出 TCP 包（无在途数据，Nagle 允许）
//   2. 服务器收到 'a'，echo 回来
//   3. 客户端 OS 收到 echo，需要发 ACK，但启用了延迟 ACK（最多等 40~500ms）
//   4. 用户继续输入 'b'，Nagle 发现 'a' 的 ACK 还没收到 → 憋住不发
//   5. 延迟 ACK 超时后才发 ACK，Nagle 才把 'b' 放行
//   6. 结果：每个字符都要经历一轮延迟，造成 ~500ms 的输入回显延迟
//
// 修复：设置 TCP_NODELAY = true，彻底绕开 Nagle，每个字节立即发送。
// ─────────────────────────────────────────────────────────────────────────────
class _TcpNoDelaySocket implements SSHSocket {
  final Socket _socket;

  _TcpNoDelaySocket._(this._socket);

  /// 创建一个禁用 Nagle 算法的 TCP Socket。
  static Future<_TcpNoDelaySocket> connect(
    String host,
    int port, {
    Duration? timeout,
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    // TCP_NODELAY = true：禁用 Nagle 算法，每次 write 立即触发 TCP 发送，
    // 消除人机交互型 SSH 会话中 Nagle + 延迟 ACK 叠加导致的 ~500ms 延迟。
    socket.setOption(SocketOption.tcpNoDelay, true);
    return _TcpNoDelaySocket._(socket);
  }

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();
}

// ─────────────────────────────────────────────────────────────────────────────

class SshManager {
  final TerminalSession session;
  SSHClient? _client;
  SSHSession? _shell;

  // 增量 UTF-8 解码器：allowMalformed 防止流式数据在字节序列边界被截断时抛异常
  final _stdoutDecoder = Utf8Decoder(allowMalformed: true);
  final _stderrDecoder = Utf8Decoder(allowMalformed: true);

  // sync: true → 数据到达后同步派发给监听者，消除微任务调度带来的额外延迟
  final _outputController = StreamController<String>.broadcast(sync: true);
  Stream<String> get output => _outputController.stream;

  SSHClient? get client => _client;

  SshManager({required this.session});

  Future<void> connect() async {
    try {
      _outputController.add('Connecting to ${session.host}:${session.port}...\r\n');

      // 使用自定义 Socket（TCP_NODELAY），替代 SSHSocket.connect() 默认实现
      final socket = await _TcpNoDelaySocket.connect(
        session.host,
        session.port,
        timeout: const Duration(seconds: 10),
      );

      _client = SSHClient(
        socket,
        username: session.username ?? 'root',
        onPasswordRequest: () => session.password,
      );

      _outputController.add('Connected. Authenticating...\r\n');
      await _client!.authenticated;
      _outputController.add('Authenticated.\r\n');

      _shell = await _client!.shell(
        pty: const SSHPtyConfig(
          type: 'xterm-256color',
          width: 80,
          height: 24,
        ),
      );

      _shell!.stdout.listen((data) {
        final decoded = _stdoutDecoder.convert(data);
        debugPrint('[SSH-Output] recv ${data.length}B '
            'at ${DateTime.now().millisecondsSinceEpoch}ms');
        _outputController.add(decoded);
      });

      _shell!.stderr.listen((data) {
        _outputController.add(_stderrDecoder.convert(data));
      });

      _client!.done.then((_) {
        _outputController.add('\r\nConnection closed.\r\n');
      });
    } catch (e) {
      _outputController.add('Error: $e\r\n');
    }
  }

  void write(String data) {
    if (_shell != null) {
      debugPrint('[SSH-Write] send at ${DateTime.now().millisecondsSinceEpoch}ms '
          '"${data.replaceAll('\r', '\\r').replaceAll('\n', '\\n')}"');
      _shell!.write(Uint8List.fromList(utf8.encode(data)));
    }
  }

  void resize(int width, int height) {
    _shell?.resizeTerminal(width, height, width * 8, height * 16);
  }

  void dispose() {
    _shell?.close();
    _client?.close();
    _outputController.close();
  }
}
