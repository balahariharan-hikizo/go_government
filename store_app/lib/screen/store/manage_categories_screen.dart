import 'package:flutter/material.dart';
import '../../model/category_model.dart';
import '../../model/product_model.dart';
import '../../model/store_model.dart';
import '../../network/category_api_service.dart';
import '../../network/product_api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import 'add_product_screen.dart';

class ManageCategoriesScreen extends StatefulWidget {
  final StoreModel store;

  const ManageCategoriesScreen({
    super.key,
    required this.store,
  });

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  bool _isLoading = true;
  List<CategoryModel> _allCategories = [];
  List<ProductModel> _allStoreProducts = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Navigation path for nested drill-down (List of parent category breadcrumbs)
  final List<CategoryModel> _navigationStack = [];

  CategoryModel? get _currentParent => _navigationStack.isNotEmpty ? _navigationStack.last : null;

  final List<String> _presetIcons = [
    '🌾', '🫘', '🛢️', '🧂', '🥦', '🍎', '🥔', '🥬',
    '💊', '🩹', '🍼', '🌿', '🥛', '☕', '🧼', '🏷️',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final catsFuture = CategoryApiService.getCategoriesByStore(widget.store.storeId);
      final prodsFuture = ProductApiService.getProductsByStore(widget.store.storeId);
      final results = await Future.wait([catsFuture, prodsFuture]);
      if (mounted) {
        setState(() {
          _allCategories = results[0] as List<CategoryModel>;
          _allStoreProducts = results[1] as List<ProductModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Filter categories displayed in current drill-down level
  List<CategoryModel> get _currentLevelCategories {
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      return _allCategories.where((c) => c.name.toLowerCase().contains(q) || c.description.toLowerCase().contains(q)).toList();
    }
    final parentId = _currentParent?.categoryId ?? '';
    return _allCategories.where((c) => c.parentCategoryId == parentId).toList();
  }

  // Direct products belonging strictly to current parent category (for drill-down view)
  List<ProductModel> get _currentParentDirectProducts {
    if (_currentParent == null) return [];
    return _getProductsForCategory(_currentParent!, includeSubcategories: false);
  }

  Set<String> _getDescendantCategoryIds(String categoryId) {
    final ids = <String>{categoryId};
    void addChildren(String pid) {
      for (final c in _allCategories) {
        if (c.parentCategoryId == pid && !ids.contains(c.categoryId)) {
          ids.add(c.categoryId);
          addChildren(c.categoryId);
        }
      }
    }
    addChildren(categoryId);
    return ids;
  }

  Set<String> _getDescendantCategoryNames(String categoryId) {
    final descendantIds = _getDescendantCategoryIds(categoryId);
    final names = <String>{};
    for (final c in _allCategories) {
      if (descendantIds.contains(c.categoryId)) {
        names.add(c.name.trim().toLowerCase());
      }
    }
    return names;
  }

  List<ProductModel> _getProductsForCategory(CategoryModel cat, {bool includeSubcategories = true}) {
    if (!includeSubcategories) {
      final catId = cat.categoryId;
      final catName = cat.name.trim().toLowerCase();
      return _allStoreProducts.where((p) {
        final idMatch = catId.isNotEmpty && (p.categoryId == catId);
        final nameMatch = p.category.trim().toLowerCase() == catName;
        return idMatch || nameMatch;
      }).toList();
    }

    final descendantIds = _getDescendantCategoryIds(cat.categoryId);
    final descendantNames = _getDescendantCategoryNames(cat.categoryId);

    return _allStoreProducts.where((p) {
      final pidMatch = p.categoryId.isNotEmpty && descendantIds.contains(p.categoryId);
      final pathMatch = p.categoryPath.any((cid) => descendantIds.contains(cid));
      final nameMatch = descendantNames.contains(p.category.trim().toLowerCase());
      return pidMatch || pathMatch || nameMatch;
    }).toList();
  }

  Map<String, int> _getProductStats(CategoryModel cat) {
    final direct = _getProductsForCategory(cat, includeSubcategories: false).length;
    final total = _getProductsForCategory(cat, includeSubcategories: true).length;
    return {
      'direct': direct,
      'total': total,
      'sub': total > direct ? total - direct : 0,
    };
  }

  void _navigateToAddProduct(CategoryModel cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          storeId: widget.store.storeId,
          storeCategory: widget.store.category,
          initialCategoryId: cat.categoryId,
        ),
      ),
    ).then((_) => _loadCategories());
  }

  void _navigateToEditProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          storeId: widget.store.storeId,
          storeCategory: widget.store.category,
          initialProduct: product,
        ),
      ),
    ).then((_) => _loadCategories());
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      width: Responsive.w(48),
      height: Responsive.w(48),
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined, color: Colors.grey.shade400, size: Responsive.w(22)),
    );
  }

  Widget _buildProductListItem(ProductModel p, {required VoidCallback onEdit}) {
    final bool inStock = p.stock > 0;
    return Container(
      padding: EdgeInsets.all(Responsive.w(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(12)),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.w(8)),
            child: p.image.isNotEmpty
                ? Image.network(
                    p.image,
                    width: Responsive.w(48),
                    height: Responsive.w(48),
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => _buildFallbackThumbnail(),
                  )
                : _buildFallbackThumbnail(),
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.sp(13.5),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: Responsive.h(2)),
                Row(
                  children: [
                    Text(
                      '₹${p.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: Responsive.sp(12.5),
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (p.originalPrice > p.price) ...[
                      SizedBox(width: Responsive.w(4)),
                      Text(
                        '₹${p.originalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: Responsive.sp(11),
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                    SizedBox(width: Responsive.w(6)),
                    Text(
                      '• ${p.unit}',
                      style: TextStyle(
                        fontSize: Responsive.sp(11),
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(4)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(6), vertical: Responsive.h(1.5)),
                  decoration: BoxDecoration(
                    color: inStock ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    inStock ? 'In Stock: ${p.stock}' : 'Out of Stock',
                    style: TextStyle(
                      fontSize: Responsive.sp(10),
                      fontWeight: FontWeight.w600,
                      color: inStock ? const Color(0xFF16A34A) : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
            onPressed: onEdit,
            tooltip: 'Edit Product',
          ),
        ],
      ),
    );
  }

  void _showCategoryProductsBottomSheet(CategoryModel cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String sheetSearch = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allCatProducts = _getProductsForCategory(cat, includeSubcategories: true);
            final filteredProducts = sheetSearch.isEmpty
                ? allCatProducts
                : allCatProducts.where((p) => p.title.toLowerCase().contains(sheetSearch.toLowerCase())).toList();
            final stats = _getProductStats(cat);

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: Responsive.h(12)),
                    width: Responsive.w(40),
                    height: Responsive.h(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.w(20),
                      Responsive.h(12),
                      Responsive.w(16),
                      Responsive.h(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: Responsive.w(38),
                          height: Responsive.w(38),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(Responsive.w(10)),
                          ),
                          child: Text(
                            cat.icon.isNotEmpty ? cat.icon : '🏷️',
                            style: TextStyle(fontSize: Responsive.sp(18)),
                          ),
                        ),
                        SizedBox(width: Responsive.w(10)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: Responsive.sp(15),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${stats['total']} Products (${stats['direct']} direct${stats['sub']! > 0 ? ', ${stats['sub']} in sub-categories' : ''})',
                                style: TextStyle(
                                  fontSize: Responsive.sp(11),
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _navigateToAddProduct(cat);
                          },
                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                          label: const Text(
                            'Add Product',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(16),
                      vertical: Responsive.h(6),
                    ),
                    child: TextField(
                      onChanged: (val) => setSheetState(() => sheetSearch = val.trim()),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'Search products in ${cat.name}...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(10)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(Responsive.w(24)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                                  SizedBox(height: Responsive.h(8)),
                                  Text(
                                    sheetSearch.isNotEmpty
                                        ? 'No products match "$sheetSearch"'
                                        : 'No products in "${cat.name}" yet',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                  ),
                                  SizedBox(height: Responsive.h(14)),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _navigateToAddProduct(cat);
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Add Product to this Category'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.all(Responsive.w(16)),
                            itemCount: filteredProducts.length,
                            separatorBuilder: (_, index) => SizedBox(height: Responsive.h(8)),
                            itemBuilder: (context, i) {
                              final p = filteredProducts[i];
                              return _buildProductListItem(p, onEdit: () {
                                Navigator.pop(ctx);
                                _navigateToEditProduct(p);
                              });
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEditCategorySheet([CategoryModel? existing, CategoryModel? parentOverride]) {
    final effectiveParent = parentOverride ?? _currentParent;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String selectedIcon = existing?.icon.isNotEmpty == true ? existing!.icon : '🏷️';
    bool isActive = existing?.isActive ?? true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: Responsive.w(20),
              right: Responsive.w(20),
              top: Responsive.h(20),
              bottom: MediaQuery.of(context).viewInsets.bottom + Responsive.h(20),
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: Responsive.w(44),
                      height: Responsive.h(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(16)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CustomText.title(
                        existing == null
                            ? (effectiveParent == null ? 'Add New Category' : 'Add Sub-Category to "${effectiveParent.name}"')
                            : 'Edit Category',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(12)),

                  // Icon Picker
                  CustomText.body('Select Category Icon', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  SizedBox(height: Responsive.h(8)),
                  SizedBox(
                    height: Responsive.h(46),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presetIcons.length,
                      separatorBuilder: (_, index) => SizedBox(width: Responsive.w(8)),
                      itemBuilder: (context, idx) {
                        final ic = _presetIcons[idx];
                        final isSelected = ic == selectedIcon;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedIcon = ic),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: Responsive.w(44),
                            height: Responsive.h(44),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(ic, style: TextStyle(fontSize: Responsive.sp(20))),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // Category Name Input
                  CustomText.body('Category Name *', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  SizedBox(height: Responsive.h(6)),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Rice & Grains, Pulses, Dairy',
                      prefixIcon: Container(
                        padding: EdgeInsets.all(Responsive.w(12)),
                        child: Text(selectedIcon, style: TextStyle(fontSize: Responsive.sp(18))),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(14)),

                  // Description Input
                  CustomText.body('Description (Optional)', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  SizedBox(height: Responsive.h(6)),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Brief description of items in this category',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(14)),

                  // Active Status Switch
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(10)),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText.body('Active Status', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.body(
                              isActive ? 'Visible to citizens in store & app' : 'Hidden from citizens in store',
                              fontSize: 11,
                              color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: isActive,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) => setSheetState(() => isActive = val),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: Responsive.h(48),
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter category name')),
                                );
                                return;
                              }

                              final messenger = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(ctx);
                              setSheetState(() => isSaving = true);
                              Map<String, dynamic> res;

                              if (existing == null) {
                                res = await CategoryApiService.createCategory(
                                  storeId: widget.store.storeId,
                                  name: name,
                                  parentCategoryId: effectiveParent?.categoryId ?? '',
                                  description: descCtrl.text.trim(),
                                  icon: selectedIcon,
                                  displayOrder: _allCategories.length + 1,
                                  isActive: isActive,
                                );
                              } else {
                                res = await CategoryApiService.updateCategory(
                                  existing.categoryId,
                                  name: name,
                                  description: descCtrl.text.trim(),
                                  icon: selectedIcon,
                                  isActive: isActive,
                                );
                              }

                              if (!mounted) return;
                              setSheetState(() => isSaving = false);
                              nav.pop();

                              if (res['success'] == true) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? 'Category saved successfully!'),
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                );
                                _loadCategories();
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(res['error'] ?? 'Operation failed'),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              existing == null ? 'Create Category' : 'Save Changes',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

  Future<void> _toggleCategoryStatus(CategoryModel cat, bool newStatus) async {
    final oldStatus = cat.isActive;
    setState(() {
      final idx = _allCategories.indexWhere((c) => c.categoryId == cat.categoryId);
      if (idx != -1) {
        _allCategories[idx] = cat.copyWith(isActive: newStatus);
      }
    });

    final res = await CategoryApiService.updateCategory(
      cat.categoryId,
      isActive: newStatus,
    );

    if (res['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? "'${cat.name}' is now ACTIVE and visible in store"
                  : "'${cat.name}' is now INACTIVE and hidden from citizens",
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: newStatus ? Colors.green.shade700 : Colors.grey.shade800,
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          final idx = _allCategories.indexWhere((c) => c.categoryId == cat.categoryId);
          if (idx != -1) {
            _allCategories[idx] = cat.copyWith(isActive: oldStatus);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to update category status'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _confirmDeleteCategory(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: Responsive.w(8)),
            const Text('Delete Category'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${cat.name}"?'),
            if (cat.productCount > 0) ...[
              SizedBox(height: Responsive.h(8)),
              Container(
                padding: EdgeInsets.all(Responsive.w(8)),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(
                  '⚠️ Notice: This category has ${cat.productCount} products. Items will be preserved but category will be removed from your catalog.',
                  style: TextStyle(fontSize: Responsive.sp(12), color: Colors.brown.shade800),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await CategoryApiService.deleteCategory(cat.categoryId);
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Category deleted'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                  _loadCategories();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['error'] ?? 'Failed to delete category'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _currentLevelCategories;

    return PopScope(
      canPop: _navigationStack.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _navigationStack.isNotEmpty) {
          setState(() {
            _navigationStack.removeLast();
          });
        }
      },
      child: CommonBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: CustomText.title(
              _currentParent == null ? 'Manage Categories' : _currentParent!.name,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 20),
              onPressed: () {
                if (_navigationStack.isNotEmpty) {
                  setState(() {
                    _navigationStack.removeLast();
                  });
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                onPressed: _loadCategories,
                tooltip: 'Refresh Categories',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEditCategorySheet(),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              _currentParent == null ? 'Add Category' : 'Add Sub-Category',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Column(
                  children: [
                    // Breadcrumb navigation bar if navigated into sub-categories
                    if (_navigationStack.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(16),
                          vertical: Responsive.h(8),
                        ),
                        color: Colors.grey.shade100,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _navigationStack.clear()),
                                child: Text(
                                  'Root',
                                  style: TextStyle(
                                    fontSize: Responsive.sp(12),
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              for (int i = 0; i < _navigationStack.length; i++) ...[
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(4)),
                                  child: Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade400),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _navigationStack.removeRange(i + 1, _navigationStack.length);
                                    });
                                  },
                                  child: Text(
                                    _navigationStack[i].name,
                                    style: TextStyle(
                                      fontSize: Responsive.sp(12),
                                      fontWeight: i == _navigationStack.length - 1 ? FontWeight.bold : FontWeight.w500,
                                      color: i == _navigationStack.length - 1 ? Colors.black87 : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // Category Banner inside Drill-Down view
                    if (_currentParent != null)
                      Container(
                        margin: EdgeInsets.fromLTRB(
                          Responsive.w(16),
                          Responsive.h(8),
                          Responsive.w(16),
                          Responsive.h(4),
                        ),
                        padding: EdgeInsets.all(Responsive.w(12)),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(Responsive.w(14)),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: Responsive.w(40),
                              height: Responsive.w(40),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(Responsive.w(10)),
                              ),
                              child: Text(
                                _currentParent!.icon.isNotEmpty ? _currentParent!.icon : '🏷️',
                                style: TextStyle(fontSize: Responsive.sp(20)),
                              ),
                            ),
                            SizedBox(width: Responsive.w(10)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentParent!.name,
                                    style: TextStyle(
                                      fontSize: Responsive.sp(15),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Builder(
                                    builder: (_) {
                                      final stats = _getProductStats(_currentParent!);
                                      return Text(
                                        '${stats['total']} Total Products • ${_currentLevelCategories.length} Sub-Categories',
                                        style: TextStyle(
                                          fontSize: Responsive.sp(11),
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _navigateToAddProduct(_currentParent!),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('+ Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),

                  // Search Bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.w(16),
                      Responsive.h(10),
                      Responsive.w(16),
                      Responsive.h(6),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        fontSize: Responsive.sp(14),
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: _currentParent == null ? 'Search categories...' : 'Search within ${_currentParent!.name}...',
                        hintStyle: TextStyle(
                          fontSize: Responsive.sp(14),
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.normal,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade500,
                          size: Responsive.w(22),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.cancel_rounded,
                                  color: Colors.grey.shade400,
                                  size: Responsive.w(18),
                                ),
                                splashRadius: 18,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(12),
                          vertical: Responsive.h(12),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  // Header with category & product stats for root view
                  if (_allCategories.isNotEmpty && _currentParent == null)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(20),
                        vertical: Responsive.h(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomText.subtitle(
                            _searchQuery.isEmpty
                                ? 'MAIN CATEGORIES (${filtered.length})'
                                : 'SEARCH RESULTS (${filtered.length})',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.w(8),
                              vertical: Responsive.h(3),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(Responsive.w(10)),
                            ),
                            child: Text(
                              '${_allStoreProducts.length} Total Products in Store',
                              style: TextStyle(
                                fontSize: Responsive.sp(11),
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Category & Product List
                  Expanded(
                    child: _allCategories.isEmpty
                        ? _buildEmptyState()
                        : _buildMainContent(filtered),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildMainContent(List<CategoryModel> filtered) {
    if (_currentParent == null) {
      if (filtered.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: Responsive.w(48), color: Colors.grey.shade400),
              SizedBox(height: Responsive.h(8)),
              Text(
                'No matching categories found',
                style: TextStyle(fontSize: Responsive.sp(14), color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: EdgeInsets.only(
          left: Responsive.w(16),
          right: Responsive.w(16),
          top: Responsive.h(6),
          bottom: Responsive.h(90),
        ),
        itemCount: filtered.length,
        separatorBuilder: (_, index) => SizedBox(height: Responsive.h(10)),
        itemBuilder: (context, idx) {
          final cat = filtered[idx];
          return _buildCategoryCard(cat);
        },
      );
    }

    // Drill-Down View into _currentParent
    final directProducts = _searchQuery.isEmpty
        ? _currentParentDirectProducts
        : _currentParentDirectProducts.where((p) => p.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filtered.isEmpty && directProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(Responsive.w(24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(16)),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.folder_open_rounded, size: Responsive.w(44), color: AppColors.primary),
              ),
              SizedBox(height: Responsive.h(14)),
              Text(
                'No sub-categories or products in "${_currentParent!.name}"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: Responsive.sp(14), fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              SizedBox(height: Responsive.h(6)),
              Text(
                'Add sub-categories to further organize, or add products directly to this category.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: Responsive.sp(12), color: Colors.grey.shade600),
              ),
              SizedBox(height: Responsive.h(18)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showAddEditCategorySheet(null, _currentParent),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                    label: const Text('Add Sub-Category'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  SizedBox(width: Responsive.w(10)),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddProduct(_currentParent!),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text('Add Product', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        left: Responsive.w(16),
        right: Responsive.w(16),
        top: Responsive.h(6),
        bottom: Responsive.h(90),
      ),
      children: [
        if (filtered.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: Responsive.h(8), top: Responsive.h(4)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomText.subtitle(
                  'SUB-CATEGORIES (${filtered.length})',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
                GestureDetector(
                  onTap: () => _showAddEditCategorySheet(null, _currentParent),
                  child: Text(
                    '+ Add Sub-Category',
                    style: TextStyle(
                      fontSize: Responsive.sp(11.5),
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...filtered.map((c) => Padding(
                padding: EdgeInsets.only(bottom: Responsive.h(10)),
                child: _buildCategoryCard(c),
              )),
          SizedBox(height: Responsive.h(10)),
        ],
        if (directProducts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: Responsive.h(8), top: Responsive.h(4)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomText.subtitle(
                  'PRODUCTS IN ${_currentParent!.name.toUpperCase()} (${directProducts.length})',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
                GestureDetector(
                  onTap: () => _navigateToAddProduct(_currentParent!),
                  child: Text(
                    '+ Add Product',
                    style: TextStyle(
                      fontSize: Responsive.sp(11.5),
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...directProducts.map((p) => Padding(
                padding: EdgeInsets.only(bottom: Responsive.h(8)),
                child: _buildProductListItem(p, onEdit: () => _navigateToEditProduct(p)),
              )),
        ],
      ],
    );
  }

  Widget _buildCategoryCard(CategoryModel cat) {
    final stats = _getProductStats(cat);
    final totalCount = stats['total'] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _navigationStack.add(cat);
          });
        },
        borderRadius: BorderRadius.circular(Responsive.w(14)),
        child: Container(
          padding: EdgeInsets.all(Responsive.w(12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Responsive.w(14)),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji / Icon Container
              Container(
                width: Responsive.w(44),
                height: Responsive.w(44),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                ),
                child: Text(
                  cat.icon.isNotEmpty ? cat.icon : '🏷️',
                  style: TextStyle(fontSize: Responsive.sp(22)),
                ),
              ),
              SizedBox(width: Responsive.w(12)),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomText.title(
                      cat.name,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                    if (cat.description.isNotEmpty) ...[
                      SizedBox(height: Responsive.h(2)),
                      CustomText.body(
                        cat.description,
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        maxLines: 1,
                      ),
                    ],
                    SizedBox(height: Responsive.h(4)),
                    Wrap(
                      spacing: Responsive.w(6),
                      runSpacing: Responsive.h(4),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Interactive Product Count Badge (Tap to see products sheet)
                        InkWell(
                          onTap: () => _showCategoryProductsBottomSheet(cat),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: Responsive.w(7), vertical: Responsive.h(2)),
                            decoration: BoxDecoration(
                              color: totalCount > 0 ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: totalCount > 0 ? AppColors.primary.withValues(alpha: 0.25) : Colors.grey.shade200,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: Responsive.sp(11),
                                  color: totalCount > 0 ? AppColors.primary : Colors.grey.shade600,
                                ),
                                SizedBox(width: Responsive.w(3)),
                                Text(
                                  totalCount == 1 ? '1 Product' : '$totalCount Products',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: Responsive.sp(10.5),
                                    fontWeight: FontWeight.w600,
                                    color: totalCount > 0 ? AppColors.primary : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(7), vertical: Responsive.h(2)),
                          decoration: BoxDecoration(
                            color: cat.subCategoryCount > 0 ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: Responsive.sp(11),
                                color: cat.subCategoryCount > 0 ? AppColors.primary : Colors.grey.shade600,
                              ),
                              SizedBox(width: Responsive.w(3)),
                              Text(
                                '${cat.subCategoryCount} Sub-cats',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.sp(10.5),
                                  fontWeight: FontWeight.w600,
                                  color: cat.subCategoryCount > 0 ? AppColors.primary : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(7), vertical: Responsive.h(2)),
                          decoration: BoxDecoration(
                            color: cat.isActive ? const Color(0xFFDCFCE7) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: Responsive.w(5),
                                height: Responsive.w(5),
                                decoration: BoxDecoration(
                                  color: cat.isActive ? const Color(0xFF16A34A) : Colors.grey.shade600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: Responsive.w(4)),
                              Text(
                                cat.isActive ? 'Active' : 'Inactive',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.sp(10),
                                  fontWeight: FontWeight.bold,
                                  color: cat.isActive ? const Color(0xFF16A34A) : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons: Active Switch + Edit + Options Menu (Add Product, Add Sub-cat, Delete) + Forward arrow
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: Responsive.w(36),
                    height: Responsive.h(26),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch.adaptive(
                        value: cat.isActive,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) => _toggleCategoryStatus(cat, val),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.all(Responsive.w(4)),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 19),
                    onPressed: () => _showAddEditCategorySheet(cat),
                    tooltip: 'Edit Category',
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600, size: 19),
                    onSelected: (val) {
                      if (val == 'view_products') {
                        _showCategoryProductsBottomSheet(cat);
                      } else if (val == 'add_product') {
                        _navigateToAddProduct(cat);
                      } else if (val == 'add_sub') {
                        _showAddEditCategorySheet(null, cat);
                      } else if (val == 'delete') {
                        _confirmDeleteCategory(cat);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'view_products',
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('View Products', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_product',
                        child: Row(
                          children: [
                            Icon(Icons.add_box_outlined, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Add Product Here', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_sub',
                        child: Row(
                          children: [
                            Icon(Icons.create_new_folder_outlined, size: 18, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Add Sub-Category', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Delete Category', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: Responsive.w(2)),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: Responsive.sp(12),
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(Responsive.w(20)),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.category_outlined, size: 56, color: AppColors.primary),
            ),
            SizedBox(height: Responsive.h(16)),
             CustomText.title(
              'No Categories Configured',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
            SizedBox(height: Responsive.h(8)),
            Text(
              'You haven\'t added any categories yet. Create categories to organize your store catalog.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.sp(13), color: Colors.grey.shade600),
            ),
            SizedBox(height: Responsive.h(20)),
           
        
          ],
        ),
      ),
    );
  }
}
