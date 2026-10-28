import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An interactive 3D perspective tilt card that rotates along X and Y axes
/// responding to finger touch/drag with physics spring-back and specular light glare.
class Tilt3DCard extends StatefulWidget {
  final Widget child;
  final double maxTiltAngle; // In radians (e.g. 0.15 = ~8.5 degrees)
  final double perspective; // Default 0.0012
  final BorderRadius? borderRadius;
  final bool enableGlare;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const Tilt3DCard({
    super.key,
    required this.child,
    this.maxTiltAngle = 0.16,
    this.perspective = 0.0012,
    this.borderRadius,
    this.enableGlare = true,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  State<Tilt3DCard> createState() => _Tilt3DCardState();
}

class _Tilt3DCardState extends State<Tilt3DCard> with SingleTickerProviderStateMixin {
  static int _lastTapTime = 0;
  late AnimationController _springController;
  late Animation<double> _rotXAnimation;
  late Animation<double> _rotYAnimation;

  double _rotX = 0.0;
  double _rotY = 0.0;
  bool _isPressed = false;
  Size _cardSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _rotXAnimation = const AlwaysStoppedAnimation(0.0);
    _rotYAnimation = const AlwaysStoppedAnimation(0.0);
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        setState(() {
          _rotX = _rotXAnimation.value;
          _rotY = _rotYAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, RenderBox box) {
    _cardSize = box.size;
    final localPos = details.localPosition;

    // Calculate normalized position from center (-1.0 to 1.0)
    final double normX = ((localPos.dx / _cardSize.width) * 2 - 1).clamp(-1.0, 1.0);
    final double normY = ((localPos.dy / _cardSize.height) * 2 - 1).clamp(-1.0, 1.0);

    // X tilt rotates around X axis (driven by Y offset), Y tilt rotates around Y axis (driven by X offset)
    setState(() {
      _rotX = -normY * widget.maxTiltAngle;
      _rotY = normX * widget.maxTiltAngle;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _springBack();
  }

  void _onPanCancel() {
    _springBack();
  }

  void _springBack() {
    setState(() {
      _isPressed = false;
    });
    _rotXAnimation = Tween<double>(begin: _rotX, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _rotYAnimation = Tween<double>(begin: _rotY, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _springController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // 3D Matrix transform with perspective projection
    final transform = Matrix4.identity()
      ..setEntry(3, 2, widget.perspective)
      ..rotateX(_rotX)
      ..rotateY(_rotY);

    // Calculate dynamic specular glare offset based on rotation
    final double glareX = -_rotY / widget.maxTiltAngle;
    final double glareY = -_rotX / widget.maxTiltAngle;
    final radius = widget.borderRadius ?? BorderRadius.circular(24);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: widget.width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : null),
          height: widget.height ?? (constraints.hasBoundedHeight ? constraints.maxHeight : null),
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) {
              setState(() => _isPressed = false);
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - _lastTapTime < 500) return;
              _lastTapTime = now;
              widget.onTap?.call();
            },
            onTapCancel: () => setState(() => _isPressed = false),
            onPanDown: (_) => setState(() => _isPressed = true),
            onPanUpdate: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) _onPanUpdate(details, box);
            },
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            child: AnimatedScale(
              scale: _isPressed ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutBack,
              child: Transform(
                transform: transform,
                alignment: FractionalOffset.center,
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      widget.child,

                  // Dynamic Specular Light Glare
                  if (widget.enableGlare && (_rotX.abs() > 0.005 || _rotY.abs() > 0.005))
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: LinearGradient(
                              begin: Alignment(glareX * 1.5 - 0.5, glareY * 1.5 - 0.5),
                              end: Alignment(glareX * 1.5 + 0.5, glareY * 1.5 + 0.5),
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(
                                  alpha: (math.sqrt(_rotX * _rotX + _rotY * _rotY) / widget.maxTiltAngle * 0.22)
                                      .clamp(0.0, 0.25),
                                ),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      },
    );
  }
}
