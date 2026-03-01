import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import 'ui/main/workflow.dart';

void main() {
  // 禁用 TDesign 的字体强制居中功能，修复 Flutter 3.16+ 下的偏移问题
  kTextForceVerticalCenterEnable = false;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeckTerm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
        // 自定义菜单主题
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // 圆角
            side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1), // 边框
          ),
          elevation: 4, // 阴影
          color: Colors.white, // 背景色
          textStyle: const TextStyle(fontSize: 14, color: Colors.black87),
          // 调整菜单项样式
          // 注意：Flutter 的 PopupMenuItem 本身有一些固定的 padding，可能需要自定义 Widget 来完全控制
        ),
        extensions: [TDThemeData.defaultData()],
      ),
      home: const PermissionCheckWrapper(),
    );
  }
}

/// 权限检查包装器
class PermissionCheckWrapper extends StatefulWidget {
  const PermissionCheckWrapper({super.key});

  @override
  State<PermissionCheckWrapper> createState() => _PermissionCheckWrapperState();
}

class _PermissionCheckWrapperState extends State<PermissionCheckWrapper> {
  bool _hasPermission = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) {
      setState(() {
        _hasPermission = true;
        _isChecking = false;
      });
      return;
    }

    // 检查 Android 存储权限
    // Android 11+ (API 30+) 使用 MANAGE_EXTERNAL_STORAGE
    // Android 10及以下使用 STORAGE
    bool granted = false;
    
    // 简单起见，我们先请求 manageExternalStorage，如果不可用则请求 storage
    // 注意：Manage External Storage 需要在 AndroidManifest.xml 中声明并由用户在系统设置中手动授予
    if (await Permission.manageExternalStorage.status.isGranted) {
      granted = true;
    } else if (await Permission.storage.status.isGranted) {
      granted = true;
    } else {
      // 尝试请求权限
      // 优先请求 Manage External Storage (Android 11+)
      if (await Permission.manageExternalStorage.request().isGranted) {
        granted = true;
      } else if (await Permission.storage.request().isGranted) {
        granted = true;
      }
    }

    if (mounted) {
      setState(() {
        _hasPermission = granted;
        _isChecking = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    // 打开应用设置页面让用户手动授权
    await openAppSettings();
    // 返回后再次检查
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: TDLoading(size: TDLoadingSize.medium, text: '正在检查权限...'),
        ),
      );
    }

    if (_hasPermission) {
      return const WorkflowPage();
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(TDIcons.error_circle, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const TDText(
              '需要存储权限',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: TDText(
                '为了管理本地文件，DeckTerm 需要访问您的设备存储。请授予权限以继续。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            TDButton(
              text: '去授权',
              size: TDButtonSize.large,
              theme: TDButtonTheme.primary,
              onTap: _requestPermission,
            ),
          ],
        ),
      ),
    );
  }
}
