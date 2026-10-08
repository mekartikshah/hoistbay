import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared animation durations and curves for the app
class AppAnimations {
  AppAnimations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve spring = Curves.easeOutBack;
}

/// Fade + slide transition for content switching
class FadeSlideTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Offset offset;

  const FadeSlideTransition({
    super.key,
    required this.child,
    this.duration = AppAnimations.medium,
    this.offset = const Offset(0, 0.02),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppAnimations.easeOut,
      switchOutCurve: AppAnimations.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: offset,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AppAnimations.easeOut,
            )),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Scale animation wrapper for buttons and cards
class ScaleOnPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  const ScaleOnPress({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.duration = AppAnimations.fast,
  });

  @override
  State<ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<ScaleOnPress> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: AppAnimations.easeInOut,
        child: widget.child,
      ),
    );
  }
}

/// Animated hover background for list items and cards
class AnimatedHoverBackground extends StatefulWidget {
  final Widget child;
  final Color defaultColor;
  final Color hoverColor;
  final BorderRadius? borderRadius;

  const AnimatedHoverBackground({
    super.key,
    required this.child,
    required this.defaultColor,
    required this.hoverColor,
    this.borderRadius,
  });

  @override
  State<AnimatedHoverBackground> createState() => _AnimatedHoverBackgroundState();
}

class _AnimatedHoverBackgroundState extends State<AnimatedHoverBackground> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppAnimations.normal,
        curve: AppAnimations.easeInOut,
        decoration: BoxDecoration(
          color: _isHovered ? widget.hoverColor : widget.defaultColor,
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Shimmer loading effect placeholder
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppColors.borderLight,
                AppColors.background,
                AppColors.borderLight,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlideGradientTransform(
                percent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double percent;

  const _SlideGradientTransform({required this.percent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (percent * 2 - 1),
      0.0,
      0.0,
    );
  }
}
