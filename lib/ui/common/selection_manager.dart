import 'package:flutter/material.dart';

/// 文件/目录选择管理器 (ChangeNotifier)
/// 用于管理文件树中的选中状态 (高亮显示)
class SelectionManager extends ChangeNotifier {
  static final SelectionManager _instance = SelectionManager._internal();
  factory SelectionManager() => _instance;
  SelectionManager._internal();

  // 当前选中的路径 (全局唯一)
  String? _selectedPath;
  // 区分选中项的来源 (local/remote)，避免两边同时高亮造成混淆
  // 虽然 UI 上可能允许两边各选一个，但为了简单的“剪切/复制”逻辑，通常一次只操作一个对象
  // 或者我们可以让两边各自维护一个 SelectionManager，或者在这里加个 tag
  String? _sourceTag; 

  String? get selectedPath => _selectedPath;
  String? get sourceTag => _sourceTag;

  bool isSelected(String path, String tag) {
    return _selectedPath == path && _sourceTag == tag;
  }

  void select(String path, String tag) {
    if (_selectedPath == path && _sourceTag == tag) return;
    _selectedPath = path;
    _sourceTag = tag;
    notifyListeners();
  }

  void clear() {
    _selectedPath = null;
    _sourceTag = null;
    notifyListeners();
  }
}
