import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../../../setting/app_theme.dart';
import '../models/device_info.dart';

/// 设备状态显示组件
class DeviceStatus extends StatefulWidget {
  final Map<String, DeviceInfo> devices;

  const DeviceStatus({
    super.key,
    required this.devices,
  });

  @override
  State<DeviceStatus> createState() => _DeviceStatusState();
}

class _DeviceStatusState extends State<DeviceStatus> with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _deviceIps = [];

  @override
  void initState() {
    super.initState();
    _updateTabs();
  }

  @override
  void didUpdateWidget(DeviceStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areDeviceListsEqual(oldWidget.devices.keys, widget.devices.keys)) {
      _updateTabs();
    }
  }

  bool _areDeviceListsEqual(Iterable<String> a, Iterable<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.containsAll(setB) && setB.containsAll(setA);
  }

  void _updateTabs() {
    // 尝试销毁旧的控制器
    try {
      _tabController.dispose();
    } catch (_) {}

    _deviceIps = widget.devices.keys.toList()..sort();
    
    // 如果没有设备，创建一个长度为1的Controller用于显示占位页面
    _tabController = TabController(
      length: _deviceIps.isEmpty ? 1 : _deviceIps.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        border: Border.all(
          color: AppColors.of(context).cardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和 Tab
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.of(context).divider)),
            ),
            child: Row(
              children: [
                TDText(
                  '设备监控',
                  style: TextStyle(
                    fontSize: textScaler.scale(TDTheme.of(context).fontTitleMedium?.size ?? 16),
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).text1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _deviceIps.isEmpty 
                    ? const SizedBox() // 无设备时不显示Tab
                    : TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: TDTheme.of(context).brandNormalColor,
                        unselectedLabelColor: TDTheme.of(context).grayColor6,
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: _deviceIps.map((ip) {
                          final device = widget.devices[ip];
                          return Tab(
                            text: device?.name ?? ip,
                          );
                        }).toList(),
                      ),
                ),
              ],
            ),
          ),
          
          // 内容区域
          Expanded(
            child: _deviceIps.isEmpty
                ? _buildPlaceholderDetail(context, textScaler)
                : TabBarView(
                    controller: _tabController,
                    children: _deviceIps.map((ip) {
                      final deviceInfo = widget.devices[ip]!;
                      return _buildDeviceDetail(context, textScaler, deviceInfo);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderDetail(BuildContext context, TextScaler textScaler) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  TDIcons.cloud,
                  size: textScaler.scale(16),
                  color: TDTheme.of(context).grayColor5,
                ),
                const SizedBox(width: 6),
                TDText(
                  '等待连接...',
                  style: TextStyle(
                    fontSize: textScaler.scale(TDTheme.of(context).fontBodyMedium?.size ?? 14),
                    fontWeight: FontWeight.w500,
                    color: TDTheme.of(context).grayColor6,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TDText(
                    '未连接',
                    style: TextStyle(
                      color: TDTheme.of(context).grayColor6,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressRow(
              context,
              textScaler,
              label: 'CPU',
              usage: 0.0,
              percentText: '0.0%',
              isPlaceholder: true,
            ),
            const SizedBox(height: 16),
            _buildProgressRow(
              context,
              textScaler,
              label: '内存',
              usage: 0.0,
              percentText: '0.0%',
              isPlaceholder: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceDetail(BuildContext context, TextScaler textScaler, DeviceInfo deviceInfo) {
    if (deviceInfo.status == DeviceStatusType.connecting) {
      return const Center(child: TDLoading(size: TDLoadingSize.medium, text: '连接中...'));
    }
    
    if (deviceInfo.status == DeviceStatusType.failed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TDIcons.error_circle, color: TDTheme.of(context).errorNormalColor, size: 32),
            const SizedBox(height: 8),
            TDText('状态查询失败', style: TextStyle(color: TDTheme.of(context).errorNormalColor)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildIpRow(context, textScaler, deviceInfo),
            const SizedBox(height: 16),
            _buildProgressRow(
              context,
              textScaler,
              label: 'CPU',
              usage: deviceInfo.cpuUsage,
              percentText: deviceInfo.cpuUsagePercent,
            ),
            const SizedBox(height: 16),
            _buildProgressRow(
              context,
              textScaler,
              label: '内存',
              usage: deviceInfo.memoryUsage,
              percentText: deviceInfo.memoryUsagePercent,
            ),
          ],
        ),
      ),
    );
  }

  /// IP 地址行
  Widget _buildIpRow(BuildContext context, TextScaler textScaler, DeviceInfo deviceInfo) {
    return Row(
      children: [
        Icon(
          TDIcons.cloud,
          size: textScaler.scale(16),
          color: TDTheme.of(context).brandNormalColor,
        ),
        const SizedBox(width: 6),
        TDText(
          'IP: ${deviceInfo.ip}',
          style: TextStyle(
            fontSize: textScaler.scale(TDTheme.of(context).fontBodyMedium?.size ?? 14),
            fontWeight: FontWeight.w500,
            color: AppColors.of(context).text1,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: TDTheme.of(context).successNormalColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TDText(
            '运行中',
            style: TextStyle(
              color: TDTheme.of(context).successNormalColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// 进度条行
  Widget _buildProgressRow(
    BuildContext context,
    TextScaler textScaler, {
    required String label,
    required double usage,
    required String percentText,
    bool isPlaceholder = false,
  }) {
    final baseFontSize = TDTheme.of(context).fontBodySmall?.size ?? 12;
    final color = isPlaceholder
        ? AppColors.of(context).divider
        : _getProgressColor(context, usage);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TDText(
              label,
              style: TextStyle(
                fontSize: textScaler.scale(baseFontSize),
                fontWeight: FontWeight.normal,
                color: isPlaceholder ? TDTheme.of(context).grayColor6 : AppColors.of(context).text1,
              ),
            ),
            TDText(
              percentText,
              style: TextStyle(
                fontSize: textScaler.scale(baseFontSize),
                fontWeight: FontWeight.w900,
              ).copyWith(
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TDProgress(
          type: TDProgressType.linear,
          value: usage.clamp(0.0, 1.0),
          strokeWidth: textScaler.scale(20), // 加粗进度条，从 12 改为 20
          color: color,
          backgroundColor: AppColors.of(context).divider,
        ),
      ],
    );
  }

  Color _getProgressColor(BuildContext context, double usage) {
    if (usage < 0.5) {
      return TDTheme.of(context).successNormalColor;
    } else if (usage < 0.75) {
      return TDTheme.of(context).warningNormalColor;
    } else {
      return TDTheme.of(context).errorNormalColor;
    }
  }
}
