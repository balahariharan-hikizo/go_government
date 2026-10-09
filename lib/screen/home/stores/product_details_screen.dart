import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../widget/common_cart_badge.dart';
import '../../../constants/route_constants.dart';
import '../../../service/cart_manager.dart';
import '../../../widget/common_wishlist_button.dart';
import '../../../network/api_client.dart';
import '../../../network/product_api_service.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String storeType; // 'medical' or 'vegstore'

  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.storeType,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Map<String, dynamic> _product;
  bool _isHighlightsExpanded = false; // Start collapsed
  bool _isAllDetailsExpanded = false; // Start collapsed
  bool _isSpecsMoreExpanded = false; // Sub-section specs toggle
  String _selectedTab = 'Specs'; // 'Specs' or 'Mfg'
  int _currentImageIndex = 0;
  Map<String, dynamic>? _selectedVariant;

  List<String> get _productImages {
    final raw = _product['images'];
    if (raw is List && raw.isNotEmpty) {
      final list = raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      if (list.isNotEmpty) return list;
    }
    final single = _product['image']?.toString();
    if (single != null && single.isNotEmpty) return [single];
    return [];
  }

  List<Map<String, dynamic>> get _productVariants {
    final raw = _product['variants'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  String get _currentUnit => _selectedVariant != null
      ? (_selectedVariant!['unit']?.toString() ?? _product['unit']?.toString() ?? '1 Units')
      : (_product['unit']?.toString() ?? '1 Units');

  String get _activeCartKey {
    final pid = (_product['productId'] ?? _product['id'])?.toString() ?? '';
    final vid = _selectedVariant?['variantId']?.toString() ?? '';
    return vid.isNotEmpty ? '$pid:$vid' : pid;
  }

  Map<String, dynamic> _getActiveProductMap() {
    final map = Map<String, dynamic>.from(_product);
    final basePid = (_product['productId'] ?? _product['id'])?.toString() ?? '';
    map['productId'] = basePid;
    if (_selectedVariant != null) {
      final vid = _selectedVariant!['variantId']?.toString() ?? '';
      map['variantId'] = vid;
      map['id'] = vid.isNotEmpty ? '$basePid:$vid' : basePid;
      map['unit'] = _selectedVariant!['unit'] ?? map['unit'];
      map['price'] = _selectedVariant!['price'] ?? map['price'];
      map['originalPrice'] = _selectedVariant!['originalPrice'] ?? map['originalPrice'];
      if (_selectedVariant!['stock'] != null) {
        map['stock'] = _selectedVariant!['stock'];
      }
    } else {
      map['id'] = basePid;
    }
    return map;
  }

  late final VoidCallback _cartListener;
  late final VoidCallback _favListener;

  int get _quantity => CartManager.instance.getQuantity(_activeCartKey);
  int get _cartCount => CartManager.instance.totalCartCount;

  // Real-time products lists
  List<Map<String, dynamic>> _similarProducts = [];
  List<Map<String, dynamic>> _youMayAlsoLike = [];

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);

    final variants = _productVariants;
    if (variants.isNotEmpty) {
      final initialVid = widget.product['variantId']?.toString();
      final initialUnit = widget.product['unit']?.toString().trim();
      if (initialVid != null && initialVid.isNotEmpty) {
        _selectedVariant = variants.firstWhere(
          (v) => v['variantId']?.toString() == initialVid,
          orElse: () => variants.first,
        );
      } else if (initialUnit != null && initialUnit.isNotEmpty) {
        _selectedVariant = variants.firstWhere(
          (v) => (v['unit']?.toString().trim().toLowerCase() ?? '') == initialUnit.toLowerCase(),
          orElse: () => variants.first,
        );
      } else {
        _selectedVariant = variants.first;
      }
    }

    _cartListener = () {
      if (mounted) setState(() {});
    };
    _favListener = () {
      if (mounted) setState(() {});
    };
    CartManager.instance.cartItems.addListener(_cartListener);
    WishlistManager.instance.favoriteIds.addListener(_favListener);

    // Register active product details
    CartManager.instance.productDetails[_activeCartKey] = _getActiveProductMap();

    // Live background refresh from single product API & real store products
    _loadLiveProductDetails();
    _loadSimilarAndCrossSellProducts();
  }

  Future<void> _loadSimilarAndCrossSellProducts() async {
    final storeId = (_product['storeId'] ?? widget.product['storeId'])?.toString();
    if (storeId == null || storeId.trim().isEmpty) return;

    try {
      final realProducts = await ProductApiService.fetchProductsByStore(
        storeId,
        limit: 12,
        storeType: widget.storeType,
      );

      final currentId = (_product['id'] ?? _product['productId'] ?? _product['_id'])?.toString();
      final filtered = realProducts.where((p) {
        final pId = (p['id'] ?? p['productId'] ?? p['_id'])?.toString();
        return pId != null && pId.isNotEmpty && pId != currentId;
      }).toList();

      if (mounted) {
        setState(() {
          final currentCat = _product['category']?.toString().toLowerCase().trim();
          if (currentCat != null && currentCat.isNotEmpty && currentCat != 'all' && currentCat != 'general') {
            final sameCat = filtered.where((p) => (p['category'] ?? '').toString().toLowerCase().trim() == currentCat).toList();
            final diffCat = filtered.where((p) => (p['category'] ?? '').toString().toLowerCase().trim() != currentCat).toList();

            _similarProducts = sameCat.isNotEmpty ? sameCat : filtered.take(6).toList();
            _youMayAlsoLike = sameCat.isNotEmpty ? diffCat : filtered.skip(6).toList();
          } else {
            _similarProducts = filtered.take(6).toList();
            _youMayAlsoLike = filtered.skip(6).toList();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLiveProductDetails() async {
    final prodId = (_product['id'] ?? _product['productId'] ?? _product['_id'])?.toString();
    if (prodId == null || prodId.trim().isEmpty) return;

    try {
      final fresh = await ProductApiService.fetchProductDetails(prodId);
      if (fresh != null && mounted) {
        setState(() {
          _product.addAll(fresh);
          final variants = _productVariants;
          if (variants.isNotEmpty) {
            final curVid = _selectedVariant?['variantId']?.toString() ?? widget.product['variantId']?.toString();
            final curUnit = _selectedVariant?['unit']?.toString().trim() ?? widget.product['unit']?.toString().trim();
            if (curVid != null && curVid.isNotEmpty) {
              _selectedVariant = variants.firstWhere(
                (v) => v['variantId']?.toString() == curVid,
                orElse: () => variants.first,
              );
            } else if (curUnit != null && curUnit.isNotEmpty) {
              _selectedVariant = variants.firstWhere(
                (v) => (v['unit']?.toString().trim().toLowerCase() ?? '') == curUnit.toLowerCase(),
                orElse: () => variants.first,
              );
            } else {
              _selectedVariant ??= variants.first;
            }
          }
          CartManager.instance.productDetails[_activeCartKey] = _getActiveProductMap();
        });
        if (_similarProducts.isEmpty) {
          _loadSimilarAndCrossSellProducts();
        }
      }
    } catch (_) {
      // Retain existing cached/passed product on network failure
    }
  }

  @override
  void dispose() {
    CartManager.instance.cartItems.removeListener(_cartListener);
    WishlistManager.instance.favoriteIds.removeListener(_favListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int stock = _selectedVariant != null && _selectedVariant!['stock'] != null
        ? ((_selectedVariant!['stock'] as num).toInt())
        : CartManager.instance.getStock(_product);

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // 1. Scrollable Product Details list
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
                      // Space for custom appBar
                      SizedBox(height: Responsive.h(60)),

                      // Delivery Estimate Row
                      Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: const Color(0xFF4CAF50),
                            size: Responsive.w(18),
                          ),
                          SizedBox(width: Responsive.w(4)),
                          CustomText.title(
                            '25-30 mins',
                            color: const Color(0xFF4CAF50),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(12)),

                      // Product Hero Images Carousel / Swiper
                      Builder(builder: (context) {
                        final images = _productImages;
                        if (images.isEmpty) {
                          return Center(
                            child: _buildProductHeroImage(
                              _product['image'],
                              widget.storeType,
                            ),
                          );
                        }

                        return Column(
                          children: [
                            SizedBox(
                              height: Responsive.h(220),
                              child: PageView.builder(
                                itemCount: images.length,
                                onPageChanged: (idx) {
                                  setState(() => _currentImageIndex = idx);
                                },
                                itemBuilder: (context, index) {
                                  return Center(
                                    child: _buildProductHeroImage(
                                      images[index],
                                      widget.storeType,
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (images.length > 1) ...[
                              SizedBox(height: Responsive.h(10)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (index) {
                                  final isCurrent = index == _currentImageIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isCurrent ? Responsive.w(16) : Responsive.w(6),
                                    height: Responsive.w(6),
                                    margin: EdgeInsets.symmetric(horizontal: Responsive.w(3)),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(Responsive.w(3)),
                                      color: isCurrent ? AppColors.primary : Colors.grey.shade300,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ],
                        );
                      }),
                      SizedBox(height: Responsive.h(20)),

                      // Add to Cart Button (white button with orange border or quantity dial)
                      _buildCartActionButton(),
                      SizedBox(height: Responsive.h(20)),

                      // Subsidized Badge (if applicable)
                      if (_product['isSubsidized'] == true) ...[
                        Container(
                          margin: EdgeInsets.only(bottom: Responsive.h(8)),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(10),
                            vertical: Responsive.h(5),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(Responsive.w(8)),
                            border: Border.all(color: const Color(0xFF81C784)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, size: 14, color: Color(0xFF2E7D32)),
                              SizedBox(width: Responsive.w(4)),
                              Flexible(
                                child: Text(
                                  'Govt Subsidized Rate${(_product['subsidyLimit'] != null && _product['subsidyLimit'].toString().trim().isNotEmpty) ? ' (Limit: ${_product['subsidyLimit']})' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Stock alert if low
                      if (stock <= 3) ...[
                        Container(
                          margin: EdgeInsets.only(bottom: Responsive.h(8)),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(8),
                            vertical: Responsive.h(4),
                          ),
                          decoration: BoxDecoration(
                            color: stock <= 0
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(Responsive.w(6)),
                            border: Border.all(
                              color: stock <= 0
                                  ? const Color(0xFFFFCDD2)
                                  : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            stock <= 0
                                ? 'Out of stock'
                                : 'Hurry, only $stock left in stock!',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: stock <= 0
                                  ? Colors.red.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],

                      // Product Title with dynamic unit
                      CustomText.header(
                        '${_product['title']} ($_currentUnit)',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: Responsive.h(8)),

                      // Pricing Details Row (Dynamic based on selected variant)
                      Builder(builder: (context) {
                        final double price = _selectedVariant != null
                            ? ((_selectedVariant!['price'] as num?)?.toDouble() ?? 0.0)
                            : ((_product['price'] as num?)?.toDouble() ?? 0.0);
                        final double origPrice = _selectedVariant != null
                            ? ((_selectedVariant!['originalPrice'] as num?)?.toDouble() ?? price)
                            : ((_product['originalPrice'] as num?)?.toDouble() ?? price);
                        final int discount = origPrice > price && origPrice > 0
                            ? (((origPrice - price) / origPrice) * 100).round()
                            : ((_product['discountPercentage'] as num?)?.toInt() ?? 0);

                        return Row(
                          children: [
                            if (discount > 0) ...[
                              CustomText.title(
                                '$discount% OFF  ',
                                color: const Color(0xFF4CAF50),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              Text(
                                '₹${origPrice.toStringAsFixed(0)} ',
                                style: TextStyle(
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              SizedBox(width: Responsive.w(4)),
                            ],
                            CustomText.header(
                              '₹${price.toStringAsFixed(0)}',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        );
                      }),

                      // Available Sizes & Weights Chips (Variants)
                      if (_productVariants.isNotEmpty) ...[
                        SizedBox(height: Responsive.h(16)),
                        CustomText.title(
                          'Available Sizes / Weights:',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        SizedBox(height: Responsive.h(8)),
                        Wrap(
                          spacing: Responsive.w(8),
                          runSpacing: Responsive.h(8),
                          children: _productVariants.map((v) {
                            final isSel = _selectedVariant != null &&
                                _selectedVariant!['variantId'] == v['variantId'];
                            final vUnit = v['unit'] ?? '';
                            final vPrice = (v['price'] as num?)?.toDouble() ?? 0.0;
                            final vOrig = (v['originalPrice'] as num?)?.toDouble() ?? 0.0;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedVariant = v;
                                  CartManager.instance.productDetails[_activeCartKey] = _getActiveProductMap();
                                });
                              },
                              borderRadius: BorderRadius.circular(Responsive.w(10)),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.w(12),
                                  vertical: Responsive.h(8),
                                ),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(Responsive.w(10)),
                                  border: Border.all(
                                    color: isSel ? AppColors.primary : Colors.grey.shade300,
                                    width: isSel ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vUnit,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                        color: isSel ? AppColors.primary : Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: Responsive.h(2)),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '₹${vPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isSel ? AppColors.primary : Colors.black87,
                                          ),
                                        ),
                                        if (vOrig > vPrice) ...[
                                          SizedBox(width: Responsive.w(4)),
                                          Text(
                                            '₹${vOrig.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              decoration: TextDecoration.lineThrough,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      SizedBox(height: Responsive.h(12)),

                      // Quantity Pill & Cart Badge Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText.subtitle(
                                  'Selected Quantity: $_currentUnit',
                                  fontSize: 11,
                                  color: AppColors.grayFont,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: Responsive.h(8)),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade900,
                                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(16),
                                    vertical: Responsive.h(8),
                                  ),
                                  child: CustomText.title(
                                    _currentUnit,
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: Responsive.h(4)),
                                CustomText.title(
                                  stock <= 0 ? 'Out of stock' : '$stock left',
                                  color: stock <= 3 ? AppColors.error : AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          // Common Cart Badge on the right
                          CommonCartBadge(
                            itemCount: _cartCount,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                RouteConstants.cart,
                                arguments: widget.storeType,
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(20)),

                      // Dropdown Panel 1: Product Highlights
                      _buildHighlightsAccordion(),
                      const Divider(),

                      // Dropdown Panel 2: All Details
                      _buildAllDetailsAccordion(),
                      const Divider(),
                      SizedBox(height: Responsive.h(16)),

                      // Section similar products (Real-time from store/category)
                      if (_similarProducts.isNotEmpty) ...[
                        _buildCrossSellSection('Similar Products', _similarProducts),
                        SizedBox(height: Responsive.h(24)),
                      ],

                      // Section you may also like (Real-time cross-sell from store)
                      if (_youMayAlsoLike.isNotEmpty) ...[
                        _buildCrossSellSection('You May Also Like..', _youMayAlsoLike),
                        SizedBox(height: Responsive.h(24)),
                      ],

                      // Bottom Trust/Value Badges
                      _buildTrustBadgesRow(),
                      SizedBox(height: Responsive.h(60)),
                    ],
                  ),
                ),
              ),

              // 2. Custom App Bar overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: Responsive.h(60),
                  color: AppColors.screenColor.withValues(alpha: 0.95),
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                                'Near Stores',
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
                      SizedBox(width: Responsive.w(8)),
                      Row(
                        children: [
                          CommonWishlistButton(
                            product: _product,
                            isCircleStyle: true,
                          ),
                          SizedBox(width: Responsive.w(8)),
                          Container(
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
                              Icons.share_outlined,
                              color: AppColors.black,
                              size: Responsive.w(20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildProductHeroImage(String? imagePath, String storeType, {double? height}) {
    final effectiveHeight = height ?? Responsive.h(220);

    Widget buildNoImagePlaceholder() {
      return Container(
        height: effectiveHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: effectiveHeight > 100 ? Responsive.w(48) : Responsive.w(24),
                color: Colors.grey.shade400,
              ),
              if (effectiveHeight > 100) ...[
                SizedBox(height: Responsive.h(8)),
                Text(
                  'No Image Available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (imagePath == null || imagePath.trim().isEmpty) {
      return buildNoImagePlaceholder();
    }

    final normalized = ApiClient.normalizeImageUrl(imagePath);
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Image.network(
        normalized,
        height: effectiveHeight,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => buildNoImagePlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: effectiveHeight,
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
      height: effectiveHeight,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => buildNoImagePlaceholder(),
    );
  }

  Widget _buildCartActionButton() {
    final int qty = _quantity;
    final int stock = CartManager.instance.getStock(_product);
    final bool isOutOfStock = stock <= 0;
    final bool isMaxStock = qty >= stock;

    if (isOutOfStock) {
      return Container(
        width: double.infinity,
        height: Responsive.h(48),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(Responsive.w(24)),
          border: Border.all(
            color: Colors.grey.shade400,
            width: Responsive.w(1.5),
          ),
        ),
        child: Center(
          child: CustomText.title(
            'Out of Stock',
            color: Colors.grey.shade600,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (qty > 0) {
      return Container(
        height: Responsive.h(48),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(Responsive.w(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.white),
              onPressed: () {
                CartManager.instance.updateQuantity(_getActiveProductMap(), qty - 1, context: context);
              },
            ),
            CustomText.title(
              qty.toString().padLeft(2, '0'),
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            IconButton(
              icon: Icon(
                Icons.add,
                color: isMaxStock ? Colors.white.withValues(alpha: 0.4) : Colors.white,
              ),
              onPressed: () {
                CartManager.instance.updateQuantity(_getActiveProductMap(), qty + 1, context: context);
              },
            ),
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          CartManager.instance.addToCart(_getActiveProductMap(), qty: 1, context: context);
        },
        child: Container(
          width: double.infinity,
          height: Responsive.h(48),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Responsive.w(24)),
            border: Border.all(
              color: AppColors.primary,
              width: Responsive.w(1.5),
            ),
          ),
          child: Center(
            child: CustomText.title(
              'Add',
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildHighlightsAccordion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isHighlightsExpanded = !_isHighlightsExpanded;
            });
          },
          child: Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title('Product Highlights', fontSize: 14, fontWeight: FontWeight.bold),
                    SizedBox(height: Responsive.h(2)),
                    CustomText.subtitle('Key features, expiry, usage and more', fontSize: 11, color: Colors.grey),
                  ],
                ),
                Icon(
                  _isHighlightsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_isHighlightsExpanded)
          Padding(
            padding: EdgeInsets.only(top: Responsive.h(8), bottom: Responsive.h(12)),
            child: Container(
              padding: EdgeInsets.all(Responsive.w(16)),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(Responsive.w(16)),
              ),
              child: Column(
                children: [
                  _buildSpecRow(
                    'Pack of',
                    _product['packOf']?.toString() ?? '1',
                    'Brand',
                    _product['brand']?.toString() ?? 'Unbranded',
                  ),
                  const Divider(),
                  _buildSpecRow(
                    'Type',
                    _product['type']?.toString() ?? (widget.storeType == 'medical' ? 'Medicine' : 'Grocery'),
                    'Quantity',
                    _currentUnit,
                  ),
                  const Divider(),
                  _buildSpecRow(
                    'Shelf Life',
                    _product['shelfLife']?.toString() ?? '7 Days',
                    'Form Factor',
                    _product['formFactor']?.toString() ?? 'Standard',
                  ),
                  const Divider(),
                  _buildSpecRow(
                    'Subsidized',
                    _product['isSubsidized'] == true ? 'Yes (Govt Scheme)' : 'No',
                    'Origin',
                    _product['origin']?.toString() ?? 'India',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpecRow(String key1, String val1, String key2, String val2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.subtitle(key1, fontSize: 10, color: Colors.grey),
              SizedBox(height: Responsive.h(2)),
              CustomText.title(val1, fontSize: 12, fontWeight: FontWeight.bold),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.subtitle(key2, fontSize: 10, color: Colors.grey),
              SizedBox(height: Responsive.h(2)),
              CustomText.title(val2, fontSize: 12, fontWeight: FontWeight.bold),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllDetailsAccordion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isAllDetailsExpanded = !_isAllDetailsExpanded;
            });
          },
          child: Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title('All details', fontSize: 14, fontWeight: FontWeight.bold),
                    SizedBox(height: Responsive.h(2)),
                    CustomText.subtitle('Features, description and more', fontSize: 11, color: Colors.grey),
                  ],
                ),
                Icon(
                  _isAllDetailsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_isAllDetailsExpanded)
          Padding(
            padding: EdgeInsets.only(top: Responsive.h(8), bottom: Responsive.h(12)),
            child: Column(
              children: [
                // Tabs
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 'Specs';
                          });
                        },
                        child: Container(
                          height: Responsive.h(38),
                          decoration: BoxDecoration(
                            color: _selectedTab == 'Specs' ? const Color(0xFF4CAF50) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(Responsive.w(8)),
                          ),
                          child: Center(
                            child: CustomText.title(
                              'Specifications',
                              color: _selectedTab == 'Specs' ? Colors.white : Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.w(12)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 'Mfg';
                          });
                        },
                        child: Container(
                          height: Responsive.h(38),
                          decoration: BoxDecoration(
                            color: _selectedTab == 'Mfg' ? const Color(0xFF4CAF50) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(Responsive.w(8)),
                          ),
                          child: Center(
                            child: CustomText.title(
                              'Manufacturer info',
                              color: _selectedTab == 'Mfg' ? Colors.white : Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(16)),

                // Tab Content
                Container(
                  padding: EdgeInsets.all(Responsive.w(16)),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(Responsive.w(16)),
                  ),
                  width: double.infinity,
                  child: _selectedTab == 'Specs'
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((_product['description'] ?? '').toString().trim().isNotEmpty) ...[
                              CustomText.subtitle('Description', fontSize: 10, color: Colors.grey),
                              SizedBox(height: Responsive.h(2)),
                              CustomText.title(
                                _product['description'].toString(),
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                              ),
                              const Divider(),
                            ],
                            CustomText.subtitle('Generic name', fontSize: 10, color: Colors.grey),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.title(
                              _product['type']?.toString() ?? (widget.storeType == 'medical' ? 'Medicine' : 'Grocery'),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            const Divider(),
                            CustomText.subtitle('Country of origin', fontSize: 10, color: Colors.grey),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.title(
                              _product['origin']?.toString() ?? 'India',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            if (_isSpecsMoreExpanded) ...[
                              const Divider(),
                              CustomText.subtitle('Net Quantity', fontSize: 10, color: Colors.grey),
                              SizedBox(height: Responsive.h(2)),
                              CustomText.title(_currentUnit, fontSize: 12, fontWeight: FontWeight.bold),
                              const Divider(),
                              CustomText.subtitle('Storage Instructions', fontSize: 10, color: Colors.grey),
                              SizedBox(height: Responsive.h(2)),
                              CustomText.title('Store in a cool, ventilated place away from direct sunlight', fontSize: 11, fontWeight: FontWeight.bold),
                              const Divider(),
                              CustomText.subtitle('Customer Care', fontSize: 10, color: Colors.grey),
                              SizedBox(height: Responsive.h(2)),
                              CustomText.title('support@gogovernment.in | 1800-425-0000', fontSize: 11, fontWeight: FontWeight.bold),
                            ],
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText.subtitle('Name and address of the Manufacturer', fontSize: 10, color: Colors.grey),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.title(
                              '552, 2nd Floor 16th Main, 15th Cross Rd, 4th Sector, HSR Layout, Bengaluru, Karnataka 560102',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            const Divider(),
                            CustomText.subtitle('Name and address of the Packer', fontSize: 10, color: Colors.grey),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.title(
                              '552, 2nd Floor 16th Main, 15th Cross Rd, 4th Sector, HSR Layout, Bengaluru, Karnataka 560102',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            if (_isSpecsMoreExpanded) ...[
                              const Divider(),
                              CustomText.subtitle('Marketed By', fontSize: 10, color: Colors.grey),
                              SizedBox(height: Responsive.h(2)),
                              CustomText.title('Karnataka State Agro & Civic Supplies Ltd.', fontSize: 11, fontWeight: FontWeight.bold),
                              const Divider(),
                              CustomText.subtitle('License & Compliance', fontSize: 10, color: Colors.grey),
                              SizedBox(height: Responsive.h(2)),
                              CustomText.title('Govt Certified Quality Assured · FSSAI / Drug Lic. #9823412', fontSize: 11, fontWeight: FontWeight.bold),
                            ],
                          ],
                        ),
                ),
                SizedBox(height: Responsive.h(12)),

                // See more button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSpecsMoreExpanded = !_isSpecsMoreExpanded;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(Responsive.w(16)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText.title(_isSpecsMoreExpanded ? 'See less' : 'See more', fontSize: 12, color: Colors.grey.shade700),
                        Icon(
                          _isSpecsMoreExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCrossSellSection(String heading, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: CustomText.header(
                heading,
                fontSize: 15,
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
                    'title': heading,
                    'products': items,
                    'storeType': widget.storeType,
                  },
                );
              },
              child: CustomText.title('View All', color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(12)),
        SizedBox(
          height: Responsive.h(200),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final prod = items[index];
              return Padding(
                padding: EdgeInsets.only(right: Responsive.w(12)),
                child: _buildCrossSellCard(prod, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCrossSellCard(Map<String, dynamic> prod, int index) {
    final String id = (prod['id'] ?? prod['productId'] ?? '')?.toString() ?? '';
    final int qty = CartManager.instance.getQuantity(id);
    final double price = (prod['price'] as num?)?.toDouble() ?? 0.0;
    final double origPrice = (prod['originalPrice'] as num?)?.toDouble() ?? price;
    final int discount = origPrice > price && origPrice > 0 ? (((origPrice - price) / origPrice) * 100).round() : 0;
    final String title = (prod['title'] ?? prod['name'] ?? 'Product').toString();
    final String? img = prod['image']?.toString();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteConstants.productDetails,
          arguments: {
            'product': prod,
            'storeType': widget.storeType,
          },
        );
      },
      child: Container(
        width: Responsive.w(140),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(color: AppColors.outliner, width: 1.2),
        ),
        padding: EdgeInsets.all(Responsive.w(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heart icon + Image
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (index == 1)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(4), vertical: Responsive.h(2)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(Responsive.w(4)),
                    ),
                    child: const Text('Fast Delivery', style: TextStyle(color: Colors.green, fontSize: 7, fontWeight: FontWeight.bold)),
                  )
                else
                  const Spacer(),
                CommonWishlistButton(
                  product: prod,
                  size: 16,
                ),
              ],
            ),
            SizedBox(height: Responsive.h(4)),
            Center(
              child: _buildProductHeroImage(
                img,
                widget.storeType,
                height: Responsive.h(60),
              ),
            ),
            const Spacer(),
            CustomText.title(title, fontSize: 11, maxLines: 1),
            SizedBox(height: Responsive.h(2)),
            Row(
              children: [
                if (discount > 0) ...[
                  const Icon(Icons.arrow_downward, color: Colors.green, size: 8),
                  Text('$discount% ', style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('₹${origPrice.toStringAsFixed(0)} ', style: TextStyle(color: Colors.grey.shade400, fontSize: 8, decoration: TextDecoration.lineThrough)),
                ],
                Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: Responsive.h(6)),

            // Qty selector
            if (qty > 0)
              Container(
                height: Responsive.h(28),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(Responsive.w(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.remove, color: Colors.white, size: 12),
                      onPressed: () {
                        CartManager.instance.updateQuantity(prod, qty - 1);
                      },
                    ),
                    Text(qty.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.add, color: Colors.white, size: 12),
                      onPressed: () {
                        CartManager.instance.updateQuantity(prod, qty + 1);
                      },
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    CartManager.instance.updateQuantity(prod, 1);
                  },
                  child: Container(
                    width: Responsive.w(24),
                    height: Responsive.w(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.2),
                    ),
                    child: const Icon(Icons.add, color: AppColors.primary, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadgesRow() {
    return SizedBox(
      height: Responsive.h(70),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildTrustBadgeCard(Icons.cancel_presentation_outlined, 'Doorstep\nCancellation'),
          _buildTrustBadgeCard(Icons.assignment_return_outlined, '7-Day\nReturn'),
          _buildTrustBadgeCard(Icons.local_shipping_outlined, 'Cash on\nDelivery'),
          _buildTrustBadgeCard(Icons.verified_outlined, 'GOV\nAssured'),
        ],
      ),
    );
  }

  Widget _buildTrustBadgeCard(IconData icon, String label) {
    return Padding(
      padding: EdgeInsets.only(right: Responsive.w(10)),
      child: Container(
        width: Responsive.w(86),
        padding: EdgeInsets.all(Responsive.w(8)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(12)),
          border: Border.all(color: AppColors.outliner, width: 1.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: Responsive.w(18)),
            SizedBox(height: Responsive.h(4)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
