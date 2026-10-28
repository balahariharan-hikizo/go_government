import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A 3D Flip Card widget that rotates 180 degrees along the Y-axis in 3D perspective
/// to transition seamlessly between front and back views.
class Flip3DCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final Duration duration;
  final bool flipOnTap;
  final bool? isFlipped;
  final ValueChanged<bool>? onFlipChanged;

  const Flip3DCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 600),
    this.flipOnTap = true,
    this.isFlipped,
    this.onFlipChanged,
  });

  @override
  State<Flip3DCard> createState() => _Flip3DCardState();
}

class _Flip3DCardState extends State<Flip3DCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    if (widget.isFlipped == true) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(Flip3DCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != null && widget.isFlipped != _isFlippedNow()) {
      if (widget.isFlipped!) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  bool _isFlippedNow() => _controller.value >= 0.5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_controller.isAnimating) return;
    if (_controller.value < 0.5) {
      _controller.forward();
      widget.onFlipChanged?.call(true);
    } else {
      _controller.reverse();
      widget.onFlipChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.flipOnTap ? _toggleCard : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final double angle = _animation.value * math.pi;
          final bool isFront = angle < (math.pi / 2);

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: FractionalOffset.center,
            child: isFront
                ? widget.front
                : Transform(
                    transform: Matrix4.identity()..rotateY(math.pi), // Reverse back mirroring
                    alignment: FractionalOffset.center,
                    child: widget.back,
                  ),
          );
        },
      ),
    );
  }
}
