import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_animations.dart';

class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double scaleDown;
  final bool enableHaptic;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final double width;
  final double? height;

  const AnimatedPressButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleDown = 0.96, // Soft scale
    this.enableHaptic = true, 
    this.padding = const EdgeInsets.all(0),
    this.decoration,
    this.width = double.infinity,
    this.height,
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: AppAnimations.fast,
       reverseDuration: AppAnimations.fast,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact(); // Soft feedback on confirm
    }
    widget.onPressed();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppAnimations.smoothIn,
      ),
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: scale,
        builder: (context, child) {
          return Transform.scale(
            scale: scale.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: widget.decoration,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
