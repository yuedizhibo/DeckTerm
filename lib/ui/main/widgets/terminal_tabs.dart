import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../models/terminal_session.dart';
import '../ssh/ssh_terminal_view.dart';
import '../../../ui/common/context_menu_trigger.dart';

/// VNC 远程桌面组件（占位实现）
class VncDesktopView extends StatelessWidget {
  final TerminalSession session;

  const VncDesktopView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              TDIcons.desktop,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            TDText(
              'VNC 远程桌面',
              style: TextStyle(fontSize: TDTheme.of(context).fontTitleMedium?.size, height: TDTheme.of(context).fontTitleMedium?.height, fontWeight: TDTheme.of(context).fontTitleMedium?.fontWeight).copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            TDText(
              '${session.connectionString}',
              style: TextStyle(fontSize: TDTheme.of(context).fontBodySmall?.size, height: TDTheme.of(context).fontBodySmall?.height, fontWeight: TDTheme.of(context).fontBodySmall?.fontWeight).copyWith(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            TDButton(
              text: session.isConnected ? '断开连接' : '连接',
              theme: TDButtonTheme.primary,
              onTap: () {
                // TODO: 实现 VNC 连接逻辑
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 终端标签页组件
class TerminalTabs extends StatefulWidget {
  final List<TerminalSession> sessions;
  final VoidCallback? onAddSession;
  final Function(String sessionId)? onRemoveSession;
  final Function(TerminalSession)? onSessionSwitch;

  const TerminalTabs({
    super.key,
    this.sessions = const [],
    this.onAddSession,
    this.onRemoveSession,
    this.onSessionSwitch,
  });

  @override
  State<TerminalTabs> createState() => _TerminalTabsState();
}

class _TerminalTabsState extends State<TerminalTabs> with TickerProviderStateMixin {
  late TabController _tabController;
  late List<TerminalSession> _sessions;
  int _currentIndex = 0;
  // 缓存 GlobalKey，确保 Widget 状态在 IndexedStack 重建时保留
  final Map<String, GlobalKey> _tabKeys = {};

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.sessions);
    _updateKeys();
    _tabController = TabController(
      length: _sessions.length, // Tab 数不再包含添加按钮
      vsync: this,
    );
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void didUpdateWidget(covariant TerminalTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessions.length != _sessions.length || 
        !_areSessionsEqual(widget.sessions, _sessions)) {
      _sessions = List.from(widget.sessions);
      _updateKeys();
      _tabController.removeListener(_handleTabSelection);
      // 重新计算初始索引，确保不超过新列表长度
      int newIndex = _currentIndex;
      if (_sessions.isEmpty) {
        newIndex = 0;
      } else if (newIndex >= _sessions.length) {
        newIndex = _sessions.length - 1;
      }
      _currentIndex = newIndex;
      
      _tabController = TabController(
        length: _sessions.length, 
        vsync: this, 
        initialIndex: newIndex
      );
      _tabController.addListener(_handleTabSelection);
    }
  }

  bool _areSessionsEqual(List<TerminalSession> a, List<TerminalSession> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _updateKeys() {
    // 移除已不存在的 key
    final currentIds = _sessions.map((s) => s.id).toSet();
    _tabKeys.removeWhere((id, _) => !currentIds.contains(id));
    
    // 为新会话生成 key
    for (var session in _sessions) {
      if (!_tabKeys.containsKey(session.id)) {
        _tabKeys[session.id] = GlobalKey();
      }
    }
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    // 检查 _sessions 是否为空，防止 TabController 在空列表时触发索引错误
    if (_sessions.isEmpty) return;
    if (_tabController.index == _currentIndex) return;

    setState(() {
      _currentIndex = _tabController.index;
    });
    widget.onSessionSwitch?.call(_sessions[_currentIndex]);
  }

  void _removeSession(int index) {
    widget.onRemoveSession?.call(_sessions[index].id);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TDTheme.of(context).whiteColor1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: TDTheme.of(context).grayColor4,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabBar(context),
          const Divider(height: 1),
          Expanded(
            child: _sessions.isEmpty
                ? Center(child: TDText('暂无会话，请点击+添加', style: TextStyle(color: TDTheme.of(context).grayColor5)))
                : IndexedStack(
                    index: _currentIndex,
                    children: _sessions.map((session) {
                      // 使用 GlobalKey 确保状态在移动或重建时保留
                      final key = _tabKeys[session.id]!;
                      if (session.type == TerminalType.ssh) {
                        return SshTerminalView(key: key, session: session);
                      }
                      return VncDesktopView(key: key, session: session);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: TDTheme.of(context).brandNormalColor,
            unselectedLabelColor: TDTheme.of(context).grayColor6,
            tabs: _sessions.map((session) => ContextMenuTrigger(
              onTrigger: (position) {
                _showTabMenu(session, position);
              },
              child: Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(session.name),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _removeSession(_sessions.indexOf(session)),
                      borderRadius: BorderRadius.circular(12),
                      child: const Icon(TDIcons.close, size: 16),
                    )
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
        // 添加按钮
        SizedBox(
          width: 48,
          child: TDButton(
            onTap: widget.onAddSession,
            type: TDButtonType.text, // 正确用法
            icon: TDIcons.add,       // 正确用法
          ),
        )
      ],
    );
  }

  void _showTabMenu(TerminalSession session, Offset position) {
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
          value: 'close',
          child: Row(
            children: [
              Icon(TDIcons.close, size: 16),
              SizedBox(width: 8),
              Text('关闭标签'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'close_others',
          child: Row(
            children: [
              Icon(TDIcons.minus_rectangle, size: 16),
              SizedBox(width: 8),
              Text('关闭其他'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'close') {
        _removeSession(_sessions.indexOf(session));
      } else if (value == 'close_others') {
        // 关闭其他标签逻辑
        // 注意：这需要父组件支持批量删除，目前只支持单个删除
        // 暂时简单实现：遍历删除其他
        for (var s in List.from(_sessions)) {
          if (s.id != session.id) {
            widget.onRemoveSession?.call(s.id);
          }
        }
      }
    });
  }
}

/// 添加会话弹窗
class _AddSessionDialog extends StatelessWidget {
  final Function(TerminalType) onAdd;

  const _AddSessionDialog({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const TDText('添加新连接'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: TDButton(
              text: 'SSH 连接',
              theme: TDButtonTheme.primary,
              onTap: () => onAdd(TerminalType.ssh),
              icon: TDIcons.user,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TDButton(
              text: 'VNC 连接',
              theme: TDButtonTheme.light,
              onTap: () => onAdd(TerminalType.vnc),
              icon: TDIcons.desktop,
            ),
          ),
        ],
      ),
      actions: [
        TDButton(
          text: '取消',
          theme: TDButtonTheme.light,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
