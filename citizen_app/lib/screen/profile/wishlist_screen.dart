import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/route_constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../widget/common_wishlist_button.dart';
import '../../widget/common_cart_badge.dart';
import '../../network/api_client.dart';
import '../../bloc/cart/cart_bloc.dart';
import '../../bloc/cart/cart_event.dart';
import '../../bloc/cart/cart_state.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    CartBloc.instance.add(FetchCartAndWishlistEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          final wishlistedIds = state.favoriteIds;
          final products = wishlistedIds
              .map((id) => state.productDetails[id])
              .where((p) => p != null)
              .cast<Map<String, dynamic>>()
              .toList();

          return CommonBackground(
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Scrollable Wishlist products list
                  Positioned.fill(
                    child: products.isEmpty
                        ? _buildEmptyState()
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.w(20),
                              vertical: Responsive.h(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: Responsive.h(60)),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: Responsive.w(12),
                                    mainAxisSpacing: Responsive.h(12),
                                    childAspectRatio: 0.72,
                                  ),
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final product = products[index];
                                    return _buildProductCard(context, state, product);
                                  },
                                ),
                              ],
                            ),
                          ),
                  ),

                  // Custom Header Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: Responsive.h(60),
                      color: AppColors.screenColor.withValues(alpha: 0.95),
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
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
                                Icons.chevron_left,
                                color: AppColors.black,
                                size: Responsive.w(24),
                              ),
                            ),
                          ),
                          SizedBox(width: Responsive.w(12)),
                          CustomText.header(
                            'Wishlist',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Cart Badge Button overlay
                  Positioned(
                    bottom: Responsive.h(20),
                    right: Responsive.w(20),
                    child: CommonCartBadge(
                      itemCount: state.totalCartCount,
                      onTap: () {
                        String storeType = 'vegstore';
                        if (state.cartItems.isNotEmpty) {
                          final firstId = state.cartItems.keys.first;
                          if (firstId.startsWith('m')) {
                            storeType = 'medical';
                          }
                        }
                        Navigator.of(context).pushNamed(
                          RouteConstants.cart,
                          arguments: storeType,
                        );
                      },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: Responsive.w(80),
            height: Responsive.w(80),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border_outlined,
              color: AppColors.primary,
              size: Responsive.w(40),
            ),
          ),
          SizedBox(height: Responsive.h(20)),
          CustomText.header(
            'Your Wishlist is Empty',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: Responsive.h(8)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(40)),
            child: CustomText.subtitle(
              'Explore products and tap the heart icon to save your favorite items here!',
              fontSize: 12,
              color: Colors.grey.shade500,
              textAlign: TextAlign.center,
              height: 1.4,
            ),
          ),
          SizedBox(height: Responsive.h(24)),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed(RouteConstants.nearStores);
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(24),
                vertical: Responsive.h(12),
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(Responsive.w(24)),
              ),
              child: CustomText.title(
                'Start Shopping',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistImage(String? imagePath) {
    Widget buildPlaceholder() {
      return Container(
        height: Responsive.h(85),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(Responsive.w(10)),
          border: Border.all(color: Colors.grey.shade200, width: 0.8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: Responsive.w(26),
                color: Colors.grey.shade400,
              ),
              SizedBox(height: Responsive.h(2)),
              Text(
                'No image',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    if (imagePath == null || imagePath.trim().isEmpty) {
      return buildPlaceholder();
    }

    final normalized = ApiClient.normalizeImageUrl(imagePath);
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Image.network(
        normalized,
        height: Responsive.h(90),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => buildPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: Responsive.h(90),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        },
      );
    }

    return Image.asset(
      imagePath,
      height: Responsive.h(90),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => buildPlaceholder(),
    );
  }

  Widget _buildProductCard(BuildContext context, CartState state, Map<String, dynamic> product) {
    final String id = product['id']?.toString() ?? '';
    final int qty = state.cartItems[id] ?? 0;

    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final double origPrice = (product['originalPrice'] as num?)?.toDouble() ?? price;
    final int discount = (product['discountPercentage'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(
          color: AppColors.outliner,
          width: Responsive.w(1.2),
        ),
      ),
      padding: EdgeInsets.all(Responsive.w(10)),
      child: Stack(
        children: [
          // 1. Main details & Cart action (Base layer)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RouteConstants.productDetails,
                    arguments: {
                      'product': product,
                      'storeType': id.startsWith('m') ? 'medical' : 'vegstore',
                    },
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: Responsive.h(16)),
                    Center(
                      child: _buildWishlistImage(product['image']),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    CustomText.title(product['title'] ?? 'Product', fontSize: 12, fontWeight: FontWeight.bold, maxLines: 1),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  if (discount > 0) ...[
                    const Icon(Icons.arrow_downward, color: Color(0xFF4CAF50), size: 10),
                    Text('$discount% ', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('₹${origPrice.toStringAsFixed(0)} ', style: const TextStyle(fontSize: 10, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                  ],
                  Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: Responsive.h(8)),

              // Cart actions
              if (qty > 0)
                Container(
                  height: Responsive.h(32),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(Responsive.w(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          context.read<CartBloc>().add(UpdateQuantityEvent(id, qty - 1));
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                          child: const Icon(Icons.remove, color: Colors.white, size: 14),
                        ),
                      ),
                      Text(qty.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () {
                          context.read<CartBloc>().add(UpdateQuantityEvent(id, qty + 1));
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      context.read<CartBloc>().add(AddToCartEvent(id, product));
                    },
                    child: Container(
                      width: Responsive.w(28),
                      height: Responsive.w(28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                      child: const Icon(Icons.add, color: AppColors.primary, size: 16),
                    ),
                  ),
                ),
            ],
          ),

          // 2. Stock Badge & Heart Icon (Foreground layer - always rendered on top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (product['stockBadge'] != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(6),
                      vertical: Responsive.h(3),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(Responsive.w(6)),
                    ),
                    child: CustomText.title(
                      product['stockBadge'],
                      color: const Color(0xFF4CAF50),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                CommonWishlistButton(product: product),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
