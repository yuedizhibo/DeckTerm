enum DeviceStatusType {
  connecting,
  connected,
  failed,
}

/// 设备信息数据模型
class DeviceInfo {
  /// IP 地址
  final String ip;

  /// 设备名称
  final String name;

  /// CPU 使用率 (0.0 - 1.0)
  final double cpuUsage;

  /// 内存使用率 (0.0 - 1.0)
  final double memoryUsage;

  /// 连接状态
  final DeviceStatusType status;

  DeviceInfo({
    required this.ip,
    this.name = 'Device',
    this.cpuUsage = 0.0,
    this.memoryUsage = 0.0,
    this.status = DeviceStatusType.connecting,
  });

  /// 获取 CPU 使用率百分比字符串
  String get cpuUsagePercent => '${(cpuUsage * 100).toStringAsFixed(1)}%';

  /// 获取内存使用率百分比字符串
  String get memoryUsagePercent => '${(memoryUsage * 100).toStringAsFixed(1)}%';
}
