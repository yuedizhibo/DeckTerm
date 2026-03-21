import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../ui/main/models/terminal_session.dart';

/// VNC 连接管理器
/// 实现 RFB 3.8 协议最小子集：握手、VNC 认证、帧缓冲更新（Raw 编码）
class VncManager {
  final TerminalSession session;
  Socket? _socket;
  bool _disposed = false;

  // 帧缓冲
  int _fbWidth = 0;
  int _fbHeight = 0;
  String _fbName = '';
  Uint8List? _frameBuffer; // BGRA 像素数据

  int get fbWidth => _fbWidth;
  int get fbHeight => _fbHeight;
  String get fbName => _fbName;

  // 状态流
  final _statusController = StreamController<VncStatus>.broadcast(sync: true);
  Stream<VncStatus> get statusStream => _statusController.stream;

  // 帧更新通知
  final _frameController = StreamController<void>.broadcast(sync: true);
  Stream<void> get frameStream => _frameController.stream;

  VncStatus _status = VncStatus.disconnected;
  VncStatus get status => _status;

  VncManager(this.session);

  /// 获取当前帧缓冲数据（BGRA）
  Uint8List? get frameBuffer => _frameBuffer;

  /// 连接并完成 RFB 握手
  Future<void> connect() async {
    if (_disposed) return;
    _setStatus(VncStatus.connecting);

    try {
      _socket = await Socket.connect(
        session.host,
        session.port,
        timeout: const Duration(seconds: 10),
      );
      _socket!.setOption(SocketOption.tcpNoDelay, true);

      final stream = _socket!.asBroadcastStream();

      // 1. 协议版本握手
      final versionData = await stream.first.timeout(const Duration(seconds: 5));
      final serverVersion = String.fromCharCodes(versionData).trim();
      debugPrint('[VNC] Server version: $serverVersion');

      // 发送客户端版本 RFB 003.008
      _socket!.add(Uint8List.fromList('RFB 003.008\n'.codeUnits));

      // 2. 安全协商
      final secData = await stream.first.timeout(const Duration(seconds: 5));
      if (secData.isEmpty) throw Exception('Empty security data');

      final numSecTypes = secData[0];
      if (numSecTypes == 0) {
        // 连接失败，读取原因
        throw Exception('Server refused connection');
      }

      final secTypes = secData.sublist(1, 1 + numSecTypes);
      debugPrint('[VNC] Security types: $secTypes');

      // 优先选择 None(1)，否则选 VNC Authentication(2)
      if (secTypes.contains(1)) {
        // None authentication
        _socket!.add(Uint8List.fromList([1]));
      } else if (secTypes.contains(2)) {
        // VNC Authentication
        _socket!.add(Uint8List.fromList([2]));
        await _vncAuth(stream);
      } else {
        throw Exception('No supported security type');
      }

      // 3. SecurityResult
      final resultData = await _readExact(stream, 4);
      final result = ByteData.sublistView(resultData).getUint32(0);
      if (result != 0) {
        throw Exception('Authentication failed (code: $result)');
      }

      // 4. ClientInit - shared=true
      _socket!.add(Uint8List.fromList([1]));

      // 5. ServerInit
      final serverInit = await _readExact(stream, 24);
      final bd = ByteData.sublistView(serverInit);
      _fbWidth = bd.getUint16(0);
      _fbHeight = bd.getUint16(2);
      final nameLen = bd.getUint32(20);
      final nameData = await _readExact(stream, nameLen);
      _fbName = String.fromCharCodes(nameData);
      debugPrint('[VNC] Screen: ${_fbWidth}x$_fbHeight name: $_fbName');

      // 分配帧缓冲 (BGRA)
      _frameBuffer = Uint8List(_fbWidth * _fbHeight * 4);
      // 初始化为黑色不透明
      for (int i = 0; i < _frameBuffer!.length; i += 4) {
        _frameBuffer![i] = 0;     // B
        _frameBuffer![i + 1] = 0; // G
        _frameBuffer![i + 2] = 0; // R
        _frameBuffer![i + 3] = 255; // A
      }

      // 6. SetPixelFormat - 请求 32bpp BGRA
      _sendSetPixelFormat();

      // 7. SetEncodings - 只支持 Raw(0) 和 CopyRect(1)
      _sendSetEncodings([0, 1]);

      _setStatus(VncStatus.connected);

      // 8. 请求首帧完整更新
      requestFrameUpdate(incremental: false);

      // 9. 启动消息读取循环
      _readLoop(stream);
    } catch (e) {
      debugPrint('[VNC] Connect error: $e');
      _setStatus(VncStatus.failed);
      _socket?.destroy();
      _socket = null;
    }
  }

  /// VNC Authentication (DES challenge-response)
  Future<void> _vncAuth(Stream<Uint8List> stream) async {
    // 读取 16 字节 challenge
    final challenge = await _readExact(stream, 16);

    // DES 加密 challenge
    final password = session.password ?? '';
    final key = _vncPasswordToKey(password);
    final response = Uint8List(16);

    // 加密前 8 字节
    final encrypted1 = _desEncrypt(key, challenge.sublist(0, 8));
    response.setRange(0, 8, encrypted1);

    // 加密后 8 字节
    final encrypted2 = _desEncrypt(key, challenge.sublist(8, 16));
    response.setRange(8, 16, encrypted2);

    _socket!.add(response);
  }

  /// 将密码转换为 VNC DES key（反转每字节位序）
  Uint8List _vncPasswordToKey(String password) {
    final key = Uint8List(8);
    for (int i = 0; i < 8 && i < password.length; i++) {
      key[i] = _reverseBits(password.codeUnitAt(i));
    }
    return key;
  }

  int _reverseBits(int b) {
    int result = 0;
    for (int i = 0; i < 8; i++) {
      result = (result << 1) | (b & 1);
      b >>= 1;
    }
    return result;
  }

  /// 最小 DES 加密实现（ECB 模式，单块）
  /// VNC 使用的是标准 DES，但 key 的每字节位序反转
  Uint8List _desEncrypt(Uint8List key, Uint8List data) {
    // DES 常量表
    final des = _DES(key);
    return des.encrypt(data);
  }

  void _sendSetPixelFormat() {
    final msg = Uint8List(20);
    msg[0] = 0; // message-type: SetPixelFormat
    // bytes 1-3: padding
    // PixelFormat (16 bytes)
    msg[4] = 32;  // bits-per-pixel
    msg[5] = 24;  // depth
    msg[6] = 0;   // big-endian-flag (little)
    msg[7] = 1;   // true-colour-flag
    // red-max: 255
    msg[8] = 0; msg[9] = 255;
    // green-max: 255
    msg[10] = 0; msg[11] = 255;
    // blue-max: 255
    msg[12] = 0; msg[13] = 255;
    // red-shift: 16, green-shift: 8, blue-shift: 0
    msg[14] = 16; msg[15] = 8; msg[16] = 0;
    // padding bytes 17-19
    _socket?.add(msg);
  }

  void _sendSetEncodings(List<int> encodings) {
    final msg = Uint8List(4 + encodings.length * 4);
    msg[0] = 2; // message-type: SetEncodings
    // byte 1: padding
    final bd = ByteData.sublistView(msg);
    bd.setUint16(2, encodings.length);
    for (int i = 0; i < encodings.length; i++) {
      bd.setInt32(4 + i * 4, encodings[i]);
    }
    _socket?.add(msg);
  }

  /// 请求帧缓冲更新
  void requestFrameUpdate({bool incremental = true}) {
    if (_socket == null || _disposed) return;
    final msg = Uint8List(10);
    msg[0] = 3; // FramebufferUpdateRequest
    msg[1] = incremental ? 1 : 0;
    // x, y = 0
    final bd = ByteData.sublistView(msg);
    bd.setUint16(2, 0);
    bd.setUint16(4, 0);
    bd.setUint16(6, _fbWidth);
    bd.setUint16(8, _fbHeight);
    _socket!.add(msg);
  }

  /// 发送键盘事件
  void sendKeyEvent(int keysym, bool down) {
    if (_socket == null || _disposed) return;
    final msg = Uint8List(8);
    msg[0] = 4; // KeyEvent
    msg[1] = down ? 1 : 0;
    // bytes 2-3: padding
    final bd = ByteData.sublistView(msg);
    bd.setUint32(4, keysym);
    _socket!.add(msg);
  }

  /// 发送鼠标/触摸事件
  void sendPointerEvent(int x, int y, int buttonMask) {
    if (_socket == null || _disposed) return;
    final msg = Uint8List(6);
    msg[0] = 5; // PointerEvent
    msg[1] = buttonMask;
    final bd = ByteData.sublistView(msg);
    bd.setUint16(2, x.clamp(0, _fbWidth - 1));
    bd.setUint16(4, y.clamp(0, _fbHeight - 1));
    _socket!.add(msg);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  消息读取循环
  // ═══════════════════════════════════════════════════════════════════

  final _readBuffer = <int>[];

  void _readLoop(Stream<Uint8List> stream) {
    stream.listen(
      (data) {
        if (_disposed) return;
        _readBuffer.addAll(data);
        _processBuffer();
      },
      onError: (e) {
        if (_disposed) return;
        debugPrint('[VNC] Stream error: $e');
        _setStatus(VncStatus.failed);
      },
      onDone: () {
        if (_disposed) return;
        debugPrint('[VNC] Connection closed');
        _setStatus(VncStatus.disconnected);
      },
    );
  }

  void _processBuffer() {
    while (_readBuffer.isNotEmpty) {
      final msgType = _readBuffer[0];
      switch (msgType) {
        case 0: // FramebufferUpdate
          if (!_handleFramebufferUpdate()) return;
        case 1: // SetColourMapEntries - skip
          if (_readBuffer.length < 6) return;
          final numColors = (_readBuffer[4] << 8) | _readBuffer[5];
          final totalLen = 6 + numColors * 6;
          if (_readBuffer.length < totalLen) return;
          _readBuffer.removeRange(0, totalLen);
        case 2: // Bell
          _readBuffer.removeAt(0);
        case 3: // ServerCutText
          if (_readBuffer.length < 8) return;
          final len = (_readBuffer[4] << 24) | (_readBuffer[5] << 16) | (_readBuffer[6] << 8) | _readBuffer[7];
          final totalLen = 8 + len;
          if (_readBuffer.length < totalLen) return;
          _readBuffer.removeRange(0, totalLen);
        default:
          debugPrint('[VNC] Unknown message type: $msgType');
          _readBuffer.clear();
          return;
      }
    }
  }

  bool _handleFramebufferUpdate() {
    if (_readBuffer.length < 4) return false;
    final numRects = (_readBuffer[2] << 8) | _readBuffer[3];
    int offset = 4;

    for (int i = 0; i < numRects; i++) {
      if (_readBuffer.length < offset + 12) return false;
      final x = (_readBuffer[offset] << 8) | _readBuffer[offset + 1];
      final y = (_readBuffer[offset + 2] << 8) | _readBuffer[offset + 3];
      final w = (_readBuffer[offset + 4] << 8) | _readBuffer[offset + 5];
      final h = (_readBuffer[offset + 6] << 8) | _readBuffer[offset + 7];
      final encoding = (_readBuffer[offset + 8] << 24) | (_readBuffer[offset + 9] << 16) |
          (_readBuffer[offset + 10] << 8) | _readBuffer[offset + 11];
      offset += 12;

      if (encoding == 0) {
        // Raw encoding
        final pixelDataLen = w * h * 4; // 32bpp
        if (_readBuffer.length < offset + pixelDataLen) return false;

        // 复制像素到帧缓冲
        if (_frameBuffer != null) {
          for (int row = 0; row < h; row++) {
            final srcStart = offset + row * w * 4;
            final dstStart = ((y + row) * _fbWidth + x) * 4;
            if (dstStart + w * 4 <= _frameBuffer!.length && srcStart + w * 4 <= _readBuffer.length) {
              for (int col = 0; col < w * 4; col++) {
                _frameBuffer![dstStart + col] = _readBuffer[srcStart + col];
              }
            }
          }
        }
        offset += pixelDataLen;
      } else if (encoding == 1) {
        // CopyRect
        if (_readBuffer.length < offset + 4) return false;
        final srcX = (_readBuffer[offset] << 8) | _readBuffer[offset + 1];
        final srcY = (_readBuffer[offset + 2] << 8) | _readBuffer[offset + 3];
        offset += 4;

        if (_frameBuffer != null) {
          // 创建临时缓冲区避免重叠问题
          final temp = Uint8List(w * h * 4);
          for (int row = 0; row < h; row++) {
            final srcStart = ((srcY + row) * _fbWidth + srcX) * 4;
            final tmpStart = row * w * 4;
            for (int col = 0; col < w * 4; col++) {
              if (srcStart + col < _frameBuffer!.length) {
                temp[tmpStart + col] = _frameBuffer![srcStart + col];
              }
            }
          }
          for (int row = 0; row < h; row++) {
            final dstStart = ((y + row) * _fbWidth + x) * 4;
            final tmpStart = row * w * 4;
            for (int col = 0; col < w * 4; col++) {
              if (dstStart + col < _frameBuffer!.length) {
                _frameBuffer![dstStart + col] = temp[tmpStart + col];
              }
            }
          }
        }
      } else {
        debugPrint('[VNC] Unsupported encoding: $encoding');
        _readBuffer.clear();
        return true;
      }
    }

    _readBuffer.removeRange(0, offset);
    _frameController.add(null);

    // 请求下一帧增量更新
    requestFrameUpdate();
    return true;
  }

  /// 从流中精确读取 n 字节
  Future<Uint8List> _readExact(Stream<Uint8List> stream, int n) async {
    final buffer = <int>[];
    await for (final chunk in stream) {
      buffer.addAll(chunk);
      if (buffer.length >= n) break;
    }
    if (buffer.length < n) throw Exception('Connection closed prematurely');
    return Uint8List.fromList(buffer.sublist(0, n));
  }

  void _setStatus(VncStatus s) {
    _status = s;
    if (!_disposed) _statusController.add(s);
  }

  void dispose() {
    _disposed = true;
    _socket?.destroy();
    _socket = null;
    _statusController.close();
    _frameController.close();
  }
}

enum VncStatus {
  disconnected,
  connecting,
  connected,
  failed,
}

// ═══════════════════════════════════════════════════════════════════
//  最小 DES 实现（VNC Authentication 专用）
//  VNC 仅需 ECB 模式加密单个 8 字节块
// ═══════════════════════════════════════════════════════════════════

class _DES {
  late final List<int> _subkeys;

  _DES(Uint8List key) {
    _subkeys = _generateSubkeys(key);
  }

  Uint8List encrypt(Uint8List data) {
    assert(data.length == 8);
    int block = 0;
    for (int i = 0; i < 8; i++) {
      block = (block << 8) | data[i];
    }
    block = _initialPermutation(block);
    int left = (block >> 32) & 0xFFFFFFFF;
    int right = block & 0xFFFFFFFF;

    for (int i = 0; i < 16; i++) {
      final temp = right;
      right = left ^ _feistel(right, _subkeys[i]);
      left = temp;
    }

    block = ((right & 0xFFFFFFFF) << 32) | (left & 0xFFFFFFFF);
    block = _finalPermutation(block);

    final result = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      result[i] = block & 0xFF;
      block >>= 8;
    }
    return result;
  }

  // DES 置换表和 S-box（标准实现）
  static const _ip = [58,50,42,34,26,18,10,2,60,52,44,36,28,20,12,4,62,54,46,38,30,22,14,6,64,56,48,40,32,24,16,8,57,49,41,33,25,17,9,1,59,51,43,35,27,19,11,3,61,53,45,37,29,21,13,5,63,55,47,39,31,23,15,7];
  static const _fp = [40,8,48,16,56,24,64,32,39,7,47,15,55,23,63,31,38,6,46,14,54,22,62,30,37,5,45,13,53,21,61,29,36,4,44,12,52,20,60,28,35,3,43,11,51,19,59,27,34,2,42,10,50,18,58,26,33,1,41,9,49,17,57,25];
  static const _e = [32,1,2,3,4,5,4,5,6,7,8,9,8,9,10,11,12,13,12,13,14,15,16,17,16,17,18,19,20,21,20,21,22,23,24,25,24,25,26,27,28,29,28,29,30,31,32,1];
  static const _p = [16,7,20,21,29,12,28,17,1,15,23,26,5,18,31,10,2,8,24,14,32,27,3,9,19,13,30,6,22,11,4,25];
  static const _pc1 = [57,49,41,33,25,17,9,1,58,50,42,34,26,18,10,2,59,51,43,35,27,19,11,3,60,52,44,36,63,55,47,39,31,23,15,7,62,54,46,38,30,22,14,6,61,53,45,37,29,21,13,5,28,20,12,4];
  static const _pc2 = [14,17,11,24,1,5,3,28,15,6,21,10,23,19,12,4,26,8,16,7,27,20,13,2,41,52,31,37,47,55,30,40,51,45,33,48,44,49,39,56,34,53,46,42,50,36,29,32];
  static const _shifts = [1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1];

  static const _sBoxes = [
    [14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7,0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8,4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0,15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13],
    [15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10,3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5,0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15,13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9],
    [10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8,13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1,13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7,1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12],
    [7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15,13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9,10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4,3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14],
    [2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9,14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6,4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14,11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3],
    [12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11,10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8,9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6,4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13],
    [4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1,13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6,1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2,6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12],
    [13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7,1,15,13,8,10,3,7,4,12,5,6,2,0,14,9,11,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1,13,11,14,4,1,5,12,2,15,8,3,10,6,13,7,9,0],
  ];

  int _getBit(int value, int bit, int totalBits) {
    return (value >> (totalBits - bit)) & 1;
  }

  int _permute(int value, List<int> table, int inputBits) {
    int result = 0;
    for (int i = 0; i < table.length; i++) {
      result = (result << 1) | _getBit(value, table[i], inputBits);
    }
    return result;
  }

  int _initialPermutation(int block) => _permute(block, _ip, 64);
  int _finalPermutation(int block) => _permute(block, _fp, 64);

  int _feistel(int right, int subkey) {
    // Expansion
    int expanded = _permute(right, _e, 32);
    // XOR with subkey
    expanded ^= subkey;
    // S-box substitution
    int output = 0;
    for (int i = 0; i < 8; i++) {
      final bits6 = (expanded >> (42 - i * 6)) & 0x3F;
      final row = ((bits6 >> 5) << 1) | (bits6 & 1);
      final col = (bits6 >> 1) & 0xF;
      output = (output << 4) | _sBoxes[i][row * 16 + col];
    }
    // P permutation
    return _permute(output, _p, 32);
  }

  List<int> _generateSubkeys(Uint8List key) {
    int keyBits = 0;
    for (int i = 0; i < 8; i++) {
      keyBits = (keyBits << 8) | key[i];
    }

    int permuted = _permute(keyBits, _pc1, 64);
    int c = (permuted >> 28) & 0xFFFFFFF;
    int d = permuted & 0xFFFFFFF;

    final subkeys = <int>[];
    for (int i = 0; i < 16; i++) {
      final shift = _shifts[i];
      c = ((c << shift) | (c >> (28 - shift))) & 0xFFFFFFF;
      d = ((d << shift) | (d >> (28 - shift))) & 0xFFFFFFF;
      final cd = (c << 28) | d;
      subkeys.add(_permute(cd, _pc2, 56));
    }
    return subkeys;
  }
}
