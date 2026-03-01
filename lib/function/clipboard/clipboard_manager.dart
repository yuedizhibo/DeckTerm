import 'dart:io';
import 'package:flutter/material.dart';
import '../dev-file/sftp_manager.dart';
import '../transfer/transfer_manager.dart';

enum FileSourceType {
  local,
  remote,
}

enum ClipboardAction {
  copy,
  cut,
}

class FileClipboardItem {
  final String path;
  final FileSourceType source;
  final ClipboardAction action;
  final String name;
  final bool isDirectory;
  // 仅 remote 需要
  final SftpManager? sftpManager;

  FileClipboardItem({
    required this.path,
    required this.source,
    required this.action,
    required this.name,
    required this.isDirectory,
    this.sftpManager,
  });
}

class FileClipboardManager extends ChangeNotifier {
  static final FileClipboardManager _instance = FileClipboardManager._internal();
  factory FileClipboardManager() => _instance;
  FileClipboardManager._internal();

  FileClipboardItem? _item;

  FileClipboardItem? get item => _item;
  bool get hasItem => _item != null;

  void copyLocal(String path, String name, bool isDirectory) {
    _item = FileClipboardItem(
      path: path,
      source: FileSourceType.local,
      action: ClipboardAction.copy,
      name: name,
      isDirectory: isDirectory,
    );
    notifyListeners();
  }

  void cutLocal(String path, String name, bool isDirectory) {
    _item = FileClipboardItem(
      path: path,
      source: FileSourceType.local,
      action: ClipboardAction.cut,
      name: name,
      isDirectory: isDirectory,
    );
    notifyListeners();
  }

  void copyRemote(String path, String name, bool isDirectory, SftpManager sftpManager) {
    _item = FileClipboardItem(
      path: path,
      source: FileSourceType.remote,
      action: ClipboardAction.copy,
      name: name,
      isDirectory: isDirectory,
      sftpManager: sftpManager,
    );
    notifyListeners();
  }

  void cutRemote(String path, String name, bool isDirectory, SftpManager sftpManager) {
    _item = FileClipboardItem(
      path: path,
      source: FileSourceType.remote,
      action: ClipboardAction.cut,
      name: name,
      isDirectory: isDirectory,
      sftpManager: sftpManager,
    );
    notifyListeners();
  }

  void clear() {
    _item = null;
    notifyListeners();
  }

  /// 执行粘贴操作
  /// [targetPath] 目标文件夹路径
  /// [targetType] 目标位置类型 (local/remote)
  /// [targetSftp] 如果目标是 remote，需要提供 SftpManager
  Future<void> paste(String targetPath, FileSourceType targetType, {SftpManager? targetSftp}) async {
    if (_item == null) return;

    final source = _item!;
    final destPath = targetType == FileSourceType.local 
        ? (targetPath.endsWith(Platform.pathSeparator) ? '$targetPath${source.name}' : '$targetPath${Platform.pathSeparator}${source.name}')
        : (targetPath == '/' ? '/${source.name}' : '$targetPath/${source.name}');

    try {
      if (source.source == FileSourceType.local && targetType == FileSourceType.local) {
        // 本地 -> 本地
        await _pasteLocalToLocal(source.path, destPath, source.isDirectory, source.action);
      } else if (source.source == FileSourceType.local && targetType == FileSourceType.remote) {
        // 本地 -> 远程 (上传)
        if (targetSftp == null) throw Exception('Target SFTP manager is null');
        await _pasteLocalToRemote(source.path, destPath, source.isDirectory, source.action, targetSftp);
      } else if (source.source == FileSourceType.remote && targetType == FileSourceType.local) {
        // 远程 -> 本地 (下载)
        if (source.sftpManager == null) throw Exception('Source SFTP manager is null');
        await _pasteRemoteToLocal(source.path, destPath, source.isDirectory, source.action, source.sftpManager!);
      } else if (source.source == FileSourceType.remote && targetType == FileSourceType.remote) {
        // 远程 -> 远程 (如果是同一个连接，则是移动/复制；如果是不同连接，则是下载再上传)
        // 目前简化处理，假设不支持跨服务器直接传输，只支持同一连接内的操作
        if (source.sftpManager != targetSftp) {
           throw Exception('Cross-server paste not supported yet');
        }
        await _pasteRemoteToRemote(source.path, destPath, source.isDirectory, source.action, targetSftp!);
      }

      // 如果是剪切操作，完成后清除剪贴板
      if (source.action == ClipboardAction.cut) {
        clear();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _pasteLocalToLocal(String src, String dst, bool isDir, ClipboardAction action) async {
    if (isDir) {
      final srcDir = Directory(src);
      if (action == ClipboardAction.copy) {
        // 递归复制目录
        await _copyDirectory(srcDir, Directory(dst));
      } else {
        await srcDir.rename(dst);
      }
    } else {
      final srcFile = File(src);
      if (action == ClipboardAction.copy) {
        await srcFile.copy(dst);
      } else {
        await srcFile.rename(dst);
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = destination.path + Platform.pathSeparator + entity.uri.pathSegments.last;
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  Future<void> _pasteLocalToRemote(String src, String dst, bool isDir, ClipboardAction action, SftpManager sftp) async {
    if (isDir) {
       // TODO: 递归上传目录
       throw Exception('Folder upload not implemented yet');
    } else {
      final file = File(src);
      if (!await file.exists()) {
        throw Exception('Source file does not exist: $src');
      }
      final size = await file.length();
      
      // 创建传输任务
      final task = TransferManager().addTask(
        file.uri.pathSegments.last,
        src,
        dst,
        TransferType.upload,
        size,
      );

      try {
        final stream = file.openRead();
        // 上传
        await sftp.uploadFile(dst, stream, onProgress: (transferred) {
          TransferManager().updateProgress(task.id, transferred);
        });
        
        TransferManager().completeTask(task.id);
        
        if (action == ClipboardAction.cut) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Upload failed: $e');
        TransferManager().failTask(task.id, e.toString());
        rethrow;
      }
    }
  }

  Future<void> _pasteRemoteToLocal(String src, String dst, bool isDir, ClipboardAction action, SftpManager sftp) async {
    if (isDir) {
      // TODO: 递归下载目录
      throw Exception('Folder download not implemented yet');
    } else {
      // 获取远程文件大小 (这里暂时无法精确获取，因为 item 信息没有直接传递过来，可能需要先 stat)
      // 简单起见，如果 sftpManager 有缓存或提供方法获取最好。这里先设为 0 或 100 以显示不确定进度，或者尝试 stat
      // 实际上，_item 里有 name，但没有 size。为了更好的体验，应该在 ClipboardItem 里带上 size。
      // 这里先尝试获取
      // 由于没有 stat 方法暴露，暂时设为 0 (未知大小) 或者让 downloadFile 负责
      // 改进：SftpManager.downloadFile 内部可以先 stat，但为了保持接口简单，这里先创建任务。
      
      final task = TransferManager().addTask(
        src.split('/').last,
        src,
        dst,
        TransferType.download,
        0, // 未知大小，进度条可能只会显示已传输量或不确定状态
      );

      try {
        final file = File(dst);
        final sink = file.openWrite();
        // 下载
        await sftp.downloadFile(src, sink, onProgress: (transferred) {
          TransferManager().updateProgress(task.id, transferred);
        });
        await sink.close();

        TransferManager().completeTask(task.id);

        if (action == ClipboardAction.cut) {
          await sftp.delete(src, isDirectory: false);
        }
      } catch (e) {
        TransferManager().failTask(task.id, e.toString());
        rethrow;
      }
    }
  }

  Future<void> _pasteRemoteToRemote(String src, String dst, bool isDir, ClipboardAction action, SftpManager sftp) async {
    if (action == ClipboardAction.cut) {
      // 移动/重命名
      await sftp.rename(src, dst);
    } else {
      // 远程复制 (SFTP 协议本身不支持服务器端复制，通常需要下载再上传，或者执行 SSH 命令 cp)
      // 这里为了性能，应该使用 SSH exec cp 命令，而不是 SFTP 流
      // 暂时抛出未实现，或者回退到 SSH 命令
      // 简单起见，如果提供了 SSH Client，可以用 exec
      await sftp.copyRemote(src, dst, isDir);
    }
  }
}
