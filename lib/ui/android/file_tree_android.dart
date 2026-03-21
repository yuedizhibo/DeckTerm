import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../setting/app_theme.dart';
import '../../function/android/storage.dart';
import '../common/context_menu_trigger.dart';
import '../../function/clipboard/clipboard_manager.dart';
import '../common/selection_manager.dart';
import '../main/widgets/file_tree.dart';

/// Android 平台本地文件树组件
class FileTreeAndroid extends StatefulWidget {
  const FileTreeAndroid({super.key});

  @override
  State<FileTreeAndroid> createState() => _FileTreeAndroidState();
}

class _FileTreeAndroidState extends State<FileTreeAndroid> {
  List<FileSystemEntity> _roots = [];
  List<QuickAccessEntry> _quickAccessEntries = [];
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
    // 解析快速访问路径，过滤掉实际不存在的目录
    final rawPaths = AndroidStorage.getQuickAccessPaths();
    final entries = <QuickAccessEntry>[];
    for (final entry in rawPaths.entries) {
      if (await Directory(entry.value).exists()) {
        entries.add(QuickAccessEntry(
          label: entry.key,
          icon: TDIcons.download,
          path: entry.value,
        ));
      }
    }
    if (mounted) {
      setState(() {
        _roots = roots;
        _quickAccessEntries = entries;
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
            Icon(TDIcons.folder_open, size: 48, color: AppColors.of(context).text3),
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
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.of(context).cardBorder, width: 1),
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
                    color: AppColors.of(context).text1,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // 快速访问区
                if (_quickAccessEntries.isNotEmpty) ...[
                  const QuickAccessSectionHeader(),
                  ..._quickAccessEntries.map((e) => _DirectoryNode(
                        key: ValueKey('qa_${e.path}'),
                        path: e.path,
                        name: e.label,
                        customIcon: e.icon,
                        customIconColor: e.iconColor,
                      )),
                  const Divider(height: 8, indent: 12, endIndent: 12),
                ],
                // 内部存储根目录
                ..._roots.map((root) => _DirectoryNode(
                      key: ValueKey('root_${root.path}'),
                      path: root.path,
                      name: '内部存储',
                      isRoot: true,
                    )),
              ],
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
  /// 快速访问入口的自定义图标，不传则使用默认的文件夹/存储图标
  final IconData? customIcon;
  final Color? customIconColor;

  const _DirectoryNode({
    super.key,
    required this.path,
    required this.name,
    this.isRoot = false,
    this.customIcon,
    this.customIconColor,
  });

  @override
  State<_DirectoryNode> createState() => _DirectoryNodeState();
}

class _DirectoryNodeState extends State<_DirectoryNode>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  List<FileSystemEntity> _children = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 350), // 会被 _adaptDuration 覆盖
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );
    _arrowAnimation = Tween<double>(begin: 0, end: 0.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// 根据子项数量动态调整展开时长，内容越多越慢，保持视觉节奏一致
  void _adaptDuration(int itemCount) {
    final ms = (300 + (itemCount / 5).floor() * 50).clamp(300, 700);
    _animController.duration = Duration(milliseconds: ms);
  }

  Future<void> _toggleExpand() async {
    if (_isExpanded) {
      _adaptDuration(_children.length);
      _animController.reverse();
      setState(() => _isExpanded = false);
      return;
    }

    setState(() => _isExpanded = true);

    if (!_hasLoaded) {
      await _loadChildren();
    }
    _adaptDuration(_children.length);
    _animController.forward();
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
              color: isSelected ? AppColors.of(context).accentDimBg : null,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  RotationTransition(
                    turns: _arrowAnimation,
                    child: Icon(
                      TDIcons.caret_right_small,
                      size: 16,
                      color: theme.grayColor6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    widget.customIcon ??
                        (widget.isRoot
                            ? TDIcons.mobile
                            : (_isExpanded ? TDIcons.folder_open : TDIcons.folder)),
                    size: 18,
                    color: widget.customIconColor ??
                        (widget.isRoot ? theme.brandNormalColor : theme.warningNormalColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TDText(
                      widget.name,
                      style: TextStyle(
                        color: isSelected ? theme.brandNormalColor : AppColors.of(context).text1,
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
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _buildChildren(context),
            ),
          ),
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
        _animController.reset();
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
            _animController.reset();
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
          color: isSelected ? AppColors.of(context).accentDimBg : null,
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
                    color: isSelected ? theme.brandNormalColor : AppColors.of(context).text1,
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
