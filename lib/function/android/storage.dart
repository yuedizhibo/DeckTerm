import 'dart:io';

/// Android 本地文件存储功能
class AndroidStorage {
  /// 获取根目录列表 (通常从 /storage/emulated/0 开始)
  /// 注意：在 Android 11+ 上访问所有文件需要 MANAGE_EXTERNAL_STORAGE 权限，
  /// 或者只能访问应用私有目录和公共媒体目录。
  /// 这里为了演示，假设有权限或只访问主存储。
  static Future<List<FileSystemEntity>> getRootDirectories() async {
    // 通常 Android 的主存储路径
    final root = Directory('/storage/emulated/0');
    if (await root.exists()) {
      return [root];
    }
    // 备选：尝试获取外部存储目录
    // final externalDirs = await getExternalStorageDirectories();
    return [];
  }

  /// 快速访问入口路径（显示名称 → 完整路径）
  static Map<String, String> getQuickAccessPaths() {
    return {
      '下载': '/storage/emulated/0/Download',
    };
  }

  /// 获取指定目录下的内容
  static Future<List<FileSystemEntity>> getDirectoryContent(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return [];
    }

    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      
      // 排序：文件夹在前，文件在后
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      return entities;
    } catch (e) {
      // 权限不足或其他错误
      return [];
    }
  }

  /// 获取文件/目录名称
  static String getName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}
