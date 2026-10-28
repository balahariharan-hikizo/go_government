import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/responsive_helper.dart';
import 'custom_text.dart';

class CommonCartBadge extends StatelessWidget {
  final int itemCount;
  final VoidCallback onTap;
  static int _lastTapTime = 0;

  const CommonCartBadge({
    super.key,
    required this.itemCount,
    required this.onTap,
  });

  void _handleTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTime < 500) return;
    _lastTapTime = now;
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _handleTap,
          child: Container(
            width: Responsive.w(52),
            height: Responsive.w(52),
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: AppColors.primary,
                width: Responsive.w(2.0),
              ),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.primary,
              size: Responsive.w(24),
            ),
          ),
        ),
        Positioned(
          right: -Responsive.w(4),
          top: -Responsive.h(4),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(6),
              vertical: Responsive.h(3),
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: CustomText.title(
              itemCount.toString().padLeft(2, '0'),
              color: AppColors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
