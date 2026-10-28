import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/app_colors.dart';
import '../utils/responsive_helper.dart';
import '../bloc/cart/cart_bloc.dart';
import '../bloc/cart/cart_event.dart';
import '../bloc/cart/cart_state.dart';

class CommonWishlistButton extends StatelessWidget {
  final Map<String, dynamic> product;
  final double? size;
  final bool isCircleStyle; // True for circular background with border (e.g. details page header), False for plain icon (e.g. cards)

  const CommonWishlistButton({
    super.key,
    required this.product,
    this.size,
    this.isCircleStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final String id = product['id']?.toString() ?? '';
    if (id.isEmpty) return const SizedBox.shrink();

    return BlocBuilder<CartBloc, CartState>(
      buildWhen: (prev, curr) => prev.favoriteIds != curr.favoriteIds,
      builder: (context, state) {
        final bool isFav = state.favoriteIds.contains(id);

        if (isCircleStyle) {
          return GestureDetector(
            onTap: () {
              context.read<CartBloc>().add(ToggleFavoriteEvent(id, product));
            },
            child: Container(
              width: Responsive.w(44),
              height: Responsive.w(44),
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.outliner,
                  width: Responsive.w(1.5),
                ),
              ),
              child: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? AppColors.primary : AppColors.black,
                size: size ?? Responsive.w(20),
              ),
            ),
          );
        } else {
          return GestureDetector(
            onTap: () {
              context.read<CartBloc>().add(ToggleFavoriteEvent(id, product));
            },
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? AppColors.primary : Colors.grey.shade400,
              size: size ?? Responsive.w(18),
            ),
          );
        }
      },
    );
  }
}
