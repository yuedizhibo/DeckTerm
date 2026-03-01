import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../function/android/storage.dart';
import '../common/context_menu_trigger.dart';
import '../../function/clipboard/clipboard_manager.dart';
import '../common/selection_manager.dart';
import '../../function/transfer/transfer_manager.dart';
import '../common/transfer_progress_widget.dart';

/// Android 平台本地文件树组件
class FileTreeAndroid extends StatefulWidget {
  const FileTreeAndroid({super.key});

  @override
  State<FileTreeAndroid> createState() => _FileTreeAndroidState();
}

class _FileTreeAndroidState extends State<FileTreeAndroid> {
  List<FileSystemEntity> _roots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoots();
    FileClipboardManager().addListener(_onClipboardChanged);
    SelectionManager().addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    FileClipboardManager().removeListener(_onClipboardChanged);
    SelectionManager().removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onClipboardChanged() {
    if (mounted) setState(() {});
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRoots() async {
    setState(() => _isLoading = true);
    final roots = await AndroidStorage.getRootDirectories();
    if (mounted) {
      setState(() {
        _roots = roots;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: TDLoading(size: TDLoadingSize.medium));
    }

    if (_roots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TDIcons.folder_open, size: 48, color: TDTheme.of(context).grayColor4),
            const SizedBox(height: 12),
            TDText(
              '未找到存储设备或无权限',
              style: TextStyle(color: TDTheme.of(context).grayColor6),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: TDTheme.of(context).whiteColor1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TDTheme.of(context).grayColor4, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TDText(
                  '本地存储',
                  style: TextStyle(
                    fontSize: TDTheme.of(context).fontTitleMedium?.size,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(TDIcons.refresh),
                  onPressed: _loadRoots,
                  tooltip: '刷新',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 传输进度条 (下载任务)
          const TransferProgressWidget(type: TransferType.download),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: _roots.map((root) => _DirectoryNode(
                path: root.path,
                name: '内部存储', // Android 主存储通常显示为 Internal Storage
                isRoot: true,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryNode extends StatefulWidget {
  final String path;
  final String name;
  final bool isRoot;

  const _DirectoryNode({
    required this.path,
    required this.name,
    this.isRoot = false,
  });

  @override
  State<_DirectoryNode> createState() => _DirectoryNodeState();
}

class _DirectoryNodeState extends State<_DirectoryNode> {
  bool _isExpanded = false;
  List<FileSystemEntity> _children = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  Future<void> _toggleExpand() async {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      return;
    }

    setState(() {
      _isExpanded = true;
    });

    if (!_hasLoaded) {
      await _loadChildren();
    }
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    final children = await AndroidStorage.getDirectoryContent(widget.path);
    if (mounted) {
      setState(() {
        _children = children;
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = TDTheme.of(context);
    final isSelected = SelectionManager().isSelected(widget.path, 'local');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContextMenuTrigger(
          onTrigger: (position) {
            SelectionManager().select(widget.path, 'local');
            _showContextMenu(context, position);
          },
          child: InkWell(
            onTap: () {
              SelectionManager().select(widget.path, 'local');
              _toggleExpand();
            },
            child: Container(
              color: isSelected ? theme.brandColor1 : null,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? TDIcons.caret_down_small : TDIcons.caret_right_small,
                    size: 16,
                    color: theme.grayColor6,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    widget.isRoot ? TDIcons.mobile : (_isExpanded ? TDIcons.folder_open : TDIcons.folder),
                    size: 18,
                    color: widget.isRoot ? theme.brandNormalColor : theme.warningNormalColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TDText(
                      widget.name,
                      style: TextStyle(
                        color: isSelected ? theme.brandNormalColor : theme.textColorPrimary,
                        fontWeight: isSelected ? FontWeight.w500 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _buildChildren(context),
          ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final clipboard = FileClipboardManager();
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(
          height: 32,
          value: 'refresh',
          child: Row(
            children: [
              Icon(TDIcons.refresh, size: 16),
              SizedBox(width: 8),
              Text('刷新', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (clipboard.hasItem)
          const PopupMenuItem(
            height: 32,
            value: 'paste',
            child: Row(
              children: [
                Icon(TDIcons.assignment_checked, size: 16),
                SizedBox(width: 8),
                Text('粘贴', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
    ).then((value) async {
      if (value == 'refresh') {
        setState(() {
          _isExpanded = false;
          _hasLoaded = false;
          _isLoading = true;
        });
        _toggleExpand(); // 重新加载
      } else if (value == 'paste') {
        try {
          await clipboard.paste(widget.path, FileSourceType.local);
          if (context.mounted) {
            TDToast.showSuccess('粘贴成功', context: context);
            setState(() {
              _isExpanded = false;
              _hasLoaded = false;
              _isLoading = true;
            });
            _toggleExpand(); // 刷新
          }
        } catch (e) {
          if (context.mounted) {
            TDToast.showFail('粘贴失败: $e', context: context);
          }
        }
      }
    });
  }

  Widget _buildChildren(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: TDText('加载中...', style: TextStyle(fontSize: 12)),
      );
    }

    if (_children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: TDText('(空)', style: TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }

    return Column(
      children: _children.map((entity) {
        final name = AndroidStorage.getName(entity.path);
        // 忽略隐藏文件
        if (name.startsWith('.')) return const SizedBox.shrink();

        if (entity is Directory) {
          return _DirectoryNode(path: entity.path, name: name);
        } else {
          return _FileNode(path: entity.path, name: name, size: (entity as File).lengthSync());
        }
      }).toList(),
    );
  }
}

class _FileNode extends StatelessWidget {
  final String path; // 需要完整路径
  final String name;
  final int size;

  const _FileNode({
    required this.path,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = TDTheme.of(context);
    final isSelected = SelectionManager().isSelected(path, 'local');

    return ContextMenuTrigger(
      onTrigger: (position) {
        SelectionManager().select(path, 'local');
        _showContextMenu(context, position);
      },
      child: InkWell(
        onTap: () {
          SelectionManager().select(path, 'local');
          // TODO: 打开文件
        },
        child: Container(
          color: isSelected ? theme.brandColor1 : null,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Icon(_getFileIcon(name), size: 16, color: theme.grayColor6),
              const SizedBox(width: 8),
              Expanded(
                child: TDText(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? theme.brandNormalColor : theme.textColorPrimary,
                    fontWeight: isSelected ? FontWeight.w500 : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TDText(
                _formatSize(size),
                style: TextStyle(fontSize: 10, color: theme.grayColor5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(
          height: 32,
          value: 'copy',
          child: Row(
            children: [
              Icon(TDIcons.file_copy, size: 16),
              SizedBox(width: 8),
              Text('复制', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          height: 32,
          value: 'cut',
          child: Row(
            children: [
              Icon(TDIcons.cut, size: 16),
              SizedBox(width: 8),
              Text('剪切', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy') {
        FileClipboardManager().copyLocal(path, name, false);
        TDToast.showSuccess('已复制', context: context);
      } else if (value == 'cut') {
        FileClipboardManager().cutLocal(path, name, false);
        TDToast.showSuccess('已剪切', context: context);
      }
    });
  }

  String _formatSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': case 'java': case 'kt': case 'cs': case 'py': case 'js': case 'ts': return TDIcons.code;
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'bmp': case 'svg': return TDIcons.image;
      case 'pdf': return TDIcons.file_pdf;
      case 'doc': case 'docx': case 'txt': case 'md': return TDIcons.file_word;
      case 'xls': case 'xlsx': return TDIcons.file_excel;
      case 'ppt': case 'pptx': return TDIcons.file_powerpoint;
      case 'mp3': case 'wav': case 'flac': return TDIcons.sound;
      case 'mp4': case 'avi': case 'mkv': case 'mov': return TDIcons.video;
      case 'zip': case 'rar': case '7z': case 'tar': return TDIcons.file_zip;
      case 'exe': case 'bat': case 'cmd': case 'sh': return TDIcons.setting;
      default: return TDIcons.file;
    }
  }
}
