import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

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
import '../../function/monitor/device_monitor.dart';
import '../../function/transfer/transfer_manager.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// 工作流主界面
class WorkflowPage extends StatefulWidget {
  const WorkflowPage({super.key});

  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage> {
  bool _isLocked = false; 
  final DeviceMonitor _monitor = DeviceMonitor();
  Map<String, DeviceInfo> _deviceStatuses = {};
  
  // 布局尺寸状态 (像素值)
  // 如果为 null，将在 ResizableWidget 内部初始化默认值
  double? _horizontalSize;
  double? _leftVerticalSize;
  double? _rightVerticalSize;
  bool _isLayoutLoaded = false;

  final List<TerminalSession> _sessions = [];
  TerminalSession? _currentSession;

  @override
  void initState() {
    super.initState();
    _loadLayoutSettings();
    // 监听设备状态更新
    _monitor.statusStream.listen((statuses) {
      if (mounted) {
        setState(() {
          _deviceStatuses = statuses;
        });
      }
    });
  }

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
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLayoutLoaded) {
      return const Scaffold(body: Center(child: TDLoading(size: TDLoadingSize.medium)));
    }
    
    debugPrint('WorkflowPage build: sessions=${_sessions.length}, current=${_currentSession?.id}');

    return Scaffold(
      appBar: AppBar(
        title: const TDText('DeckTerm'),
        backgroundColor: TDTheme.of(context).brandNormalColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isLocked ? TDIcons.lock_on : TDIcons.lock_off),
            onPressed: () {
              setState(() {
                _isLocked = !_isLocked;
              });
              _saveLayoutSettings();
            },
            tooltip: _isLocked ? '解锁布局' : '锁定布局',
          ),
          // 传输列表按钮：有活跃任务时显示数量角标
          ListenableBuilder(
            listenable: TransferManager(),
            builder: (context, _) {
              final activeCount = TransferManager()
                  .tasks
                  .where((t) =>
                      t.status == TransferStatus.pending ||
                      t.status == TransferStatus.running)
                  .length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(TDIcons.cloud_upload),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const TransferListDialog(),
                      barrierColor: Colors.black54,
                    ),
                    tooltip: '传输列表',
                  ),
                  if (activeCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(TDIcons.link),
            onPressed: () async {
              final result = await showDialog(
                context: context,
                builder: (context) => const ConnectionManagerDialog(),
                barrierColor: Colors.black54,
              );

              if (result != null && result is TerminalSession) {
                _connectSession(result);
              }
            },
            tooltip: '连接管理',
          ),
          IconButton(
            icon: const Icon(TDIcons.setting),
            onPressed: () {},
            tooltip: '设置',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 定义最小宽高，例如 800x600
          const minWidth = 800.0;
          const minHeight = 600.0;
          
          final targetWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
          final targetHeight = constraints.maxHeight < minHeight ? minHeight : constraints.maxHeight;

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const ClampingScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: targetWidth,
                height: targetHeight,
                child: Container(
                  color: TDTheme.of(context).grayColor2,
                  padding: const EdgeInsets.all(12),
                  child: ResizableWidget(
                    isResizable: !_isLocked,
                    direction: Axis.horizontal,
                    initialSize: _horizontalSize,
                    onResizeEnd: (size) {
                      _horizontalSize = size;
                      _saveLayoutSettings();
                    },
                    separatorColor: Colors.transparent, // 设置为透明，使其与背景色一致
                    separatorWidth: 12.0,
                    children: [
                      ResizableWidget(
                        isResizable: !_isLocked,
                        direction: Axis.vertical,
                        initialSize: _leftVerticalSize,
                        onResizeEnd: (size) {
                          _leftVerticalSize = size;
                          _saveLayoutSettings();
                        },
                        separatorColor: Colors.transparent, // 设置为透明
                        separatorWidth: 12.0,
                        children: [
                          DeviceStatus(
                            devices: _deviceStatuses,
                          ),
                          _buildFileTree(),
                        ],
                      ),
                      ResizableWidget(
                        isResizable: !_isLocked,
                        direction: Axis.vertical,
                        initialSize: _rightVerticalSize,
                        onResizeEnd: (size) {
                          _rightVerticalSize = size;
                          _saveLayoutSettings();
                        },
                        separatorColor: Colors.transparent, // 设置为透明
                        separatorWidth: 12.0,
                        children: [
                          TerminalTabs(
                            sessions: _sessions,
                            onAddSession: _addSession,
                            onRemoveSession: _removeSession,
                            onSessionSwitch: _onSessionSwitch,
                          ),
                          RemoteFileManager(
                            key: ValueKey(_currentSession?.id ?? 'none'),
                            session: _currentSession
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _addSession() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const ConnectionManagerDialog(),
      barrierColor: Colors.black54,
    );
    
    if (result != null && result is TerminalSession) {
      _connectSession(result);
    }
  }

  Future<void> _connectSession(TerminalSession session) async {
    debugPrint('_connectSession called with: ${session.name}, id=${session.id}');
    setState(() {
      _sessions.add(session);
      // 如果这是第一个会话，自动设为当前会话
      if (_sessions.length == 1) {
        _currentSession = session;
        debugPrint('_currentSession set to: ${session.name}');
      }
    });

    // 显式调用切换逻辑，确保状态一致
    if (_sessions.length == 1) {
      debugPrint('Triggering _onSessionSwitch for first session');
      _onSessionSwitch(session);
    }

    if (session.type == TerminalType.ssh) {
      // 创建临时 SshManager 来获取 SSHClient，用于监控
      // 注意：实际项目中应该复用 SSH 连接，这里为了演示逻辑简化处理
      // 理想情况下 SshTerminalView 应该把建立好的 client 回传出来
      // 或者我们将 SshManager 的创建提升到这一层
      
      // 暂时方案：我们等待 SshTerminalView 建立连接
      // 在实际生产代码中，应该重构 SshManager 的生命周期管理
    }
  }

  void _removeSession(String sessionId) {
    setState(() {
      _sessions.removeWhere((s) => s.id == sessionId);
      // 如果当前会话被删除，重置或切换
      if (_currentSession?.id == sessionId) {
        if (_sessions.isNotEmpty) {
          _currentSession = _sessions.last;
        } else {
          _currentSession = null;
        }
      }
    });
  }

  Widget _buildFileTree() {
    if (!kIsWeb) {
      if (Platform.isWindows) {
        return const FileTreeWindows();
      } else if (Platform.isAndroid) {
        return const FileTreeAndroid();
      }
    }
    return const _PlaceholderFileTree();
  }

  void _onSessionSwitch(TerminalSession session) {
    debugPrint('切换到会话：${session.name}');
    setState(() {
      _currentSession = session;
    });
  }
}

/// 占位文件树实现（临时）
class _PlaceholderFileTree extends StatelessWidget {
  const _PlaceholderFileTree();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          TDText(
            '文件目录',
            style: TextStyle(fontSize: TDTheme.of(context).fontTitleMedium?.size, height: TDTheme.of(context).fontTitleMedium?.height, fontWeight: TDTheme.of(context).fontTitleMedium?.fontWeight),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    TDIcons.folder,
                    size: 48,
                    color: TDTheme.of(context).grayColor4,
                  ),
                  const SizedBox(height: 12),
                  TDText(
                    '当前平台不支持文件树',
                    style: TextStyle(fontSize: TDTheme.of(context).fontBodyMedium?.size, height: TDTheme.of(context).fontBodyMedium?.height, fontWeight: TDTheme.of(context).fontBodyMedium?.fontWeight).copyWith(
                      color: TDTheme.of(context).grayColor6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
