import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../../../setting/app_theme.dart';
import '../models/terminal_session.dart';
import '../ssh/ssh_terminal_view.dart';
import '../vnc/vnc_desktop_view.dart';
import '../../../ui/common/context_menu_trigger.dart';

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
  bool _isFullscreen = false;
  // 缓存 GlobalKey，确保 Widget 状态在 IndexedStack 重建时保留
  final Map<String, GlobalKey> _tabKeys = {};

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.sessions);
    _updateKeys();
    _tabController = TabController(
      length: _sessions.length,
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
        initialIndex: newIndex,
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
    final currentIds = _sessions.map((s) => s.id).toSet();
    _tabKeys.removeWhere((id, _) => !currentIds.contains(id));
    for (var session in _sessions) {
      if (!_tabKeys.containsKey(session.id)) {
        _tabKeys[session.id] = GlobalKey();
      }
    }
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
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

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 全屏模式下也显示标签栏，但增加退出全屏按钮
          _buildTabBar(context),
          const Divider(height: 1),
          Expanded(
            child: _sessions.isEmpty
                ? Center(child: TDText('暂无会话，请点击+添加', style: TextStyle(color: c.text3)))
                : IndexedStack(
                    index: _currentIndex,
                    children: _sessions.map((session) {
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
    final c = AppColors.of(context);

    return Row(
      children: [
        Expanded(
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: c.accent,
            unselectedLabelColor: c.text3,
            tabs: _sessions.map((session) => ContextMenuTrigger(
              onTrigger: (position) {
                _showTabMenu(session, position);
              },
              child: Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // SSH/VNC 类型图标
                    Icon(
                      session.type == TerminalType.ssh
                          ? Icons.terminal_rounded
                          : Icons.desktop_windows_rounded,
                      size: 14,
                      color: session.type == TerminalType.vnc ? c.accentSecondary : null,
                    ),
                    const SizedBox(width: 6),
                    Text(session.name),
                    // VNC badge
                    if (session.type == TerminalType.vnc) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.accentSecondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'VNC',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c.accentSecondary),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _removeSession(_sessions.indexOf(session)),
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(TDIcons.close, size: 14, color: c.text3),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
        // 全屏按钮
        if (_sessions.isNotEmpty)
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                size: 18,
                color: c.text3,
              ),
              onPressed: _toggleFullscreen,
              tooltip: _isFullscreen ? '退出全屏' : '全屏',
              padding: EdgeInsets.zero,
            ),
          ),
        // 添加按钮
        SizedBox(
          width: 48,
          child: TDButton(
            onTap: widget.onAddSession,
            type: TDButtonType.text,
            icon: TDIcons.add,
          ),
        ),
      ],
    );
  }

  void _showTabMenu(TerminalSession session, Offset position) {
    final c = AppColors.of(context);
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
              Text('关闭标签', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'close_others',
          child: Row(
            children: [
              Icon(TDIcons.minus_rectangle, size: 16),
              SizedBox(width: 8),
              Text('关闭其他', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'fullscreen',
          child: Row(
            children: [
              Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 16),
              const SizedBox(width: 8),
              Text(_isFullscreen ? '退出全屏' : '全屏', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'close') {
        _removeSession(_sessions.indexOf(session));
      } else if (value == 'close_others') {
        for (var s in List.from(_sessions)) {
          if (s.id != session.id) {
            widget.onRemoveSession?.call(s.id);
          }
        }
      } else if (value == 'fullscreen') {
        _toggleFullscreen();
      }
    });
  }
}
