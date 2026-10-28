import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class CommonBackground extends StatelessWidget {
  final Widget child;

  const CommonBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.screenColor,
            AppColors.outliner, // Peach gradient at the bottom
          ],
          stops: [0.4, 1.0], // Smooth transition starting from 40% of the screen
        ),
      ),
      child: child,
    );
  }
}
