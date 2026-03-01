import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

import '../../ui/main/models/terminal_session.dart';

class SftpManager {
  final TerminalSession session;
  SSHClient? _client;
  SftpClient? _sftp;
  // 缓存目录列表，key 为路径
  final Map<String, List<SftpName>> _cache = {};
  
  SftpManager(this.session);

  bool get isConnected => _client != null && !_client!.isClosed && _sftp != null;

  /// 连接 SFTP
  Future<void> connect() async {
    try {
      final socket = await SSHSocket.connect(
        session.host,
        session.port,
        timeout: const Duration(seconds: 10),
      );

      _client = SSHClient(
        socket,
        username: session.username ?? 'root',
        onPasswordRequest: () => session.password,
      );

      await _client!.authenticated;
      _sftp = await _client!.sftp();
    } catch (e) {
      // 连接失败
      rethrow;
    }
  }

  /// 获取指定目录下的文件列表
  /// [useCache] 是否优先使用缓存
  Future<List<SftpName>> listDirectory(String path, {bool useCache = true}) async {
    if (useCache && _cache.containsKey(path)) {
      return _cache[path]!;
    }

    if (!isConnected) {
      await connect();
    }
    try {
      final items = await _sftp!.listdir(path);
      
      // 过滤掉 . 和 ..
      items.removeWhere((item) => item.filename == '.' || item.filename == '..');

      // 排序：目录在前，文件在后；同类按名称排序
      items.sort((a, b) {
        final aIsDir = a.attr.isDirectory;
        final bIsDir = b.attr.isDirectory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      });
      
      // 更新缓存
      _cache[path] = items;
      return items;
    } catch (e) {
      rethrow;
    }
  }

  /// 清除指定路径的缓存
  void clearCache(String path) {
    _cache.remove(path);
  }

  /// 创建目录
  Future<void> createDirectory(String path) async {
    if (!isConnected) await connect();
    await _sftp!.mkdir(path);
    // 简单的缓存失效策略：清除父目录缓存
    // 假设 path 是完整路径，我们需要找到父目录
    // 简单起见，这里清除所有缓存可能更安全，或者解析父路径
    _cache.clear(); 
  }

  /// 删除文件或目录
  Future<void> delete(String path, {bool isDirectory = false}) async {
    if (!isConnected) await connect();
    if (isDirectory) {
      await _sftp!.rmdir(path);
    } else {
      await _sftp!.remove(path);
    }
    _cache.clear(); // 操作后清除缓存
  }
  
  /// 上传文件
  /// [onProgress] 上传进度回调 (已传输字节数)
  Future<void> uploadFile(String remotePath, Stream<List<int>> content, {Function(int)? onProgress}) async {
    if (!isConnected) await connect();
    
    // 确保目录存在（可选，或者让 open 抛错）
    // final dir = remotePath.substring(0, remotePath.lastIndexOf('/'));
    // try { await _sftp!.stat(dir); } catch (_) { await createDirectory(dir); }

    final file = await _sftp!.open(remotePath, mode: SftpFileOpenMode.write | SftpFileOpenMode.create | SftpFileOpenMode.truncate);
    
    try {
      int transferred = 0;
      // 手动处理流，以便更新进度
      await for (final chunk in content) {
        final bytes = Uint8List.fromList(chunk);
        await file.writeBytes(bytes);
        transferred += bytes.length;
        onProgress?.call(transferred);
      }
    } finally {
      // 无论成功失败，确保关闭文件句柄
      await file.close();
    }
    _cache.clear();
  }

  /// 下载文件
  /// [onProgress] 下载进度回调 (已传输字节数)
  Future<void> downloadFile(String remotePath, IOSink sink, {Function(int)? onProgress}) async {
    if (!isConnected) await connect();
    final file = await _sftp!.open(remotePath, mode: SftpFileOpenMode.read);
    
    int transferred = 0;
    await for (final chunk in file.read()) {
      sink.add(chunk);
      transferred += chunk.length;
      onProgress?.call(transferred);
    }
    await file.close();
  }

  /// 移动/重命名
  Future<void> rename(String oldPath, String newPath) async {
    if (!isConnected) await connect();
    await _sftp!.rename(oldPath, newPath);
    _cache.clear();
  }

  /// 远程复制 (占位，暂未实现服务器端复制)
  Future<void> copyRemote(String src, String dst, bool isDir) async {
     // TODO: Implement remote copy via SSH exec
     throw UnimplementedError('Remote copy not supported yet');
  }

  /// 断开连接
  void dispose() {
    _client?.close();
    _client = null;
    _sftp = null;
    _cache.clear();
  }
}
