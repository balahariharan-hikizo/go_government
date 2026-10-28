import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/responsive_helper.dart';
import 'motion/bouncing_button.dart';

class CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Responsive.h(74),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE5DD),
        borderRadius: BorderRadius.circular(Responsive.w(30)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: Responsive.w(22),
            offset: Offset(0, Responsive.h(8)),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: Responsive.w(12),
            offset: Offset(0, Responsive.h(3)),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(12.0)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, null), // Home item
            _buildNavItem(1, Icons.description_outlined), // History/Document item
            _buildNavItem(2, Icons.storefront_outlined), // Store item
            _buildNavItem(3, Icons.account_balance_wallet_outlined), // Wallet item
            _buildNavItem(4, Icons.person_outline), // Profile item
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData? icon) {
    final bool isActive = currentIndex == index;

    return BouncingButton(
      scaleFactor: 0.88,
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: Responsive.w(52),
        height: Responsive.h(52),
        decoration: BoxDecoration(
          color: isActive ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: isActive
              ? Border.all(color: AppColors.primary, width: Responsive.w(1.8))
              : Border.all(color: Colors.transparent, width: Responsive.w(1.8)),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            scale: isActive ? 1.08 : 1.0,
            child: icon == null
                ? CustomPaint(
                    size: Size(Responsive.w(24), Responsive.h(24)),
                    painter: PentagonalHomePainter(
                      color: isActive ? AppColors.primary : AppColors.black.withValues(alpha: 0.85),
                      strokeWidth: Responsive.w(2.2),
                    ),
                  )
                : Icon(
                    icon,
                    color: isActive ? AppColors.primary : AppColors.black.withValues(alpha: 0.85),
                    size: Responsive.w(26),
                  ),
          ),
        ),
      ),
    );
  }
}

class PentagonalHomePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  PentagonalHomePainter({
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double w = size.width;
    final double h = size.height;

    // Draw custom pentagonal home shape (tilted walls, pointed roof)
    path.moveTo(w / 2, 1); // Tip
    path.lineTo(w - 1, h * 0.42); // Roof right end
    path.lineTo(w * 0.86, h - 1); // Wall right bottom
    path.lineTo(w * 0.14, h - 1); // Wall left bottom
    path.lineTo(1, h * 0.42); // Roof left end
    path.close();

    canvas.drawPath(path, paint);

    // Draw the horizontal door dash at the bottom
    canvas.drawLine(
      Offset(w * 0.36, h * 0.8),
      Offset(w * 0.64, h * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PentagonalHomePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
