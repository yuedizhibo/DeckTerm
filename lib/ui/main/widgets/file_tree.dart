import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 文件节点数据模型
class FileNode {
  final String name;
  final bool isDirectory;
  final List<FileNode> children;
  final String path;
  final int? size;

  FileNode({
    required this.name,
    this.isDirectory = false,
    this.children = const [],
    required this.path,
    this.size,
  });

  String get formattedSize {
    if (size == null) return '-';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1024 * 1024 * 1024) {
      return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 文件树抽象组件的基类
abstract class FileTreeBase extends StatefulWidget {
  final String rootPath;
  final Function(FileNode)? onFileTap;
  final Function(FileNode, bool)? onFolderToggle;

  const FileTreeBase({
    super.key,
    required this.rootPath,
    this.onFileTap,
    this.onFolderToggle,
  });
}

/// 文件树抽象组件的 State 基类，包含共享 UI 和逻辑
abstract class FileTreeBaseState<T extends FileTreeBase> extends State<T> {
  FileNode? _rootNode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final node = await loadFileTree();
      setState(() {
        _rootNode = node;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _rootNode = FileNode(name: '加载失败: $e', path: widget.rootPath);
      });
    }
  }

  /// 加载文件树数据的抽象方法，由子类实现
  Future<FileNode> loadFileTree();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: TDCircleIndicator());
    }
    if (_rootNode == null) {
      return const Center(child: TDEmpty(emptyText: '暂无数据'));
    }
    // 注意：这里的 build 方法不再包含外部容器和标题，
    // 这些由平台特定的 State 实现来提供。
    return _buildFileTree(_rootNode!);
  }

  Widget _buildFileTree(FileNode node) {
    // 具体的树节点渲染逻辑由平台特定的 State 提供，
    // 因为它们可能包含不同的交互或样式。
    // 如果节点渲染是完全相同的，可以将_FileTreeNode的逻辑移到这里。
    // 但为了平台差异化，最好让子类实现。
    // 此处返回一个占位符，强制子类重写 build 方法或提供具体的节点构建器。
    return const SizedBox.shrink();
  }
}
