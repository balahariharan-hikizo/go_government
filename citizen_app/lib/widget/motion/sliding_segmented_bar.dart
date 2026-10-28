import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';

/// Modern segmented bar with a smooth sliding animated background pill.
class SlidingSegmentedBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double height;

  const SlidingSegmentedBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onTabSelected,
    this.height = 46.0,
  });

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final count = labels.length;

    return Container(
      height: Responsive.h(height),
      padding: EdgeInsets.all(Responsive.w(4)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - Responsive.w(4) * 2) / count;

          return Stack(
            children: [
              // Sliding Animated Pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Labels
              Row(
                children: List.generate(count, (index) {
                  final isSelected = selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTabSelected(index),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            fontSize: Responsive.sp(13),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.grayFont,
                            fontFamily: 'Valley Sans',
                          ),
                          child: Text(labels[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
