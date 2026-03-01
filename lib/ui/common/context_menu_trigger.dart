import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 统一的上下文菜单触发器组件
/// 封装了右键点击 (Secondary Tap) 和 长按 (Long Press) 两种触发方式
/// 自动处理不同平台下的位置计算
class ContextMenuTrigger extends StatelessWidget {
  final Widget child;
  final Function(Offset position) onTrigger;

  const ContextMenuTrigger({
    super.key,
    required this.child,
    required this.onTrigger,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
          onTrigger(event.position);
        }
      },
      child: GestureDetector(
        // 处理触摸长按
        onLongPressStart: (details) {
          onTrigger(details.globalPosition);
        },
        // 处理非鼠标设备的 secondary tap（虽然 Listener 已经处理了鼠标右键，但保留这个以兼容触控板等其他输入设备）
        onSecondaryTapUp: (details) {
          if (details.kind != PointerDeviceKind.mouse) {
             onTrigger(details.globalPosition);
          }
        },
        child: child,
      ),
    );
  }
}
