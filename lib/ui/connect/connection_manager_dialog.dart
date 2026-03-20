import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../function/connect/connection_manager.dart';
import '../../function/connect/connection_model.dart';
import '../../setting/app_theme.dart';
import '../../ui/main/models/terminal_session.dart';
import 'connection_form.dart';
import '../common/context_menu_trigger.dart';

/// 连接管理面板内容（非模态，嵌入 FloatingPanel 使用）
class ConnectionManagerPanel extends StatefulWidget {
  /// 发起连接回调，替代原 Navigator.pop 返回结果
  final ValueChanged<TerminalSession>? onConnect;

  const ConnectionManagerPanel({super.key, this.onConnect});

  @override
  State<ConnectionManagerPanel> createState() => _ConnectionManagerPanelState();
}

class _ConnectionManagerPanelState extends State<ConnectionManagerPanel> {
  final ConnectionManager _manager = ConnectionManager();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  Connection? _editing;
  bool _showForm = false;
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
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchText = value.trim());
  }

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
    if (_isLoading) {
      return const Center(child: TDLoading(size: TDLoadingSize.large));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _showForm ? _buildForm() : _buildList(),
    );
  }

  Widget _buildForm() {
    return Column(
      key: const ValueKey('form'),
      children: [
        // 表单内部导航栏
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.of(context).hoverBg),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.of(context).text2),
                onPressed: _closeForm,
                splashRadius: 16,
              ),
              Text(
                _editing == null ? '新建连接' : '编辑连接',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.of(context).text1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ConnectionForm(
            connection: _editing,
            onSave: (newConnection) async {
              await _manager.saveConnection(newConnection);
              if (mounted) {
                _closeForm();
                _loadData();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return Column(
      key: const ValueKey('list'),
      children: [
        // 搜索栏 + 新建按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).hoverBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.of(context).hoverBg),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(fontSize: 13, color: AppColors.of(context).text1),
                    decoration: InputDecoration(
                      hintText: '搜索连接...',
                      hintStyle: TextStyle(fontSize: 13, color: AppColors.of(context).text3),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.of(context).text3),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _ActionChip(
                icon: Icons.add_rounded,
                label: '新建',
                onTap: () => _openForm(),
              ),
            ],
          ),
        ),
        // 连接列表
        Expanded(
          child: Builder(
            builder: (context) {
              final filtered = _getFilteredConnections();
              if (_manager.connections.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dns_outlined, size: 40, color: AppColors.of(context).divider),
                      const SizedBox(height: 12),
                      Text('暂无连接，请新建', style: TextStyle(color: AppColors.of(context).text3, fontSize: 13)),
                    ],
                  ),
                );
              }
              if (filtered.isEmpty) {
                return Center(
                  child: Text('未找到匹配的连接', style: TextStyle(color: AppColors.of(context).text3, fontSize: 13)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) => _buildConnectionItem(filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionItem(Connection conn) {
    return ContextMenuTrigger(
      onTrigger: (position) => _showConnectionMenu(conn, position),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.of(context).hoverBg,
          onTap: () => _connect(conn),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.of(context).cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.of(context).cardBorder),
            ),
            child: Row(
              children: [
                // 类型图标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: conn.type == ConnectionType.ssh
                          ? [AppColors.of(context).accent, const Color(0xFF1D4ED8)]
                          : [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    conn.type == ConnectionType.ssh ? Icons.terminal_rounded : Icons.desktop_windows_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                // 名称 + 地址
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conn.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.of(context).text1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${conn.username ?? ''}@${conn.host}:${conn.port}',
                        style: TextStyle(fontSize: 11, color: AppColors.of(context).text3),
                      ),
                    ],
                  ),
                ),
                // 操作按钮
                _SmallIconBtn(icon: Icons.edit_outlined, onTap: () => _openForm(conn), tooltip: '编辑'),
                const SizedBox(width: 2),
                _SmallIconBtn(icon: Icons.delete_outline, onTap: () => _confirmDelete(conn), tooltip: '删除', hoverColor: Colors.redAccent),
                const SizedBox(width: 6),
                // 连接按钮
                _ActionChip(
                  icon: Icons.login_rounded,
                  label: '连接',
                  onTap: () => _connect(conn),
                  isPrimary: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _connect(Connection conn) {
    final session = TerminalSession(
      id: '${DateTime.now().millisecondsSinceEpoch}_${conn.id}',
      name: conn.name,
      type: conn.type == ConnectionType.ssh ? TerminalType.ssh : TerminalType.vnc,
      host: conn.host,
      port: conn.port,
      username: conn.username,
      password: conn.password,
      privateKeyPath: conn.privateKeyPath,
      isConnected: true,
    );
    widget.onConnect?.call(session);
  }

  void _showConnectionMenu(Connection conn, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem(value: 'connect', child: Row(children: [Icon(Icons.login_rounded, size: 16), SizedBox(width: 8), Text('连接')])),
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('编辑')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16), SizedBox(width: 8), Text('删除')])),
      ],
    ).then((value) {
      if (value == 'connect') _connect(conn);
      else if (value == 'edit') _openForm(conn);
      else if (value == 'delete') _confirmDelete(conn);
    });
  }

  void _confirmDelete(Connection conn) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.of(context).menuBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(color: AppColors.of(context).text1, fontSize: 16)),
        content: Text('确定要删除连接 "${conn.name}" 吗？', style: TextStyle(color: AppColors.of(context).text2, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('取消', style: TextStyle(color: AppColors.of(context).text3)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _manager.deleteConnection(conn.id).then((_) {
                if (mounted) _loadData();
              });
            },
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

/// 小图标按钮
class _SmallIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? hoverColor;

  const _SmallIconBtn({required this.icon, required this.onTap, this.tooltip, this.hoverColor});

  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.of(context).cardBorder : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: _hovered
                  ? (widget.hoverColor ?? Colors.white60)
                  : AppColors.of(context).text3,
            ),
          ),
        ),
      ),
    );
  }
}

/// 操作芯片按钮（新建/连接等）
class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionChip({required this.icon, required this.label, required this.onTap, this.isPrimary = false});

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isPrimary ? AppColors.of(context).accent : Colors.white;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_hovered ? baseColor.withOpacity(0.25) : baseColor.withOpacity(0.15))
                : (_hovered ? AppColors.of(context).cardBorder : AppColors.of(context).hoverBg),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.isPrimary
                  ? baseColor.withOpacity(0.3)
                  : AppColors.of(context).cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.isPrimary ? baseColor : Colors.white54),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.isPrimary ? baseColor : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
