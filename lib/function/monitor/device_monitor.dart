import 'dart:async';
import 'package:dartssh2/dartssh2.dart';

import '../../ui/main/models/device_info.dart';
import '../../ui/main/models/terminal_session.dart';

class DeviceMonitor {
  static final DeviceMonitor _instance = DeviceMonitor._internal();
  factory DeviceMonitor() => _instance;
  DeviceMonitor._internal();

  // Polling key: Host IP
  final Map<String, Timer> _pollingTimers = {};
  final Map<String, SSHClient> _pollingClients = {};

  // 防止对同一个 host 重复发起连接（重连期间不再触发新的重连）
  final Set<String> _reconnecting = {};
  // 防止对同一个 host 重复调度单次重试 poll（避免失败雪崩）
  final Set<String> _retryingPoll = {};
  
  // Status storage: Host IP -> DeviceInfo
  final Map<String, DeviceInfo> _deviceStatuses = {};
  
  // Reference counting: Host IP -> Set<Session ID>
  // Tracks active UI sessions to know when to start/stop monitoring
  final Map<String, Set<String>> _sessionRefs = {};
  
  // Store session configs to recreate connections if needed
  final Map<String, TerminalSession> _hostConfigs = {};
  
  final _statusController = StreamController<Map<String, DeviceInfo>>.broadcast();
  Stream<Map<String, DeviceInfo>> get statusStream => _statusController.stream;

  /// Registers a device for monitoring.
  /// 
  /// [session] is used to get connection details (host, port, auth).
  /// [client] is ignored in this new implementation as Monitor manages its own connection.
  void addDevice(TerminalSession session, {SSHClient? client}) {
    final host = session.host;
    final sessionId = session.id;

    // Add session reference
    if (!_sessionRefs.containsKey(host)) {
      _sessionRefs[host] = {};
    }
    
    // 如果该 session 已经存在引用中，则不需要重复添加
    // 也不需要重新触发 _startIndependentMonitoring
    // 只有当这是该 host 的第一个 session 引用时，才启动监控
    
    bool isNewHost = _sessionRefs[host]!.isEmpty;
    _sessionRefs[host]!.add(sessionId);
    
    // Store config for independent connection
    _hostConfigs[host] = session;

    // Only start polling if not already polling for this host
    if (isNewHost && !_pollingTimers.containsKey(host)) {
      _deviceStatuses[host] = DeviceInfo(
        ip: host,
        name: session.name, // Use first session's name as device name
        status: DeviceStatusType.connecting,
      );
      _notify();

      // Initiate independent connection and polling
      _startIndependentMonitoring(host, session);
    }
  }

  void removeDevice(String sessionId) {
    // Find which host this session belongs to
    String? targetHost;
    for (var entry in _sessionRefs.entries) {
      if (entry.value.contains(sessionId)) {
        targetHost = entry.key;
        break;
      }
    }

    if (targetHost != null) {
      _sessionRefs[targetHost]!.remove(sessionId);
      
      // If no more sessions refer to this host, stop polling and close connection
      if (_sessionRefs[targetHost]!.isEmpty) {
        _sessionRefs.remove(targetHost);
        _hostConfigs.remove(targetHost);
        _stopPolling(targetHost);
      }
    }
  }

  Future<void> _startIndependentMonitoring(String host, TerminalSession session) async {
    // 防止对同一 host 并发触发多次连接
    if (_reconnecting.contains(host)) return;
    _reconnecting.add(host);

    try {
      final socket = await SSHSocket.connect(
        session.host,
        session.port,
        timeout: const Duration(seconds: 10),
      );

      final client = SSHClient(
        socket,
        username: session.username ?? 'root',
        onPasswordRequest: () => session.password,
      );

      await client.authenticated;
      _pollingClients[host] = client;
      _reconnecting.remove(host);

      // Start polling loop
      _pollingTimers[host] = Timer.periodic(const Duration(seconds: 5), (_) => _pollDevice(host));

      // Immediate first poll
      _pollDevice(host);

    } catch (e) {
      _reconnecting.remove(host);
      _updateStatus(host, DeviceStatusType.failed);
      // 连接失败：1 秒后自动重连
      _scheduleReconnect(host);
    }
  }

  /// 1 秒后重新发起连接。
  /// 仅在 host 仍被引用、且当前没有连接进行中时执行。
  void _scheduleReconnect(String host) {
    if (!_sessionRefs.containsKey(host)) return;  // host 已被移除，不再重连
    if (_reconnecting.contains(host)) return;      // 已有重连在进行中

    Future.delayed(const Duration(seconds: 1), () {
      // 延迟结束后再次检查：session 可能已被关闭，或重连已由其他路径发起
      if (!_sessionRefs.containsKey(host)) return;
      if (_reconnecting.contains(host)) return;
      if (_pollingTimers.containsKey(host)) return; // 已恢复轮询，无需重连

      final config = _hostConfigs[host];
      if (config != null) _startIndependentMonitoring(host, config);
    });
  }

  void _stopPolling(String host) {
    _pollingTimers[host]?.cancel();
    _pollingTimers.remove(host);

    _pollingClients[host]?.close();
    _pollingClients.remove(host);

    // 清理重试状态：延迟回调执行前会检查 _sessionRefs，host 已移除所以不会有副作用
    _reconnecting.remove(host);
    _retryingPoll.remove(host);

    _deviceStatuses.remove(host);
    _notify();
  }

  Future<void> _pollDevice(String host) async {
    final client = _pollingClients[host];

    // 连接已断开：停止轮询，触发重连
    if (client == null || client.isClosed) {
      _updateStatus(host, DeviceStatusType.failed);
      _pollingTimers[host]?.cancel();
      _pollingTimers.remove(host);
      _pollingClients.remove(host);
      _scheduleReconnect(host);
      return;
    }

    try {
      final cpuResult = await client.run("grep 'cpu ' /proc/stat | awk '{usage=(\$2+\$4)*100/(\$2+\$4+\$5)} END {print usage}'");
      final cpuUsage = double.tryParse(String.fromCharCodes(cpuResult).trim()) ?? 0.0;

      final memResult = await client.run("free | grep Mem | awk '{print \$3/\$2 * 100.0}'");
      final memUsage = double.tryParse(String.fromCharCodes(memResult).trim()) ?? 0.0;

      _deviceStatuses[host] = DeviceInfo(
        ip: host,
        name: _deviceStatuses[host]?.name ?? 'Device',
        cpuUsage: cpuUsage / 100.0,
        memoryUsage: memUsage / 100.0,
        status: DeviceStatusType.connected,
      );
      _notify();
    } catch (e) {
      _updateStatus(host, DeviceStatusType.failed);

      // 命令执行失败：1 秒后重试本次查询。
      // 用 _retryingPoll 防止在 5s 轮询窗口内重复积累重试。
      if (!_retryingPoll.contains(host)) {
        _retryingPoll.add(host);
        Future.delayed(const Duration(seconds: 1), () {
          _retryingPoll.remove(host);
          if (_sessionRefs.containsKey(host)) _pollDevice(host);
        });
      }
    }
  }

  void _updateStatus(String host, DeviceStatusType status) {
    if (_deviceStatuses.containsKey(host)) {
      final current = _deviceStatuses[host]!;
      _deviceStatuses[host] = DeviceInfo(
        ip: host,
        name: current.name,
        cpuUsage: 0,
        memoryUsage: 0,
        status: status,
      );
      _notify();
    }
  }

  void _notify() {
    _statusController.add(Map.from(_deviceStatuses));
  }

  void dispose() {
    for (var timer in _pollingTimers.values) {
      timer.cancel();
    }
    for (var client in _pollingClients.values) {
      client.close();
    }
    _pollingTimers.clear();
    _pollingClients.clear();
    _sessionRefs.clear();
    _hostConfigs.clear();
    _statusController.close();
  }
}
