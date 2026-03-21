import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../android/file_tree_android.dart';
import '../windows/file_tree_windows.dart';
import 'models/device_info.dart';
import 'models/terminal_session.dart';
import 'widgets/device_status.dart';
import 'widgets/remote_file_manager.dart';
import 'widgets/resizable_widget.dart';
import 'widgets/terminal_tabs.dart';
import '../connect/connection_manager_dialog.dart';
import '../common/transfer_list_dialog.dart';
import '../common/settings_panel.dart';
import '../common/floating_panel.dart';
import '../../function/monitor/device_monitor.dart';
import '../../function/transfer/transfer_manager.dart';
import '../../setting/app_theme.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// 工作流主界面
class WorkflowPage extends StatefulWidget {
  const WorkflowPage({super.key});

  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage> with WindowListener {
  bool _isLocked = false;
  final DeviceMonitor _monitor = DeviceMonitor();
  Map<String, DeviceInfo> _deviceStatuses = {};

  double? _horizontalSize;
  double? _leftVerticalSize;
  double? _rightVerticalSize;
  bool _isLayoutLoaded = false;

  final List<TerminalSession> _sessions = [];
  TerminalSession? _currentSession;

  // ── 浮动面板 ────────────────────────────────────────────────────
  final Set<String> _openPanels = {};
  final Set<String> _closingPanels = {}; // 正在播放关闭动画的面板
  final List<String> _panelOrder = []; // z 序
  // 各按钮的 GlobalKey，用于计算动画起点
  final _keyConnection = GlobalKey();
  final _keyTransfer = GlobalKey();
  final _keySettings = GlobalKey();

  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _loadLayoutSettings();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      _checkMaximized();
    }
    _monitor.statusStream.listen((statuses) {
      if (mounted) setState(() => _deviceStatuses = statuses);
    });
  }

  Future<void> _checkMaximized() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Future<void> _loadLayoutSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _horizontalSize = prefs.getDouble('layout_horizontal_size');
      _leftVerticalSize = prefs.getDouble('layout_left_vertical_size');
      _rightVerticalSize = prefs.getDouble('layout_right_vertical_size');
      _isLocked = prefs.getBool('layout_locked') ?? false;
      _isLayoutLoaded = true;
    });
  }

  Future<void> _saveLayoutSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (_horizontalSize != null) await prefs.setDouble('layout_horizontal_size', _horizontalSize!);
    if (_leftVerticalSize != null) await prefs.setDouble('layout_left_vertical_size', _leftVerticalSize!);
    if (_rightVerticalSize != null) await prefs.setDouble('layout_right_vertical_size', _rightVerticalSize!);
    await prefs.setBool('layout_locked', _isLocked);
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    _monitor.dispose();
    super.dispose();
  }

  // ── 面板操作 ────────────────────────────────────────────────────

  /// 获取按钮在 _stackKey 坐标系中的 Rect，供动画起点使用。
  /// 按钮在标题栏（Column 第一个子组件），Stack 是 Column 第二个子组件，
  /// 两者不是祖先-后代关系，所以必须各自转全局坐标再相减。
  Rect? _btnRect(GlobalKey key) {
    final ro = key.currentContext?.findRenderObject() as RenderBox?;
    final stackRo = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (ro == null || stackRo == null) return null;
    final btnGlobal = ro.localToGlobal(Offset.zero);
    final stackGlobal = stackRo.localToGlobal(Offset.zero);
    final pos = btnGlobal - stackGlobal;
    return pos & ro.size;
  }

  final _stackKey = GlobalKey();

  void _togglePanel(String id, GlobalKey btnKey) {
    if (Platform.isAndroid) {
      _openAndroidPanel(id);
      return;
    }
    setState(() {
      if (_openPanels.contains(id)) {
        if (_closingPanels.contains(id)) return; // 已在关闭中
        _closingPanels.add(id); // 触发关闭动画，不立即移除
      } else {
        _closingPanels.remove(id);
        _openPanels.add(id);
        _panelOrder.remove(id);
        _panelOrder.add(id);
      }
    });
  }

  /// 关闭动画播放完毕后的回调，真正从树中移除面板
  void _onPanelClosed(String id) {
    setState(() {
      _openPanels.remove(id);
      _panelOrder.remove(id);
      _closingPanels.remove(id);
    });
  }

  void _bringToFront(String id) {
    setState(() {
      _panelOrder.remove(id);
      _panelOrder.add(id);
    });
  }

  /// Android 用模态 Dialog 打开面板
  void _openAndroidPanel(String id) {
    final Widget content;
    final String title;
    double w = 560, h = 640;
    switch (id) {
      case 'connection':
        title = '连接管理';
        w = 540; h = 520;
        content = ConnectionManagerPanel(onConnect: (s) {
          Navigator.of(context).pop();
          _connectSession(s);
        });
      case 'transfer':
        title = '传输列表';
        w = 500; h = 440;
        content = const TransferListPanel();
      case 'settings':
        title = '设置';
        w = 480; h = 520;
        content = const SettingsPanel();
      default:
        return;
    }
    showPanelDialog(context: context, title: title, child: content, width: w, height: h);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (!_isLayoutLoaded) {
      return Scaffold(
        backgroundColor: c.scaffold,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
      );
    }

    // Android 需要 SafeArea 避免状态栏遮挡标题栏
    Widget body = Column(
      children: [
        _buildTitleBar(context),
        Expanded(
          // LayoutBuilder 获取 Stack 的可用尺寸，传给 FloatingPanel
          // 避免 FloatingPanel 内部使用 LayoutBuilder 导致 Positioned 失效
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                key: _stackKey,
                children: [
                  _buildMainContent(context),
                  ..._buildFloatingPanels(stackSize),
                ],
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Platform.isAndroid
          ? SafeArea(child: body)
          : body,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  标题栏 — 整个区域可拖拽（DragToMoveArea 零延迟）
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTitleBar(BuildContext context) {
    final c = AppColors.of(context);

    // Logo 区域
    Widget logo = Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [c.accent, c.accentSecondary],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Icon(Icons.terminal_rounded, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text('DeckTerm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text2, letterSpacing: 0.5)),
        ],
      ),
    );

    // 左侧区域：Logo + 空白填充（仅此区域可拖拽 / 双击最大化）
    Widget dragZone = Expanded(child: SizedBox.expand(child: Align(alignment: Alignment.centerLeft, child: logo)));
    if (Platform.isWindows) {
      dragZone = Expanded(child: DragToMoveArea(child: SizedBox.expand(child: Align(alignment: Alignment.centerLeft, child: logo))));
    }

    return Container(
      height: 44,
      color: c.titleBar,
      child: Stack(
        children: [
          Positioned(left: 0, right: 0, bottom: 0,
            child: Container(height: 1, color: c.divider),
          ),
          Row(
            children: [
              dragZone,
              _buildToolbar(context),
              const SizedBox(width: 8),
              Container(width: 1, height: 18, color: c.divider),
              if (Platform.isWindows) ...[
                _WindowControlBtn(icon: Icons.remove_rounded, tooltip: '最小化', onTap: () => windowManager.minimize()),
                _WindowControlBtn(
                  icon: _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                  iconSize: _isMaximized ? 13 : 15,
                  tooltip: _isMaximized ? '还原' : '最大化',
                  onTap: () async {
                    if (await windowManager.isMaximized()) { windowManager.unmaximize(); } else { windowManager.maximize(); }
                  },
                ),
                _WindowControlBtn(icon: Icons.close_rounded, tooltip: '关闭', isClose: true, onTap: () => windowManager.close()),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolbarBtn(
          icon: _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          tooltip: _isLocked ? '解锁布局' : '锁定布局',
          isActive: _isLocked,
          onTap: () { setState(() => _isLocked = !_isLocked); _saveLayoutSettings(); },
        ),
        const SizedBox(width: 2),
        _ToolbarBtn(
          key: _keyTransfer,
          icon: Icons.swap_vert_rounded,
          tooltip: '传输列表',
          isActive: _openPanels.contains('transfer') && !_closingPanels.contains('transfer'),
          onTap: () => _togglePanel('transfer', _keyTransfer),
          badge: _buildTransferBadge(),
        ),
        const SizedBox(width: 2),
        _ToolbarBtn(
          key: _keyConnection,
          icon: Icons.dns_outlined,
          tooltip: '连接管理',
          isActive: _openPanels.contains('connection') && !_closingPanels.contains('connection'),
          onTap: () => _togglePanel('connection', _keyConnection),
        ),
        const SizedBox(width: 2),
        _ToolbarBtn(
          key: _keySettings,
          icon: Icons.settings_outlined,
          tooltip: '设置',
          isActive: _openPanels.contains('settings') && !_closingPanels.contains('settings'),
          onTap: () => _togglePanel('settings', _keySettings),
        ),
      ],
    );
  }

  Widget? _buildTransferBadge() {
    return ListenableBuilder(
      listenable: TransferManager(),
      builder: (context, _) {
        final n = TransferManager().tasks.where((t) => t.status == TransferStatus.pending || t.status == TransferStatus.running).length;
        if (n == 0) return const SizedBox.shrink();
        return Positioned(
          right: 4, top: 4,
          child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: AppColors.of(context).badge, borderRadius: BorderRadius.circular(7)),
            child: Center(child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  浮动面板
  // ═══════════════════════════════════════════════════════════════════

  List<Widget> _buildFloatingPanels(Size stackSize) {
    final defs = <String, _PanelDef>{
      'connection': _PanelDef('连接管理', 540, 520, _keyConnection,
        ConnectionManagerPanel(onConnect: (s) {
          _connectSession(s);
          // 连接后关闭面板：直接触发关闭动画
          if (_openPanels.contains('connection') && !_closingPanels.contains('connection')) {
            setState(() => _closingPanels.add('connection'));
          }
        })),
      'transfer': _PanelDef('传输列表', 500, 440, _keyTransfer,
        const TransferListPanel()),
      'settings': _PanelDef('设置', 480, 520, _keySettings,
        const SettingsPanel()),
    };

    final entries = <MapEntry<String, Widget>>[];
    for (final id in _openPanels) {
      final d = defs[id];
      if (d == null) continue;
      entries.add(MapEntry(id, FloatingPanel(
        key: ValueKey('panel_$id'),
        title: d.title,
        width: d.width,
        height: d.height,
        availableSize: stackSize,
        originRect: _btnRect(d.btnKey),
        isClosing: _closingPanels.contains(id),
        onClose: () => _onPanelClosed(id),
        onTap: () => _bringToFront(id),
        child: d.child,
      )));
    }
    // 按 z 序排列
    entries.sort((a, b) => _panelOrder.indexOf(a.key).compareTo(_panelOrder.indexOf(b.key)));
    return entries.map((e) => e.value).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  主内容
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMainContent(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const minW = 800.0, minH = 500.0;
      final w = constraints.maxWidth < minW ? minW : constraints.maxWidth;
      final h = constraints.maxHeight < minH ? minH : constraints.maxHeight;

      return SingleChildScrollView(
        scrollDirection: Axis.vertical, physics: const ClampingScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(),
          child: SizedBox(width: w, height: h, child: Container(
            color: AppColors.of(context).scaffold,
            padding: const EdgeInsets.all(8),
            child: ResizableWidget(
              isResizable: !_isLocked, direction: Axis.horizontal,
              initialSize: _horizontalSize,
              onResizeEnd: (s) { _horizontalSize = s; _saveLayoutSettings(); },
              separatorColor: Colors.transparent, separatorWidth: 6.0,
              children: [
                ResizableWidget(
                  isResizable: !_isLocked, direction: Axis.vertical,
                  initialSize: _leftVerticalSize,
                  onResizeEnd: (s) { _leftVerticalSize = s; _saveLayoutSettings(); },
                  separatorColor: Colors.transparent, separatorWidth: 6.0,
                  children: [
                    DeviceStatus(devices: _deviceStatuses),
                    _buildFileTree(),
                  ],
                ),
                ResizableWidget(
                  isResizable: !_isLocked, direction: Axis.vertical,
                  initialSize: _rightVerticalSize,
                  onResizeEnd: (s) { _rightVerticalSize = s; _saveLayoutSettings(); },
                  separatorColor: Colors.transparent, separatorWidth: 6.0,
                  children: [
                    TerminalTabs(
                      sessions: _sessions,
                      onAddSession: _addSession,
                      onRemoveSession: _removeSession,
                      onSessionSwitch: _onSessionSwitch,
                    ),
                    RemoteFileManager(
                      key: ValueKey(_currentSession?.id ?? 'none'),
                      session: _currentSession,
                    ),
                  ],
                ),
              ],
            ),
          )),
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  会话管理
  // ═══════════════════════════════════════════════════════════════════

  void _addSession() {
    if (Platform.isAndroid) {
      _openAndroidPanel('connection');
      return;
    }
    if (!_openPanels.contains('connection')) {
      _togglePanel('connection', _keyConnection);
    } else {
      _bringToFront('connection');
    }
  }

  Future<void> _connectSession(TerminalSession session) async {
    setState(() {
      _sessions.add(session);
      if (_sessions.length == 1) _currentSession = session;
    });
    if (_sessions.length == 1) _onSessionSwitch(session);
  }

  void _removeSession(String sessionId) {
    setState(() {
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_currentSession?.id == sessionId) {
        _currentSession = _sessions.isNotEmpty ? _sessions.last : null;
      }
    });
  }

  Widget _buildFileTree() {
    if (!kIsWeb) {
      if (Platform.isWindows) return const FileTreeWindows();
      if (Platform.isAndroid) return const FileTreeAndroid();
    }
    return const _PlaceholderFileTree();
  }

  void _onSessionSwitch(TerminalSession session) => setState(() => _currentSession = session);
}

// ═══════════════════════════════════════════════════════════════════
//  内部数据类
// ═══════════════════════════════════════════════════════════════════

class _PanelDef {
  final String title;
  final double width, height;
  final GlobalKey btnKey;
  final Widget child;
  const _PanelDef(this.title, this.width, this.height, this.btnKey, this.child);
}

// ═══════════════════════════════════════════════════════════════════
//  工具栏按钮
// ═══════════════════════════════════════════════════════════════════

class _ToolbarBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;
  final Widget? badge;

  const _ToolbarBtn({super.key, required this.icon, required this.tooltip, required this.onTap, this.isActive = false, this.badge});

  @override
  State<_ToolbarBtn> createState() => _ToolbarBtnState();
}

class _ToolbarBtnState extends State<_ToolbarBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip, waitDuration: const Duration(milliseconds: 500),
        child: Listener(
          onPointerDown: (_) => widget.onTap(),
          child: Stack(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 34, height: 30,
              decoration: BoxDecoration(
                color: widget.isActive
                    ? c.accentDimBg
                    : (_hovered ? c.hoverBg : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(widget.icon, size: 16,
                color: widget.isActive ? c.accent : (_hovered ? c.text2 : c.iconDefault)),
            ),
            if (widget.badge != null) widget.badge!,
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  窗口控制按钮
// ═══════════════════════════════════════════════════════════════════

class _WindowControlBtn extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowControlBtn({required this.icon, this.iconSize = 15, required this.tooltip, required this.onTap, this.isClose = false});

  @override
  State<_WindowControlBtn> createState() => _WindowControlBtnState();
}

class _WindowControlBtnState extends State<_WindowControlBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip, waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 46, height: 44,
            color: _hovered ? (widget.isClose ? c.closeHover : c.hoverBg) : Colors.transparent,
            child: Icon(widget.icon, size: widget.iconSize,
              color: _hovered ? (widget.isClose ? Colors.white : c.text1) : c.iconDefault),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  占位文件树
// ═══════════════════════════════════════════════════════════════════

class _PlaceholderFileTree extends StatelessWidget {
  const _PlaceholderFileTree();
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件目录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text2)),
          const SizedBox(height: 8),
          Expanded(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_outlined, size: 40, color: c.divider),
              const SizedBox(height: 12),
              Text('当前平台不支持文件树', style: TextStyle(color: c.text3, fontSize: 13)),
            ],
          ))),
        ],
      ),
    );
  }
}
