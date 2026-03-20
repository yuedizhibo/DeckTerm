import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'setting/app_theme.dart';
import 'ui/main/workflow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 禁用 TDesign 的字体强制居中功能，修复 Flutter 3.16+ 下的偏移问题
  kTextForceVerticalCenterEnable = false;

  // 加载持久化主题偏好
  await ThemeProvider.instance.load();

  // Windows 自定义标题栏初始化
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'DeckTerm',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tdExtra = [TDThemeData.defaultData()];

    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, _) {
        final provider = ThemeProvider.instance;
        return MaterialApp(
          title: 'DeckTerm',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light, tdExtra),
          darkTheme: buildAppTheme(Brightness.dark, tdExtra),
          themeMode: provider.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 320),
          themeAnimationCurve: Curves.easeInOut,
          home: const PermissionCheckWrapper(),
        );
      },
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

    bool granted = false;
    if (await Permission.manageExternalStorage.status.isGranted) {
      granted = true;
    } else if (await Permission.storage.status.isGranted) {
      granted = true;
    } else {
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
    await openAppSettings();
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_isChecking) {
      return Scaffold(
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
            Icon(TDIcons.error_circle, size: 64, color: c.error),
            const SizedBox(height: 16),
            Text('需要存储权限', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.text1)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '为了管理本地文件，DeckTerm 需要访问您的设备存储。请授予权限以继续。',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text3),
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
