import 'package:flutter/material.dart';

/// Staggered entry transition for lists, cards, and screens.
/// Cascades the child with a smooth vertical slide and opacity fade-in.
class FadeSlideTransitionWidget extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDuration;
  final Duration delayIncrement;
  final double slideOffset;

  const FadeSlideTransitionWidget({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDuration = const Duration(milliseconds: 450),
    this.delayIncrement = const Duration(milliseconds: 60),
    this.slideOffset = 24.0,
  });

  @override
  State<FadeSlideTransitionWidget> createState() => _FadeSlideTransitionWidgetState();
}

class _FadeSlideTransitionWidgetState extends State<FadeSlideTransitionWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.baseDuration,
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 100),
      end: Offset.zero,
    ).animate(curve);

    final delay = widget.delayIncrement * widget.index;
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
