import 'package:flutter/material.dart';
import '../../model/category_model.dart';
import '../../model/store_model.dart';
import '../../network/category_api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

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
  List<CategoryModel> _categories = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    final list = await CategoryApiService.getCategoriesByStore(widget.store.storeId);
    if (mounted) {
      setState(() {
        _categories = list;
        _isLoading = false;
      });
    }
  }

  void _showAddEditCategorySheet([CategoryModel? existing]) {
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
                        existing == null ? 'Add New Category' : 'Edit Category',
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
                      separatorBuilder: (_, __) => SizedBox(width: Responsive.w(8)),
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
                              color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade100,
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

                              setSheetState(() => isSaving = true);
                              Map<String, dynamic> res;

                              if (existing == null) {
                                res = await CategoryApiService.createCategory(
                                  storeId: widget.store.storeId,
                                  name: name,
                                  description: descCtrl.text.trim(),
                                  icon: selectedIcon,
                                  displayOrder: _categories.length + 1,
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
                              Navigator.pop(ctx);

                              if (res['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? 'Category saved successfully!'),
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                );
                                _loadCategories();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
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
      final idx = _categories.indexWhere((c) => c.categoryId == cat.categoryId);
      if (idx != -1) {
        _categories[idx] = cat.copyWith(isActive: newStatus);
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
          final idx = _categories.indexWhere((c) => c.categoryId == cat.categoryId);
          if (idx != -1) {
            _categories[idx] = cat.copyWith(isActive: oldStatus);
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
    final filtered = _categories.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return CommonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title:  CustomText.title(
            'Manage Categories',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 20),
            onPressed: () => Navigator.pop(context),
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
          label: const Text('Add Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.w(16),
                      Responsive.h(12),
                      Responsive.w(16),
                      Responsive.h(8),
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
                        hintText: 'Search categories...',
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

                  // Header with category & product stats
                  if (_categories.isNotEmpty)
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
                                ? 'ALL CATEGORIES (${filtered.length})'
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
                              '${_categories.fold<int>(0, (sum, c) => sum + c.productCount)} Products Linked',
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

                  // Category List or Empty State
                  Expanded(
                    child: _categories.isEmpty
                        ? _buildEmptyState()
                        : filtered.isEmpty
                            ? Center(
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
                              )
                            : ListView.separated(
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
                              ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel cat) {
    return Container(
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
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(7), vertical: Responsive.h(2)),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${cat.productCount} Products',
                        style: TextStyle(
                          fontSize: Responsive.sp(10.5),
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
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

          // Action Buttons: Active Switch + Edit + Delete
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: Responsive.w(38),
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
              SizedBox(width: Responsive.w(4)),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.all(Responsive.w(4)),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                onPressed: () => _showAddEditCategorySheet(cat),
                tooltip: 'Edit Category',
              ),
              SizedBox(width: Responsive.w(4)),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.all(Responsive.w(4)),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => _confirmDeleteCategory(cat),
                tooltip: 'Delete Category',
              ),
            ],
          ),
        ],
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
                color: AppColors.primary.withOpacity(0.08),
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
