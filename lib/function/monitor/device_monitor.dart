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
      
      // Start polling loop
      _pollingTimers[host] = Timer.periodic(const Duration(seconds: 5), (_) => _pollDevice(host));
      
      // Immediate first poll
      _pollDevice(host);
      
    } catch (e) {
      _updateStatus(host, DeviceStatusType.failed);
      // Retry logic could be added here if needed
    }
  }

  void _stopPolling(String host) {
    _pollingTimers[host]?.cancel();
    _pollingTimers.remove(host);
    
    _pollingClients[host]?.close();
    _pollingClients.remove(host);
    
    _deviceStatuses.remove(host);
    _notify();
  }

  Future<void> _pollDevice(String host) async {
    final client = _pollingClients[host];
    if (client == null || client.isClosed) {
      _updateStatus(host, DeviceStatusType.failed);
      // Attempt reconnection if needed? For now, just mark failed.
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
