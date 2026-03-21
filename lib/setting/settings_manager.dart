import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局设置管理器（单例，ChangeNotifier）
/// 持久化到 SharedPreferences，UI 通过 ListenableBuilder 监听变化
class SettingsManager extends ChangeNotifier {
  SettingsManager._();
  static final SettingsManager instance = SettingsManager._();

  double _fontSize = 14.0;
  bool _cursorBlink = true;
  int _scrollbackLines = 10000;
  int _keepAliveSeconds = 30;
  bool _autoReconnect = true;

  double get fontSize => _fontSize;
  bool get cursorBlink => _cursorBlink;
  int get scrollbackLines => _scrollbackLines;
  int get keepAliveSeconds => _keepAliveSeconds;
  bool get autoReconnect => _autoReconnect;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('setting_font_size') ?? 14.0;
    _cursorBlink = prefs.getBool('setting_cursor_blink') ?? true;
    _scrollbackLines = prefs.getInt('setting_scrollback_lines') ?? 10000;
    _keepAliveSeconds = prefs.getInt('setting_keep_alive_seconds') ?? 30;
    _autoReconnect = prefs.getBool('setting_auto_reconnect') ?? true;
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    if (_fontSize == v) return;
    _fontSize = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('setting_font_size', v);
  }

  Future<void> setCursorBlink(bool v) async {
    if (_cursorBlink == v) return;
    _cursorBlink = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_cursor_blink', v);
  }

  Future<void> setScrollbackLines(int v) async {
    if (_scrollbackLines == v) return;
    _scrollbackLines = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('setting_scrollback_lines', v);
  }

  Future<void> setKeepAliveSeconds(int v) async {
    if (_keepAliveSeconds == v) return;
    _keepAliveSeconds = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('setting_keep_alive_seconds', v);
  }

  Future<void> setAutoReconnect(bool v) async {
    if (_autoReconnect == v) return;
    _autoReconnect = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_auto_reconnect', v);
  }
}
