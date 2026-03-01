import 'package:flutter/material.dart';

/// 一个可拖动调整子组件大小的通用组件 (使用绝对尺寸)
class ResizableWidget extends StatefulWidget {
  /// 子组件列表
  final List<Widget> children;
  /// 初始尺寸列表 (如果为 null 或空，则平分)
  /// 对于两个子组件的情况，这里存储的是第一个子组件的像素大小
  final double? initialSize;
  /// 分割线宽度
  final double separatorWidth;
  /// 分割线颜色
  final Color separatorColor;
  /// 布局方向
  final Axis direction;
  /// 是否可调整大小
  final bool isResizable;
  /// 当尺寸变化时的回调 (返回第一个子组件的大小)
  final ValueChanged<double>? onResizeEnd;

  const ResizableWidget({
    super.key,
    required this.children,
    this.initialSize,
    this.separatorWidth = 4.0, // 加宽以便于点击，但视觉上可以透明或与背景同色
    this.separatorColor = Colors.transparent, // 默认透明，实际颜色由容器背景决定
    this.direction = Axis.horizontal,
    this.isResizable = true,
    this.onResizeEnd,
  }) : assert(children.length == 2, 'Currently only supports exactly 2 children');

  @override
  State<ResizableWidget> createState() => _ResizableWidgetState();
}

class _ResizableWidgetState extends State<ResizableWidget> {
  double? _firstChildSize;

  @override
  void initState() {
    super.initState();
    _firstChildSize = widget.initialSize;
  }
  
  @override
  void didUpdateWidget(covariant ResizableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSize != oldWidget.initialSize) {
      _firstChildSize = widget.initialSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = widget.direction == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
        
        // 如果没有初始化尺寸，默认给 40% (符合之前的默认比例)
        // 或者如果 totalSize 还没有准备好
        if (_firstChildSize == null) {
          _firstChildSize = totalSize * 0.4;
        }

        // 确保尺寸在合理范围内
        // 解除最小锁定，只保留一个极小的安全值 (例如 1.0) 防止完全消失导致无法拖回
        final minSize = 1.0;
        final maxSize = totalSize - widget.separatorWidth - 1.0;
        
        // 如果之前保存的尺寸现在超出了当前窗口大小，需要自适应调整
        // 但为了保持“不随窗口拉伸而改变分隔符位置”的特性，我们只在真正溢出时才调整
        // 注意：这里可能存在冲突。如果用户希望“拉大窗口时直接拉开”，意味着右侧/下侧填充
        // 所以左侧/上侧（firstChild）应该保持固定像素值。
        
        // 修正当前尺寸以符合约束
        // 必须确保 minSize <= maxSize，否则说明窗口太小了
        final safeMaxSize = maxSize < minSize ? minSize : maxSize;
        final effectiveSize = _firstChildSize!.clamp(minSize, safeMaxSize);

        List<Widget> children = [];
        
        // 第一个子组件：固定大小
        children.add(SizedBox(
          width: widget.direction == Axis.horizontal ? effectiveSize : double.infinity,
          height: widget.direction == Axis.vertical ? effectiveSize : double.infinity,
          child: widget.children[0],
        ));

        // 分割线
        children.add(_buildSeparator(totalSize));

        // 第二个子组件：占据剩余空间
        children.add(Expanded(
          child: widget.children[1],
        ));

        return Flex(
          direction: widget.direction,
          children: children,
        );
      },
    );
  }

  Widget _buildSeparator(double totalSize) {
    return GestureDetector(
      onPanUpdate: widget.isResizable ? (details) {
        setState(() {
          final delta = widget.direction == Axis.horizontal ? details.delta.dx : details.delta.dy;
          
          final newSize = (_firstChildSize ?? 0) + delta;
          
          // 限制最小/最大尺寸
          // 解除所有限制，允许用户自由调整
          
          final minSize = 1.0;
          final maxSize = totalSize - widget.separatorWidth - 1.0;
          
          final safeMaxSize = maxSize < minSize ? minSize : maxSize;

          if (newSize >= minSize && newSize <= safeMaxSize) {
            _firstChildSize = newSize;
          }
        });
      } : null,
      onPanEnd: (_) {
        if (_firstChildSize != null) {
          widget.onResizeEnd?.call(_firstChildSize!);
        }
      },
      child: MouseRegion(
        cursor: widget.isResizable
            ? (widget.direction == Axis.horizontal
                ? SystemMouseCursors.resizeLeftRight
                : SystemMouseCursors.resizeUpDown)
            : SystemMouseCursors.basic,
        child: Container(
          width: widget.direction == Axis.horizontal ? widget.separatorWidth : double.infinity,
          height: widget.direction == Axis.vertical ? widget.separatorWidth : double.infinity,
          color: widget.separatorColor, // 可以设置为 Colors.transparent，并在下层使用 TDTheme.grayColor3 作为边框
          // 或者如果不希望有明显的分割线，就让它透明，仅作为热区
        ),
      ),
    );
  }
}
