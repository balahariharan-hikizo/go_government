import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../widget/common_cart_badge.dart';
import 'package:go_government/bloc/product/product_bloc.dart';
import 'package:go_government/bloc/product/product_event.dart';
import 'package:go_government/bloc/product/product_state.dart';
import 'package:go_government/bloc/direction/direction_bloc.dart';
import 'package:go_government/bloc/direction/direction_event.dart';
import '../../../network/store_api_service.dart';
import '../../../constants/route_constants.dart';
import '../../../service/cart_manager.dart';
import '../../../widget/common_wishlist_button.dart';
import '../../../widget/common_directions_button.dart';
import '../../../services/translation_service.dart';
import '../../../network/api_client.dart';
import '../../../utils/call_launcher.dart';

class StoreDetailsScreen extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String storeAddress;
  final String storeImage;
  final String storeType; // 'medical' or 'vegstore'
  final String? storePhone;
  final String? ownerName;

  const StoreDetailsScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    required this.storeImage,
    required this.storeType,
    this.storePhone,
    this.ownerName,
  });

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  String _currentStorePhone = '';

  @override
  void initState() {
    super.initState();
    _currentStorePhone = widget.storePhone ?? '';

    if (_currentStorePhone.isEmpty && widget.storeId.isNotEmpty) {
      _fetchStoreContact();
    }

    // Dispatch a fetch directions event with real store address
    context.read<DirectionBloc>().add(FetchDirections(
          origin: 'Current Location',
          destination: widget.storeAddress,
        ));

    _cartListener = () {
      if (mounted) setState(() {});
    };
    _favListener = () {
      if (mounted) setState(() {});
    };
    CartManager.instance.cartItems.addListener(_cartListener);
    WishlistManager.instance.favoriteIds.addListener(_favListener);

    // Dispatch product load based on store id and store type
    context.read<ProductBloc>().add(LoadProducts(
          storeId: widget.storeId,
          storeType: widget.storeType,
        ));

    // 1. Setup filter categories based on store type
    if (widget.storeType == 'medical') {
      _categories = [
        {'title': 'Respiratory', 'image': 'assets/images/medicines/Property 1=Default.png'},
        {'title': 'Digestion', 'image': 'assets/images/medicines/Property 1=Default-1.png'},
        {'title': 'Skincare', 'image': 'assets/images/medicines/Property 1=Default-2.png'},
        {'title': 'Ortho', 'image': 'assets/images/medicines/Property 1=Default-3.png'},
        {'title': 'General', 'image': 'assets/images/medicines/Property 1=Default-4.png'},
        {'title': 'Baby Care', 'image': 'assets/images/medicines/Property 1=Default-5.png'},
      ];
    } else {
      _categories = [
        {'title': 'Veggies', 'image': 'assets/images/groceries/veg.png'},
        {'title': 'Fruits', 'image': 'assets/images/groceries/fruit.png'},
        {'title': 'Dairy', 'image': 'assets/images/groceries/milk.png'},
      ];
    }
  }

  Future<void> _fetchStoreContact() async {
    try {
      final store = await StoreApiService.fetchStoreDetails(widget.storeId);
      if (store != null && mounted) {
        setState(() {
          _currentStorePhone = (store['phone'] ?? '').toString();
        });
      }
    } catch (_) {}
  }

  String _searchQuery = '';
  int _selectedFilterIndex = 0;

  late final VoidCallback _cartListener;
  late final VoidCallback _favListener;

  late final List<Map<String, String>> _categories;

  @override
  void dispose() {
    CartManager.instance.cartItems.removeListener(_cartListener);
    WishlistManager.instance.favoriteIds.removeListener(_favListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total quantity of items in the cart
    final int totalCartCount = CartManager.instance.totalCartCount;

    // Filter products dynamically
    // Use products from ProductBloc state
    final productState = context.watch<ProductBloc>().state;
    final List<Map<String, dynamic>> allProducts =
        (productState is ProductLoaded) ? productState.products : [];
    final filteredProducts = allProducts.where((p) {
      final name = p['title'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Main content scroll view
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(20),
                    vertical: Responsive.h(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Space for the custom appBar
                      SizedBox(height: Responsive.h(60)),

                      // Search bar
                      Container(
                        height: Responsive.h(48),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(14)),
                          border: Border.all(
                            color: AppColors.outliner,
                            width: Responsive.w(1.2),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: TranslationService.translateSync('Search item'),
                                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.search, color: Colors.grey),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.h(16)),

                      // Store banner image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Responsive.w(16)),
                        child: _buildStoreBannerImage(
                          widget.storeImage,
                          widget.storeType,
                        ),
                      ),
                      SizedBox(height: Responsive.h(14)),

                      
                      // Categories filter horizontal list
                      SizedBox(
                        height: Responsive.h(64),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final bool isSelected = _selectedFilterIndex == index;
                            return Padding(
                              padding: EdgeInsets.only(right: Responsive.w(12)),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFilterIndex = index;
                                  });
                                },
                                child: Container(
                                  width: Responsive.h(64),
                                  height: Responsive.h(64),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(Responsive.w(20)),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.outliner,
                                      width: isSelected ? Responsive.w(2.0) : Responsive.w(1.2),
                                    ),
                                  ),
                                  padding: EdgeInsets.all(Responsive.w(10)),
                                  child: Image.asset(
                                    cat['image']!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: Responsive.h(24)),

                      // Product Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CustomText.header(
                              'All Items',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                RouteConstants.allProducts,
                                arguments: {
                                  'title': 'All Items',
                                  'products': allProducts,
                                  'storeType': widget.storeType,
                                },
                              );
                            },
                            child: CustomText.title(
                              'View All',
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(16)),

                      // Products Grid View or Empty State
                      if (productState is ProductLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: Responsive.h(40)),
                          child: const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        )
                      else if (filteredProducts.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.h(40),
                            horizontal: Responsive.w(20),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: Responsive.w(48),
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: Responsive.h(10)),
                                CustomText.title(
                                  'No Products Listed',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                                SizedBox(height: Responsive.h(4)),
                                CustomText.body(
                                  'This store has not added any products yet.',
                                  fontSize: 12,
                                  color: AppColors.grayFont,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: Responsive.w(12),
                            mainAxisSpacing: Responsive.h(12),
                            childAspectRatio: 0.72,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return _buildProductCard(product);
                          },
                        ),

                      // Bottom safe offset space
                      SizedBox(height: Responsive.h(80)),
                    ],
                  ),
                ),
              ),

              // 4. Custom App Bar overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: Responsive.h(60),
                  color: AppColors.screenColor.withValues(alpha: 0.9),
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button & Name
                      Expanded(
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
                            Expanded(
                              child: CustomText.header(
                                widget.storeName,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: Responsive.w(10)),

                      // Call Store button
                      if (_currentStorePhone.isNotEmpty) ...[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            CallLauncher.launchCall(
                              context,
                              phone: _currentStorePhone,
                              name: widget.storeName,
                            );
                          },
                          child: Container(
                            width: Responsive.w(44),
                            height: Responsive.w(44),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green.shade300,
                                width: Responsive.w(1.5),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.phone_outlined,
                              color: Color(0xFF2E7D32),
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),
                      ],

                      // Directions button
                      CommonDirectionsButton(
                        title: widget.storeName,
                        address: widget.storeAddress,
                        style: DirectionsButtonStyle.circle,
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: Responsive.h(20),
                right: Responsive.w(20),
               child: CommonCartBadge(
                  itemCount: totalCartCount,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      RouteConstants.cart,
                      arguments: widget.storeType,
                    );
                  },
                ),
              ),
            ],
          ),
        ),)
      
    );
  }

  Widget _buildStoreBannerImage(String? imagePath, String type) {
    final fallbackAsset = type == 'medical'
        ? 'assets/images/medical.png'
        : 'assets/images/vegstore.png';

    if (imagePath == null || imagePath.isEmpty) {
      return Image.asset(
        fallbackAsset,
        width: double.infinity,
        height: Responsive.h(140),
        fit: BoxFit.cover,
      );
    }

    final normalized = ApiClient.normalizeImageUrl(imagePath);
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Image.network(
        normalized,
        width: double.infinity,
        height: Responsive.h(140),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          fallbackAsset,
          width: double.infinity,
          height: Responsive.h(140),
          fit: BoxFit.cover,
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: double.infinity,
            height: Responsive.h(140),
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        },
      );
    }

    return Image.asset(
      imagePath,
      width: double.infinity,
      height: Responsive.h(140),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        fallbackAsset,
        width: double.infinity,
        height: Responsive.h(140),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildProductCardImage(String? imagePath, String storeType) {
    Widget buildPlaceholder() {
      return Container(
        height: Responsive.h(90),
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

  Widget _buildProductCard(Map<String, dynamic> product) {
    product['storeId'] = widget.storeId;
    product['storeName'] = widget.storeName;

    final String id = product['id'];
    final int qty = CartManager.instance.getQuantity(id);
    final int stock = CartManager.instance.getStock(product);
    final bool isOutOfStock = stock <= 0;
    final bool isMaxStock = qty >= stock;

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
          // 1. Stock & Heart Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Stock alert badge
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
                    const Spacer(),

                  // Favorite toggle
                  CommonWishlistButton(product: product),
                ],
              ),
              const Spacer(),
            ],
          ),

          // 2. Product Visual & Details
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RouteConstants.productDetails,
                    arguments: {
                      'product': product,
                      'storeType': widget.storeType,
                    },
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: Responsive.h(12)),
                    // Centered Product image
                    Center(
                      child: _buildProductCardImage(product['image'], widget.storeType),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    // Product Title
                    CustomText.title(
                      product['title'],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(height: Responsive.h(4)),

              // Pricing Details Row (Discount %, Struck Original Price, Current Price)
              Row(
                children: [
                  if (discount > 0) ...[
                    Icon(
                      Icons.arrow_downward,
                      color: const Color(0xFF4CAF50),
                      size: Responsive.w(10),
                    ),
                    CustomText.title(
                      '$discount% ',
                      color: const Color(0xFF4CAF50),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText.subtitle(
                      '₹${origPrice.toStringAsFixed(0)} ',
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ],
                  CustomText.title(
                    '₹${price.toStringAsFixed(0)}',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              SizedBox(height: Responsive.h(8)),

              // Cart Quantity Increment/Decrement or Plus (+) button
              if (isOutOfStock)
                Container(
                  height: Responsive.h(28),
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(Responsive.w(14)),
                  ),
                  child: Center(
                    child: Text(
                      'Out of Stock',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else if (qty > 0)
                Container(
                  height: Responsive.h(32),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(Responsive.w(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          CartManager.instance.updateQuantity(product, qty - 1, context: context);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                          child: const Icon(Icons.remove, color: Colors.white, size: 14),
                        ),
                      ),
                      CustomText.title(
                        qty.toString().padLeft(2, '0'),
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      GestureDetector(
                        onTap: () {
                          CartManager.instance.updateQuantity(product, qty + 1, context: context);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                          child: Icon(
                            Icons.add,
                            color: isMaxStock ? Colors.white.withValues(alpha: 0.4) : Colors.white,
                            size: 14,
                          ),
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
                      CartManager.instance.addToCart(product, qty: 1, context: context);
                    },
                    child: Container(
                      width: Responsive.w(28),
                      height: Responsive.w(28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: Responsive.w(1.5),
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: AppColors.primary,
                        size: Responsive.w(16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

}
