import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../function/connect/connection_manager.dart';
import '../../function/connect/connection_model.dart';
import '../../ui/main/models/terminal_session.dart';
import 'connection_form.dart';
import '../common/context_menu_trigger.dart';

class ConnectionManagerDialog extends StatefulWidget {
  const ConnectionManagerDialog({super.key});

  @override
  State<ConnectionManagerDialog> createState() => _ConnectionManagerDialogState();
}

class _ConnectionManagerDialogState extends State<ConnectionManagerDialog> {
  final ConnectionManager _manager = ConnectionManager();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  Connection? _editing;
  bool _showForm = false; // true: 显示新建/编辑表单；false: 显示连接列表
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _manager.loadConnections();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value.trim();
    });
  }

  /// 按搜索文本过滤并排序连接列表：
  /// 1. 完美匹配（名称或 IP 与关键字完全一致）
  /// 2. 包含关键字（名称或 IP 包含关键字）
  /// 3. 其余（不匹配，排在末尾）
  List<Connection> _getFilteredConnections() {
    final all = _manager.connections;
    if (_searchText.isEmpty) return all;

    final query = _searchText.toLowerCase();
    final perfectMatch = <Connection>[];
    final contains = <Connection>[];
    final rest = <Connection>[];

    for (final conn in all) {
      final name = conn.name.toLowerCase();
      final host = conn.host.toLowerCase();
      if (name == query || host == query) {
        perfectMatch.add(conn);
      } else if (name.contains(query) || host.contains(query)) {
        contains.add(conn);
      } else {
        rest.add(conn);
      }
    }

    return [...perfectMatch, ...contains, ...rest];
  }

  void _openForm([Connection? connection]) {
    setState(() {
      _editing = connection;
      _showForm = true;
    });
  }

  void _closeForm() {
    setState(() {
      _editing = null;
      _showForm = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 响应式布局：根据屏幕宽度决定 Dialog 尺寸
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final width = isSmallScreen ? size.width * 0.9 : 600.0;
    final height = isSmallScreen ? size.height * 0.8 : 700.0;

    return Center(
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: TDTheme.of(context).whiteColor1,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Scaffold(
          appBar: AppBar(
            title: TDText(_showForm ? (_editing == null ? '新建连接' : '编辑连接') : '连接管理'),
            backgroundColor: TDTheme.of(context).whiteColor1,
            foregroundColor: TDTheme.of(context).fontGyColor1,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: _showForm
                ? IconButton(
                    icon: const Icon(TDIcons.chevron_left),
                    onPressed: _closeForm,
                  )
                : null,
            actions: [
              IconButton(
                icon: const Icon(TDIcons.close),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: TDLoading(size: TDLoadingSize.large))
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _showForm
                      ? ConnectionForm(
                          key: const ValueKey('form'),
                          connection: _editing,
                          onSave: (newConnection) async {
                            await _manager.saveConnection(newConnection);
                            if (mounted) {
                              _closeForm();
                              _loadData();
                            }
                          },
                        )
                      : Column(
                          key: const ValueKey('list'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TDInput(
                                      controller: _searchController,
                                      leftIcon: const Icon(TDIcons.search),
                                      hintText: '搜索连接...',
                                      backgroundColor: TDTheme.of(context).grayColor1,
                                      onChanged: _onSearchChanged,
                                      onSubmitted: _onSearchChanged,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  TDButton(
                                    text: '新建',
                                    icon: TDIcons.add,
                                    theme: TDButtonTheme.primary,
                                    onTap: () => _openForm(),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final filtered = _getFilteredConnections();
                                  if (_manager.connections.isEmpty) {
                                    return const Center(
                                      child: TDEmpty(
                                        type: TDEmptyType.plain,
                                        emptyText: '暂无连接，请新建',
                                      ),
                                    );
                                  }
                                  if (filtered.isEmpty) {
                                    return const Center(
                                      child: TDEmpty(
                                        type: TDEmptyType.plain,
                                        emptyText: '未找到匹配的连接',
                                      ),
                                    );
                                  }
                                  return ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: filtered.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      return _buildConnectionItem(filtered[index]);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildConnectionItem(Connection conn) {
    return ContextMenuTrigger(
      onTrigger: (position) {
        _showConnectionMenu(conn, position);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TDTheme.of(context).grayColor1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TDTheme.of(context).grayColor3),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TDTheme.of(context).brandLightColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                conn.type == ConnectionType.ssh ? TDIcons.user : TDIcons.desktop,
                size: 20,
                color: TDTheme.of(context).brandNormalColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TDText(
                    conn.name,
                    style: TextStyle(
                      fontSize: TDTheme.of(context).fontBodyLarge?.size,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TDText(
                    '${conn.username}@${conn.host}:${conn.port}',
                    style: TextStyle(
                      color: TDTheme.of(context).grayColor6,
                      fontSize: TDTheme.of(context).fontBodySmall?.size,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(TDIcons.edit, size: 18),
              onPressed: () => _openForm(conn),
              tooltip: '编辑',
            ),
            IconButton(
              icon: Icon(TDIcons.delete, size: 18, color: TDTheme.of(context).errorNormalColor),
              onPressed: () => _confirmDelete(conn),
              tooltip: '删除',
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 60),
              child: TDButton(
                text: '连接',
                size: TDButtonSize.small,
                theme: TDButtonTheme.primary,
                onTap: () => _connect(conn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _connect(Connection conn) {
    Navigator.of(context, rootNavigator: true).pop(
      TerminalSession(
        // Generate a new unique ID for the session to allow multiple sessions from the same connection config
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + conn.id,
        name: conn.name,
        type: conn.type == ConnectionType.ssh 
            ? TerminalType.ssh 
            : TerminalType.vnc,
        host: conn.host,
        port: conn.port,
        username: conn.username,
        password: conn.password,
        privateKeyPath: conn.privateKeyPath,
        isConnected: true,
      ),
    );
  }

  void _showConnectionMenu(Connection conn, Offset position) {
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
          value: 'connect',
          child: Row(
            children: [
              Icon(TDIcons.link, size: 16),
              SizedBox(width: 8),
              Text('连接'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(TDIcons.edit, size: 16),
              SizedBox(width: 8),
              Text('编辑'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(TDIcons.delete, size: 16),
              SizedBox(width: 8),
              Text('删除'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'connect') {
        _connect(conn);
      } else if (value == 'edit') {
        _openForm(conn);
      } else if (value == 'delete') {
        _confirmDelete(conn);
      }
    });
  }

  void _confirmDelete(Connection conn) {
    showDialog(
      context: context,
      builder: (dialogContext) => TDAlertDialog(
        title: '确认删除',
        content: '确定要删除连接 "${conn.name}" 吗？',
        rightBtn: TDDialogButtonOptions(
          title: '删除',
          theme: TDButtonTheme.danger,
          action: () {
            Navigator.of(dialogContext).pop();
            _manager.deleteConnection(conn.id).then((_) {
              if (mounted) _loadData();
            });
          },
        ),
      ),
    );
  }
}
