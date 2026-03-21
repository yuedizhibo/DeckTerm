import 'dart:ui';
import 'package:flutter/material.dart';
import '../../setting/app_theme.dart';

/// 通用可拖拽毛玻璃浮动面板
///
/// 支持：
/// - 从按钮位置飞出到屏幕中央的动画（originRect → 居中）
/// - 关闭时反向动画缩回按钮位置
/// - 拖拽移动
/// - 半透明毛玻璃效果
/// - 必须作为 Stack 的子组件使用（build 返回 Positioned）
///
/// 关闭流程：
/// 1. 面板关闭按钮 或 外部设置 isClosing=true
/// 2. 动画反向播放（当前位置 → 按钮位置，缩放 1.0→0.15，淡出）
/// 3. 动画结束后调用 onClose，由父级从树中移除
class FloatingPanel extends StatefulWidget {
  final String title;
  final Widget child;
  final double width;
  final double height;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  /// 父 Stack 的可用尺寸，用于计算居中位置和边界限制。
  final Size availableSize;

  /// 动画起点/终点：按钮在 Stack 内的矩形位置。
  /// 打开时从此处飞出，关闭时缩回此处。
  final Rect? originRect;

  /// 外部关闭触发：设为 true 后播放关闭动画，结束后调用 onClose。
  final bool isClosing;

  const FloatingPanel({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    required this.availableSize,
    this.width = 560,
    this.height = 640,
    this.onTap,
    this.originRect,
    this.isClosing = false,
  });

  @override
  State<FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<FloatingPanel>
    with SingleTickerProviderStateMixin {
  late Offset _position;
  bool _positioned = false;
  late AnimationController _anim;
  late Animation<double> _curve;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _position = Offset.zero;
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _curve = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _anim.forward();
  }

  @override
  void didUpdateWidget(FloatingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isClosing && !oldWidget.isClosing) {
      _startClose();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _startClose() {
    if (_closing) return;
    _closing = true;
    _anim.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_closing) return;
    setState(() {
      _position += details.delta;
      if (_position.dy < 0) _position = Offset(_position.dx, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final avail = widget.availableSize;

    if (!_positioned) {
      _position = Offset(
        (avail.width - widget.width) / 2,
        (avail.height - widget.height) / 2,
      );
      _positioned = true;
    }

    final maxX = (avail.width - widget.width).clamp(0.0, double.infinity);
    final maxY = (avail.height - widget.height).clamp(0.0, double.infinity);
    final cx = _position.dx.clamp(0.0, maxX);
    final cy = _position.dy.clamp(0.0, maxY);

    final origin = widget.originRect;
    final targetLeft = cx;
    final targetTop = cy;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _curve.value;
        double left, top;
        double scale, opacity;

        if (origin != null && t < 1.0) {
          // 打开：从按钮飞到居中 / 关闭：从当前位置缩回按钮
          final originCx = origin.center.dx - widget.width / 2;
          final originCy = origin.center.dy - widget.height / 2;
          left = lerpDouble(originCx, targetLeft, t)!;
          top = lerpDouble(originCy, targetTop, t)!;
          scale = lerpDouble(0.15, 1.0, t)!;
          opacity = t.clamp(0.0, 1.0);
        } else {
          left = targetLeft;
          top = targetTop;
          scale = 1.0;
          opacity = 1.0;
        }

        return Positioned(
          left: left,
          top: top,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => widget.onTap?.call(),
        child: _buildPanel(context),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: c.panelBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.cardBorder),
            ),
            child: Column(
              children: [
                _buildTitleBar(context),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: c.titleBar,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          children: [
            Icon(Icons.drag_indicator_rounded, size: 14, color: c.text3),
            const SizedBox(width: 8),
            Text(widget.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text1, letterSpacing: 0.3)),
            const Spacer(),
            _PanelCloseButton(onTap: _startClose),
          ],
        ),
      ),
    );
  }
}

class _PanelCloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PanelCloseButton({required this.onTap});
  @override
  State<_PanelCloseButton> createState() => _PanelCloseButtonState();
}

class _PanelCloseButtonState extends State<_PanelCloseButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: _hovered ? c.closeHover.withOpacity(0.85) : c.hoverBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.close_rounded, size: 14, color: _hovered ? Colors.white : c.text2),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Android 兼容：用 showDialog 包装 Panel 组件
// ═══════════════════════════════════════════════════════════════════

/// 在 Android 上用半透明 Dialog 包装面板内容。
/// 进场：从底部微滑上来 + 缩放 + 淡入；退场：反向。
/// 返回的 Future 在关闭时完成。
Future<T?> showPanelDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  double width = 560,
  double height = 640,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, secondaryAnim, dialogChild) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: dialogChild),
        ),
      );
    },
    pageBuilder: (ctx, anim, secondaryAnim) {
      final c = AppColors.of(ctx);
      final size = MediaQuery.of(ctx).size;
      final isSmall = size.width < 600;
      final w = isSmall ? size.width * 0.93 : width;
      final h = isSmall ? size.height * 0.85 : height;
      return Center(
        // Material 祖先：内部的 TextField、Switch、InkWell 等必须有 Material
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: w,
            height: h,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.panelBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: c.titleBar,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    border: Border(bottom: BorderSide(color: c.divider)),
                  ),
                  child: Row(
                    children: [
                      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text1)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: c.hoverBg, borderRadius: BorderRadius.circular(6)),
                          child: Icon(Icons.close_rounded, size: 14, color: c.text2),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      );
    },
  );
}
