import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/product/product_bloc.dart';
import '../../bloc/product/product_event.dart';
import '../../bloc/product/product_state.dart';
import '../../constants/route_constants.dart';
import '../../model/product_model.dart';
import '../../model/store_model.dart';
import '../../network/api_client.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class ManageProductsScreen extends StatefulWidget {
  final StoreModel store;

  const ManageProductsScreen({
    super.key,
    required this.store,
  });

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(LoadStoreProductsEvent(widget.store.storeId));
  }

  void _editProduct(ProductModel product) async {
    if (_isNavigating) return;
    _isNavigating = true;
    await Navigator.pushNamed(
      context,
      RouteConstants.addProduct,
      arguments: {
        'storeId': widget.store.storeId,
        'storeCategory': widget.store.category,
        'initialProduct': product,
      },
    );
    if (mounted) _isNavigating = false;
  }

  void _deleteProduct(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Product'),
        content: Text('Are you sure you want to remove "${product.title}" from your catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProductBloc>().add(DeleteProductEvent(product.productId));
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: EdgeInsets.only(right: Responsive.w(8)),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(6)),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outliner,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.grayFont,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      appBar: AppBar(
        backgroundColor: AppColors.screenColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText.title('Store Inventory', fontSize: 16, color: AppColors.black),
            CustomText.body(widget.store.name, fontSize: 11, color: AppColors.grayFont),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined, color: AppColors.primary),
            tooltip: 'Manage Categories',
            onPressed: () async {
              if (_isNavigating) return;
              _isNavigating = true;
              await Navigator.pushNamed(
                context,
                RouteConstants.manageCategories,
                arguments: {'store': widget.store},
              );
              if (mounted) _isNavigating = false;
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.black),
            onPressed: () {
              context.read<ProductBloc>().add(LoadStoreProductsEvent(widget.store.storeId));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Product',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () async {
          if (_isNavigating) return;
          _isNavigating = true;
          await Navigator.pushNamed(
            context,
            RouteConstants.addProduct,
            arguments: {
              'storeId': widget.store.storeId,
              'storeCategory': widget.store.category,
            },
          );
          if (mounted) _isNavigating = false;
        },
      ),
      body: CommonBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(10)),
                child: Container(
                  height: Responsive.h(46),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Responsive.w(14)),
                    border: Border.all(color: AppColors.outliner.withValues(alpha: 0.6)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.grayFont, size: 20),
                      SizedBox(width: Responsive.w(8)),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search items in your catalog...',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchQuery = ''),
                          child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),

              // Filter Chips
              Container(
                height: Responsive.h(34),
                margin: EdgeInsets.only(bottom: Responsive.h(10)),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                  children: [
                    _buildFilterChip('All'),
                    _buildFilterChip('Low Stock (< 5)'),
                    _buildFilterChip('Subsidized'),
                    _buildFilterChip('Out of Stock'),
                  ],
                ),
              ),

              // Product List
              Expanded(
                child: BlocBuilder<ProductBloc, ProductState>(
                  builder: (context, state) {
                    if (state is ProductLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }

                    List<ProductModel> products = [];
                    if (state is ProductLoaded) {
                      products = state.products;
                    }

                    final filtered = products.where((p) {
                      final q = _searchQuery.toLowerCase();
                      final matchesSearch = p.title.toLowerCase().contains(q) ||
                          p.category.toLowerCase().contains(q) ||
                          p.brand.toLowerCase().contains(q);
                      if (!matchesSearch) return false;

                      if (_selectedFilter == 'Low Stock (< 5)') {
                        return p.stock > 0 && p.stock < 5;
                      } else if (_selectedFilter == 'Subsidized') {
                        return p.isSubsidized;
                      } else if (_selectedFilter == 'Out of Stock') {
                        return p.stock <= 0;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.all(Responsive.w(30)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: Responsive.w(70),
                                  height: Responsive.w(70),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.primary),
                                ),
                                SizedBox(height: Responsive.h(16)),
                                CustomText.header('No Products Found', fontSize: 16, color: AppColors.black),
                                SizedBox(height: Responsive.h(6)),
                                CustomText.body(
                                  _searchQuery.isNotEmpty
                                      ? 'No products matching "$_searchQuery"'
                                      : 'You have not added any products to this store yet.\nTap below to start adding items for citizens!',
                                  fontSize: 12,
                                  color: AppColors.grayFont,
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: Responsive.h(20)),
                                
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(8)),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => SizedBox(height: Responsive.h(12)),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildProductTile(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductTile(ProductModel item) {
    // Resolve image URL
    String? fullImageUrl;
    if (item.image.isNotEmpty) {
      fullImageUrl = item.image.startsWith('http')
          ? item.image
          : '${ApiClient.baseUrl.replaceAll('/api', '')}${item.image}';
    }

    final isOutOfStock = item.stock <= 0;

    return Container(
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(
          color: item.isAvailable ? AppColors.outliner.withValues(alpha: 0.5) : Colors.grey.shade300,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Thumbnail
          Container(
            width: Responsive.w(64),
            height: Responsive.w(64),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(Responsive.w(12)),
              border: Border.all(color: AppColors.outliner.withValues(alpha: 0.4)),
            ),
            child: fullImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                    child: Image.network(
                      fullImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_outlined, color: Colors.grey),
                    ),
                  )
                : const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 28),
          ),
          SizedBox(width: Responsive.w(12)),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomText.title(
                              item.title,
                              fontSize: 13,
                              color: AppColors.black,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isSubsidized) ...[
                            SizedBox(width: Responsive.w(4)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                'Govt Subsidized',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Product',
                      onPressed: () => _editProduct(item),
                    ),
                    SizedBox(width: Responsive.w(8)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete Product',
                      onPressed: () => _deleteProduct(item),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(2)),
                CustomText.body(
                  '${item.unit} • ${item.brand}',
                  fontSize: 11,
                  color: AppColors.grayFont,
                ),
                SizedBox(height: Responsive.h(6)),

                // Price & Discount row
                Row(
                  children: [
                    CustomText.title(
                      '₹${item.price.toStringAsFixed(0)}',
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    if (item.originalPrice > item.price) ...[
                      SizedBox(width: Responsive.w(6)),
                      Text(
                        '₹${item.originalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      if (item.discountPercentage.isNotEmpty) ...[
                        SizedBox(width: Responsive.w(6)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.discountPercentage,
                            style: const TextStyle(fontSize: 9, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                SizedBox(height: Responsive.h(8)),

                // Stock & Quick +/- Adjuster & Availability row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Stock badge + 1-Tap Quick Adjuster
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(7), vertical: Responsive.h(3)),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? const Color(0xFFFFEBEE)
                                : (item.stock <= 3 ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9)),
                            borderRadius: BorderRadius.circular(Responsive.w(6)),
                          ),
                          child: Text(
                            isOutOfStock ? '0' : 'Stock: ${item.stock}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOutOfStock
                                  ? Colors.red.shade700
                                  : (item.stock <= 3 ? Colors.orange.shade800 : const Color(0xFF16A34A)),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.w(6)),
                        // 1-Tap Stock Adjuster Buttons
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: item.stock > 0
                                    ? () {
                                        context.read<ProductBloc>().add(
                                              AdjustProductStockEvent(
                                                productId: item.productId,
                                                delta: -1,
                                              ),
                                            );
                                      }
                                    : null,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 14,
                                    color: item.stock > 0 ? AppColors.black : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Container(width: 1, height: 14, color: Colors.grey.shade300),
                              InkWell(
                                onTap: () {
                                  context.read<ProductBloc>().add(
                                        AdjustProductStockEvent(
                                          productId: item.productId,
                                          delta: 1,
                                        ),
                                      );
                                },
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 14,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Availability Switch
                    Row(
                      children: [
                        Text(
                          item.isAvailable ? 'Active' : 'Hidden',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isAvailable ? const Color(0xFF16A34A) : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: Responsive.w(2)),
                        Switch(
                          value: item.isAvailable,
                          activeThumbColor: const Color(0xFF16A34A),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) {
                            context.read<ProductBloc>().add(
                              ToggleProductAvailabilityEvent(
                                productId: item.productId,
                                isAvailable: val,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
