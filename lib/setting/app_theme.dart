import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════
//  AppColors — 统一色彩语义 Token，通过 ThemeExtension 注入
// ═══════════════════════════════════════════════════════════════════

class AppColors extends ThemeExtension<AppColors> {
  /// 最底层背景
  final Color scaffold;
  /// 标题栏背景
  final Color titleBar;
  /// 次级容器表面（文件树、设备监控等）
  final Color surface;
  /// 浮动面板背景（带透明度）
  final Color panelBg;
  /// 弹出菜单背景
  final Color menuBg;
  /// 卡片 / 行容器背景
  final Color cardBg;
  /// 卡片边框
  final Color cardBorder;
  /// 分割线
  final Color divider;
  /// 悬停态背景
  final Color hoverBg;
  /// 主强调色
  final Color accent;
  /// 次强调色（Logo 渐变终点等）
  final Color accentSecondary;
  /// 强调色低透明度背景
  final Color accentDimBg;
  /// 一级文字
  final Color text1;
  /// 二级文字
  final Color text2;
  /// 三级文字（占位、提示）
  final Color text3;
  /// 图标默认色
  final Color iconDefault;
  /// 关闭按钮 hover 色
  final Color closeHover;
  /// 成功色
  final Color success;
  /// 错误色
  final Color error;
  /// 错误色（角标）
  final Color badge;

  const AppColors({
    required this.scaffold,
    required this.titleBar,
    required this.surface,
    required this.panelBg,
    required this.menuBg,
    required this.cardBg,
    required this.cardBorder,
    required this.divider,
    required this.hoverBg,
    required this.accent,
    required this.accentSecondary,
    required this.accentDimBg,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.iconDefault,
    required this.closeHover,
    required this.success,
    required this.error,
    required this.badge,
  });

  /// 快捷获取
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  // ── 深色 ──
  static const dark = AppColors(
    scaffold:        Color(0xFF0F1419),
    titleBar:        Color(0xFF131820),
    surface:         Color(0xFF151B24),
    panelBg:         Color(0xEB1A1F2E), // 0.92 opacity
    menuBg:          Color(0xFF1E2530),
    cardBg:          Color(0x08FFFFFF), // white 3%
    cardBorder:      Color(0x0DFFFFFF), // white 5%
    divider:         Color(0x0FFFFFFF), // white 6%
    hoverBg:         Color(0x0FFFFFFF), // white 6%
    accent:          Color(0xFF3B82F6),
    accentSecondary: Color(0xFF8B5CF6),
    accentDimBg:     Color(0x1A3B82F6), // accent 10%
    text1:           Color(0xB3FFFFFF), // white 70%
    text2:           Color(0x8AFFFFFF), // white 54%
    text3:           Color(0x4DFFFFFF), // white 30%
    iconDefault:     Color(0x4DFFFFFF), // white 30%
    closeHover:      Color(0xFFE81123),
    success:         Color(0xFF10B981),
    error:           Color(0xFFEF4444),
    badge:           Color(0xFFEF4444),
  );

  // ── 浅色 ──
  static const light = AppColors(
    scaffold:        Color(0xFFF2F4F7),
    titleBar:        Color(0xFFFFFFFF),
    surface:         Color(0xFFFFFFFF),
    panelBg:         Color(0xF0F6F7F9), // 94% opacity
    menuBg:          Color(0xFFFFFFFF),
    cardBg:          Color(0x08000000), // black 3%
    cardBorder:      Color(0x0F000000), // black 6%
    divider:         Color(0x0F000000), // black 6%
    hoverBg:         Color(0x0A000000), // black 4%
    accent:          Color(0xFF3B82F6),
    accentSecondary: Color(0xFF8B5CF6),
    accentDimBg:     Color(0x143B82F6), // accent 8%
    text1:           Color(0xFF1A1A2E),
    text2:           Color(0xFF5A5A72),
    text3:           Color(0xFF9A9AB0),
    iconDefault:     Color(0xFF9A9AB0),
    closeHover:      Color(0xFFE81123),
    success:         Color(0xFF10B981),
    error:           Color(0xFFEF4444),
    badge:           Color(0xFFEF4444),
  );

  @override
  AppColors copyWith({Color? scaffold, Color? accent}) => AppColors(
    scaffold: scaffold ?? this.scaffold,
    titleBar: titleBar, surface: surface, panelBg: panelBg, menuBg: menuBg,
    cardBg: cardBg, cardBorder: cardBorder, divider: divider, hoverBg: hoverBg,
    accent: accent ?? this.accent, accentSecondary: accentSecondary,
    accentDimBg: accentDimBg, text1: text1, text2: text2, text3: text3,
    iconDefault: iconDefault, closeHover: closeHover, success: success,
    error: error, badge: badge,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      scaffold:        Color.lerp(scaffold, other.scaffold, t)!,
      titleBar:        Color.lerp(titleBar, other.titleBar, t)!,
      surface:         Color.lerp(surface, other.surface, t)!,
      panelBg:         Color.lerp(panelBg, other.panelBg, t)!,
      menuBg:          Color.lerp(menuBg, other.menuBg, t)!,
      cardBg:          Color.lerp(cardBg, other.cardBg, t)!,
      cardBorder:      Color.lerp(cardBorder, other.cardBorder, t)!,
      divider:         Color.lerp(divider, other.divider, t)!,
      hoverBg:         Color.lerp(hoverBg, other.hoverBg, t)!,
      accent:          Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      accentDimBg:     Color.lerp(accentDimBg, other.accentDimBg, t)!,
      text1:           Color.lerp(text1, other.text1, t)!,
      text2:           Color.lerp(text2, other.text2, t)!,
      text3:           Color.lerp(text3, other.text3, t)!,
      iconDefault:     Color.lerp(iconDefault, other.iconDefault, t)!,
      closeHover:      Color.lerp(closeHover, other.closeHover, t)!,
      success:         Color.lerp(success, other.success, t)!,
      error:           Color.lerp(error, other.error, t)!,
      badge:           Color.lerp(badge, other.badge, t)!,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ThemeProvider — 全局主题状态，持久化到 SharedPreferences
// ═══════════════════════════════════════════════════════════════════

class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();
  static final ThemeProvider instance = ThemeProvider._();

  bool _isDark = true;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('theme_is_dark') ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark', _isDark);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ThemeData 工厂
// ═══════════════════════════════════════════════════════════════════

ThemeData buildAppTheme(Brightness brightness, List<ThemeExtension> extra) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;

  const fontFamily = 'MiSans';

  return ThemeData(
    brightness: brightness,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: colors.scaffold,
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.cardBorder, width: 1),
      ),
      elevation: 8,
      color: colors.menuBg,
      textStyle: TextStyle(fontSize: 13, color: colors.text1),
    ),
    extensions: [colors, ...extra],
  );
}
