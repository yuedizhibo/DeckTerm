import 'dart:io';

class WindowsStorage {
  /// 获取根目录（驱动器列表）
  static Future<List<Directory>> getDrives() async {
    if (!Platform.isWindows) return [];
    
    final drives = <Directory>[];
    // A-Z 驱动器检测
    for (var code = 65; code <= 90; code++) {
      final driveLetter = String.fromCharCode(code);
      final drive = Directory('$driveLetter:\\');
      if (await drive.exists()) {
        drives.add(drive);
      }
    }
    return drives;
  }

  /// 快速访问入口路径（显示名称 → 完整路径）
  /// 依赖 USERPROFILE 环境变量（Windows 标准，指向当前用户目录）
  static Map<String, String> getQuickAccessPaths() {
    final home = Platform.environment['USERPROFILE'] ?? '';
    if (home.isEmpty) return {};
    return {
      '桌面': '$home\\Desktop',
      '下载': '$home\\Downloads',
    };
  }

  /// 获取指定目录下的内容（文件和子目录）
  static Future<List<FileSystemEntity>> getDirectoryContent(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    try {
      final entities = await dir.list().toList();
      // 排序：文件夹在前，文件在后；同类按名称排序
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
}
