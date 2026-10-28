import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An interactive 3D spinning coin that rotates along the Y-axis with perspective,
/// depth lighting, front/back faces, and interactive tap-spin burst.
class Spinning3DCoin extends StatefulWidget {
  final double size;
  final bool autoSpin;
  final Duration spinDuration;
  final VoidCallback? onTap;

  const Spinning3DCoin({
    super.key,
    this.size = 80,
    this.autoSpin = true,
    this.spinDuration = const Duration(seconds: 4),
    this.onTap,
  });

  @override
  State<Spinning3DCoin> createState() => _Spinning3DCoinState();
}

class _Spinning3DCoinState extends State<Spinning3DCoin> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.spinDuration,
    );

    if (widget.autoSpin) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerTapSpin() {
    widget.onTap?.call();
    // Fast 360° spin burst on tap
    final currentVal = _controller.value;
    _controller.animateTo(
      currentVal + 1.0,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (widget.autoSpin && mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerTapSpin,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double angle = (_controller.value * 2 * math.pi) % (2 * math.pi);
          final bool isFront = angle < (math.pi / 2) || angle > (3 * math.pi / 2);

          // 3D Matrix transform with perspective
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(angle);

          // Specular reflection calculation based on rotation
          final double lightIntensity = (math.cos(angle).abs()).clamp(0.0, 1.0);

          return Transform(
            transform: transform,
            alignment: FractionalOffset.center,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isFront
                      ? const [
                          Color(0xFFFFD54F), // Gold light
                          Color(0xFFFFA000), // Amber
                          Color(0xFFFF6F00), // Deep gold
                        ]
                      : const [
                          Color(0xFFFFE082),
                          Color(0xFFFFB300),
                          Color(0xFFE65100),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE65100).withValues(alpha: 0.35 * lightIntensity),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: Offset(math.sin(angle) * 4, 4),
                  ),
                ],
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFFFFF9C4),
                    const Color(0xFFFF8F00),
                    lightIntensity,
                  )!,
                  width: widget.size * 0.045,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inner coin ring
                  Container(
                    width: widget.size * 0.78,
                    height: widget.size * 0.78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),

                  // Coin Emblem (Indian Rupee ₹ Emblem)
                  Transform(
                    transform: isFront
                        ? Matrix4.identity()
                        : (Matrix4.identity()..rotateY(math.pi)), // Un-mirror back
                    alignment: FractionalOffset.center,
                    child: Icon(
                      Icons.currency_rupee_rounded,
                      color: Colors.white,
                      size: widget.size * 0.46,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFBF360C).withValues(alpha: 0.5),
                          offset: const Offset(0, 1.5),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),

                  // Metallic shine sheen
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.35 * lightIntensity),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.15 * (1 - lightIntensity)),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
