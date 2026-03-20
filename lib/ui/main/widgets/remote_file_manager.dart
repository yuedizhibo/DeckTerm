import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../../../setting/app_theme.dart';
import '../../../function/dev-file/sftp_manager.dart';
import '../models/terminal_session.dart';
import '../../../../ui/common/context_menu_trigger.dart';
import '../../../../function/clipboard/clipboard_manager.dart';
import '../../../../ui/common/selection_manager.dart';
import '../../../../function/transfer/transfer_manager.dart';

/// 远程文件管理组件 (树状结构)
class RemoteFileManager extends StatefulWidget {
  final TerminalSession? session;

  const RemoteFileManager({
    super.key,
    this.session,
  });

  @override
  State<RemoteFileManager> createState() => _RemoteFileManagerState();
}

class _RemoteFileManagerState extends State<RemoteFileManager> {
  SftpManager? _sftpManager;
  bool _isLoading = false;
  String? _error;
  // 根目录路径，默认为 / (System Root)
  final String _rootPath = '/';

  @override
  void didUpdateWidget(covariant RemoteFileManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session?.id != oldWidget.session?.id) {
      _initSftp();
    }
  }

  @override
  void initState() {
    super.initState();
    _initSftp();
  }

  @override
  void dispose() {
    _sftpManager?.dispose();
    super.dispose();
  }

  Future<void> _initSftp() async {
    _sftpManager?.dispose();
    _sftpManager = null;
    _error = null;

    if (widget.session == null || widget.session!.type != TerminalType.ssh) {
      if (mounted) setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      _sftpManager = SftpManager(widget.session!);
      await _sftpManager!.connect();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '连接失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createDirectory(String parentPath, VoidCallback onSuccess) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => TDInputDialog(
        textEditingController: controller,
        title: '新建文件夹',
        hintText: '请输入文件夹名称',
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final newPath = parentPath == '.' ? result : '$parentPath/$result';
        await _sftpManager!.createDirectory(newPath);
        if (mounted) {
          TDToast.showSuccess('创建成功', context: context);
          onSuccess();
        }
      } catch (e) {
        if (mounted) {
          TDToast.showFail('创建失败: $e', context: context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.of(context).cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TDText(
                  '远程文件',
                  style: TextStyle(
                    fontSize: textScaler.scale(TDTheme.of(context).fontTitleMedium?.size ?? 16),
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).text1,
                  ),
                ),
                const Spacer(),
                if (_sftpManager != null) ...[
                  IconButton(
                    icon: const Icon(TDIcons.refresh),
                    onPressed: _initSftp, // 重新连接并刷新根目录
                    tooltip: '重连',
                  ),
                  IconButton(
                    icon: const Icon(TDIcons.add_circle),
                    onPressed: () => _createDirectory(_rootPath, () {
                      setState(() {}); // 简单粗暴刷新整个树（优化点：只刷新根节点）
                    }),
                    tooltip: '在根目录新建',
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容区域
          Expanded(
            child: _buildContent(context, textScaler),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, TextScaler textScaler) {
    if (widget.session == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TDIcons.link_unlink, size: 48, color: AppColors.of(context).text3),
            const SizedBox(height: 16),
            TDText(
              '未连接到设备',
              style: TextStyle(
                color: TDTheme.of(context).grayColor6,
                fontSize: textScaler.scale(14),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: TDLoading(size: TDLoadingSize.medium, text: '连接中...'));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TDIcons.error_circle, size: 48, color: TDTheme.of(context).errorNormalColor),
            const SizedBox(height: 16),
            TDText(
              _error!,
              style: TextStyle(
                color: TDTheme.of(context).errorNormalColor,
                fontSize: textScaler.scale(14),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TDButton(
              text: '重试',
              size: TDButtonSize.small,
              type: TDButtonType.outline,
              onTap: _initSftp,
            ),
          ],
        ),
      );
    }

    // 树状结构根节点
    // 使用 ListView 包裹以支持滚动
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _SftpDirectoryNode(
          sftpManager: _sftpManager!,
          path: _rootPath,
          name: '/', // 显示为根目录 / (实际对应 SSH 登录后的当前目录)
          isRoot: true,
        ),
      ],
    );
  }
}

/// SFTP 目录节点
class _SftpDirectoryNode extends StatefulWidget {
  final SftpManager sftpManager;
  final String path;
  final String name;
  final bool isRoot;

  const _SftpDirectoryNode({
    super.key,
    required this.sftpManager,
    required this.path,
    required this.name,
    this.isRoot = false,
  });

  @override
  State<_SftpDirectoryNode> createState() => _SftpDirectoryNodeState();
}

class _SftpDirectoryNodeState extends State<_SftpDirectoryNode> {
  bool _isExpanded = false;
  bool _hasLoaded = false;
  List<SftpName> _children = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 根节点默认展开
    if (widget.isRoot) {
      _toggleExpand();
    }
  }

  Future<void> _toggleExpand() async {
    if (_isExpanded && widget.isRoot && _hasLoaded) {
       // 根节点点击时不折叠，只刷新？或者保持原样。
       // 这里设计为：根节点可以折叠，但默认展开。
    }

    if (_isExpanded) {
      setState(() => _isExpanded = false);
      return;
    }

    setState(() {
      _isExpanded = true;
    });

    if (!_hasLoaded || widget.isRoot) { // 根节点每次展开都刷新，或者添加刷新机制
      await _loadChildren();
    }
  }

  Future<void> _loadChildren({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final children = await widget.sftpManager.listDirectory(widget.path, useCache: !forceRefresh);
      if (mounted) {
        setState(() {
          _children = children;
          _hasLoaded = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        TDToast.showFail('加载失败: $e', context: context);
      }
    }
  }

  Future<void> _deleteItem(SftpName item) async {
    try {
      final fullPath = widget.path == '/' ? '/${item.filename}' : '${widget.path}/${item.filename}';
      await widget.sftpManager.delete(
        fullPath,
        isDirectory: item.attr.isDirectory,
      );
      if (mounted) {
        TDToast.showSuccess('删除成功', context: context);
        _loadChildren(forceRefresh: true); // 刷新当前列表
      }
    } catch (e) {
      if (mounted) {
        TDToast.showFail('删除失败: $e', context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final theme = TDTheme.of(context);
    final isSelected = SelectionManager().isSelected(widget.path, 'remote');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContextMenuTrigger(
          onTrigger: (position) {
            SelectionManager().select(widget.path, 'remote');
            _showDirectoryMenu(context, position);
          },
          child: InkWell(
            onTap: () {
              SelectionManager().select(widget.path, 'remote');
              _toggleExpand();
            },
            child: Container(
              color: isSelected ? AppColors.of(context).accentDimBg : null,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? TDIcons.caret_down_small : TDIcons.caret_right_small,
                    size: textScaler.scale(16),
                    color: theme.grayColor6,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    widget.isRoot ? TDIcons.server : (_isExpanded ? TDIcons.folder_open : TDIcons.folder),
                    size: textScaler.scale(18),
                    color: widget.isRoot ? theme.brandNormalColor : theme.warningNormalColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TDText(
                      widget.name,
                      style: TextStyle(
                        fontSize: textScaler.scale(theme.fontBodyMedium?.size ?? 14),
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
        if (_isExpanded)
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
              child: TDText(
                '加载中...',
                style: TextStyle(
                  fontSize: textScaler.scale(12),
                  color: theme.grayColor6,
                ),
              ),
            )
          else if (_children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
              child: TDText(
                '(空)',
                style: TextStyle(
                  fontSize: textScaler.scale(12),
                  color: theme.grayColor5,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 16), // 缩进
              child: Column(
                children: _children.map<Widget>((item) {
                  final fullPath = widget.path == '/' ? '/${item.filename}' : '${widget.path}/${item.filename}';
                  if (item.attr.isDirectory) {
                    return _SftpDirectoryNode(
                      key: ValueKey(fullPath), // 保持状态
                      sftpManager: widget.sftpManager,
                      path: fullPath,
                      name: item.filename,
                    );
                  } else {
                    return _SftpFileNode(
                      name: item.filename,
                      size: item.attr.size,
                      onDelete: () => _deleteItem(item),
                    );
                  }
                }).toList(),
              ),
            ),
      ],
    );
  }

  void _showDirectoryMenu(BuildContext context, [Offset? position]) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = position ?? renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 1,
        offset.dy + 1,
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
        if (FileClipboardManager().hasItem)
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
        _loadChildren(forceRefresh: true);
      } else if (value == 'paste') {
        try {
          setState(() => _isLoading = true);
          await FileClipboardManager().paste(
            widget.path, 
            FileSourceType.remote, 
            targetSftp: widget.sftpManager
          );
          if (context.mounted) {
            TDToast.showSuccess('粘贴成功', context: context);
            _loadChildren(forceRefresh: true);
          }
        } catch (e) {
          if (context.mounted) {
            TDToast.showFail('粘贴失败: $e', context: context);
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    });
  }
}

/// SFTP 文件节点
class _SftpFileNode extends StatelessWidget {
  final String name;
  final int? size;
  final VoidCallback onDelete;

  const _SftpFileNode({
    required this.name,
    this.size,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final theme = TDTheme.of(context);

    return ContextMenuTrigger(
      onTrigger: (position) {
        _showContextMenu(context, position);
      },
      child: InkWell(
        onTap: () {
          // TODO: 文件操作
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 20), // 对齐缩进 (Icon + Caret)
              Icon(
                _getFileIcon(name),
                size: textScaler.scale(16),
                color: theme.grayColor6,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TDText(
                  name,
                  style: TextStyle(
                    fontSize: textScaler.scale(theme.fontBodyMedium?.size ?? 14),
                    color: AppColors.of(context).text1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 文件大小
              if (size != null)
                TDText(
                  _formatSize(size),
                  style: TextStyle(
                    fontSize: textScaler.scale(10),
                    color: theme.grayColor5,
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    // 暂时只提供简单的菜单，后续可扩展打开、删除等
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
        const PopupMenuItem(
          height: 32,
          value: 'delete',
          child: Row(
            children: [
              Icon(TDIcons.delete, size: 16),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        onDelete();
      }
    });
  }

  String _formatSize(int? size) {
    if (size == null) return '';
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
