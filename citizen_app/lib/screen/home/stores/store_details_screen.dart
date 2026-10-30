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
import '../../../network/category_api_service.dart';
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
  String _selectedMainCategoryId = ''; // '' means All
  List<String> _selectedCategoryPath = []; // Path of subcategory IDs [level1, level2, level3, ... infinite]

  String get _selectedSubCategoryId =>
      _selectedCategoryPath.isNotEmpty ? _selectedCategoryPath[0] : '';
  String get _selectedChildCategoryId =>
      _selectedCategoryPath.length > 1 ? _selectedCategoryPath[1] : '';
  String get _selectedSubChildCategoryId =>
      _selectedCategoryPath.length > 2 ? _selectedCategoryPath[2] : '';
  List<Map<String, dynamic>> _storeCategories = [];
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _currentStorePhone = widget.storePhone ?? '';

    if (_currentStorePhone.isEmpty && widget.storeId.isNotEmpty) {
      _fetchStoreContact();
    }

    if (widget.storeId.isNotEmpty) {
      _fetchStoreCategories();
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

  Future<void> _fetchStoreCategories() async {
    try {
      final cats = await CategoryApiService.fetchCategoriesByStore(widget.storeId);
      if (mounted) {
        setState(() {
          _storeCategories = cats;
        });
      }
    } catch (_) {}
  }

  String _searchQuery = '';

  late final VoidCallback _cartListener;
  late final VoidCallback _favListener;

  @override
  void dispose() {
    CartManager.instance.cartItems.removeListener(_cartListener);
    WishlistManager.instance.favoriteIds.removeListener(_favListener);
    super.dispose();
  }

  Set<String> _getDescendantIds(String parentId, List<Map<String, dynamic>> allCats) {
    final Set<String> ids = {parentId};
    final List<String> queue = [parentId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final cat in allCats) {
        final pid = (cat['parentCategoryId'] ?? '').toString().trim();
        final cid = (cat['categoryId'] ?? '').toString().trim();
        if (pid == current && cid.isNotEmpty && ids.add(cid)) {
          queue.add(cid);
        }
      }
    }
    return ids;
  }

  Set<String> _getDescendantNames(String parentId, List<Map<String, dynamic>> allCats) {
    final ids = _getDescendantIds(parentId, allCats);
    final Set<String> names = {};
    for (final cat in allCats) {
      final cid = (cat['categoryId'] ?? '').toString().trim();
      final name = (cat['name'] ?? '').toString().trim().toLowerCase();
      if (ids.contains(cid) && name.isNotEmpty) {
        names.add(name);
      }
    }
    return names;
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

    // 1. Root / Main Categories (parentCategoryId is empty or null, level == 0)
    final rootCats = _storeCategories.where((c) {
      final pid = (c['parentCategoryId'] ?? '').toString().trim();
      final lvl = c['level'] is num ? (c['level'] as num).toInt() : 0;
      return pid.isEmpty || lvl == 0;
    }).toList();

    // Main category filter chips: starts with 'All'
    final List<Map<String, dynamic>> mainCategoryItems = [
      {'categoryId': '', 'name': 'All', 'icon': '', 'productCount': allProducts.length}
    ];
    if (rootCats.isNotEmpty) {
      for (final cat in rootCats) {
        final name = cat['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          mainCategoryItems.add({
            'categoryId': cat['categoryId']?.toString() ?? '',
            'name': name,
            'icon': cat['icon']?.toString().trim() ?? '',
            'productCount': cat['productCount'] ?? 0,
          });
        }
      }
    } else {
      // Fallback: extract distinct categories from products if no Category master docs configured
      final Set<String> seen = {};
      for (final p in allProducts) {
        final cat = p['category']?.toString().trim() ?? '';
        if (cat.isNotEmpty && !seen.contains(cat.toLowerCase())) {
          seen.add(cat.toLowerCase());
          mainCategoryItems.add({
            'categoryId': '',
            'name': cat,
            'icon': '',
            'productCount': 0,
          });
        }
      }
    }

    // 2. Sub-categories under the currently selected main category (Level 1)
    final List<Map<String, dynamic>> subCategoryItems = [];
    if (_selectedMainCategoryId.isNotEmpty) {
      final subCats = _storeCategories.where((c) {
        final pid = (c['parentCategoryId'] ?? '').toString().trim();
        return pid == _selectedMainCategoryId;
      }).toList();

      if (subCats.isNotEmpty) {
        final selectedMain = _storeCategories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['categoryId'] == _selectedMainCategoryId,
          orElse: () => null,
        );
        final mainName = selectedMain?['name'] ?? 'All';
        subCategoryItems.add({
          'categoryId': '',
          'name': 'All $mainName',
          'icon': '',
          'hasChildren': false,
        });
        for (final sub in subCats) {
          final subName = sub['name']?.toString().trim() ?? '';
          final subId = sub['categoryId']?.toString() ?? '';
          if (subName.isNotEmpty) {
            final hasChildren = _storeCategories.any((c) => (c['parentCategoryId'] ?? '').toString().trim() == subId);
            subCategoryItems.add({
              'categoryId': subId,
              'name': subName,
              'icon': sub['icon']?.toString().trim() ?? '',
              'hasChildren': hasChildren,
            });
          }
        }
      }
    }

    // 3. Child categories under the currently selected sub-category (Level 2)
    final List<Map<String, dynamic>> childCategoryItems = [];
    if (_selectedSubCategoryId.isNotEmpty) {
      final childCats = _storeCategories.where((c) {
        final pid = (c['parentCategoryId'] ?? '').toString().trim();
        return pid == _selectedSubCategoryId;
      }).toList();

      if (childCats.isNotEmpty) {
        final selectedSub = _storeCategories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['categoryId'] == _selectedSubCategoryId,
          orElse: () => null,
        );
        final subName = selectedSub?['name'] ?? 'All';
        childCategoryItems.add({
          'categoryId': '',
          'name': 'All $subName',
          'icon': '',
          'hasChildren': false,
        });
        for (final child in childCats) {
          final childName = child['name']?.toString().trim() ?? '';
          final childId = child['categoryId']?.toString() ?? '';
          if (childName.isNotEmpty) {
            final hasChildren = _storeCategories.any((c) => (c['parentCategoryId'] ?? '').toString().trim() == childId);
            childCategoryItems.add({
              'categoryId': childId,
              'name': childName,
              'icon': child['icon']?.toString().trim() ?? '',
              'hasChildren': hasChildren,
            });
          }
        }
      }
    }

    // 4. Dynamic Deeper Categories (Level 3, Level 4, Level 5... Infinite Depth!)
    final List<Map<String, dynamic>> deeperCategoryItems = [];
    bool showDeeperBackChip = false;
    String backTargetName = '';
    String activeDeeperParentId = '';

    if (_selectedCategoryPath.length >= 2) {
      final lastId = _selectedCategoryPath.last;
      final directChildrenOfLast = _storeCategories.where((c) {
        final pid = (c['parentCategoryId'] ?? '').toString().trim();
        return pid == lastId;
      }).toList();

      if (directChildrenOfLast.isNotEmpty) {
        // Last selected category HAS children -> display its children!
        activeDeeperParentId = lastId;
      } else if (_selectedCategoryPath.length > 2) {
        // Only if we are ALREADY deeper than Level 2 (i.e. Level 3+) and selecting a leaf item,
        // stay showing the siblings under its parent!
        activeDeeperParentId = _selectedCategoryPath[_selectedCategoryPath.length - 2];
      }

      // CRITICAL: Only query deeper categories if activeDeeperParentId is NOT empty!
      // Otherwise, an empty string query matches root categories (Level 0 parent like 'Grocery')!
      if (activeDeeperParentId.isNotEmpty) {
        final deeperCats = _storeCategories.where((c) {
          final pid = (c['parentCategoryId'] ?? '').toString().trim();
          return pid == activeDeeperParentId;
        }).toList();

        if (deeperCats.isNotEmpty) {
          // Show back chip ONLY if we drilled down deeper than Level 3 (Level 4+)
          final parentIdx = _selectedCategoryPath.indexOf(activeDeeperParentId);
          if (parentIdx > 1) {
            showDeeperBackChip = true;
            final prevCatId = _selectedCategoryPath[parentIdx - 1];
            final prevCat = _storeCategories.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c?['categoryId'] == prevCatId,
              orElse: () => null,
            );
            backTargetName = prevCat?['name'] ?? 'Back';
          }

          final parentCat = _storeCategories.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c?['categoryId'] == activeDeeperParentId,
            orElse: () => null,
          );
          final deeperParentName = parentCat?['name'] ?? 'All';

          deeperCategoryItems.add({
            'categoryId': '',
            'name': 'All $deeperParentName',
            'hasChildren': false,
            'isAllChip': true,
            'activeParentId': activeDeeperParentId,
          });

          for (final sc in deeperCats) {
            final scName = sc['name']?.toString().trim() ?? '';
            final scId = sc['categoryId']?.toString() ?? '';
            if (scName.isNotEmpty) {
              final hasChildren = _storeCategories.any((c) => (c['parentCategoryId'] ?? '').toString().trim() == scId);
              deeperCategoryItems.add({
                'categoryId': scId,
                'name': scName,
                'hasChildren': hasChildren,
                'activeParentId': activeDeeperParentId,
              });
            }
          }
        }
      }
    }

    // 5. Target category for filtering (Infinite depth target)
    final String targetCatId = _selectedCategoryPath.isNotEmpty
        ? _selectedCategoryPath.last
        : _selectedMainCategoryId;

    final Set<String> targetIds = targetCatId.isNotEmpty
        ? _getDescendantIds(targetCatId, _storeCategories)
        : const {};
    final Set<String> targetNames = targetCatId.isNotEmpty
        ? _getDescendantNames(targetCatId, _storeCategories)
        : const {};

    final filteredProducts = allProducts.where((p) {
      final name = p['title'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty || name.contains(query);
      if (!matchesSearch) return false;

      if (targetCatId.isEmpty) return true;

      final pCatId = (p['categoryId'] ?? '').toString().trim();
      final pPath = p['categoryPath'] is List
          ? (p['categoryPath'] as List).map((e) => e.toString().trim()).toList()
          : <String>[];
      final pCatName = (p['category'] ?? '').toString().toLowerCase().trim();

      return targetIds.contains(pCatId) ||
          pPath.any((id) => targetIds.contains(id)) ||
          targetNames.contains(pCatName);
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

                      // Category Filter Chips
                      if (mainCategoryItems.length > 1) ...[
                        SizedBox(
                          height: Responsive.h(38),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: mainCategoryItems.length,
                            separatorBuilder: (context, index) => SizedBox(width: Responsive.w(8)),
                            itemBuilder: (context, index) {
                              final item = mainCategoryItems[index];
                              final catId = item['categoryId'] as String;
                              final catName = item['name'] as String;
                              final icon = item['icon'] as String? ?? '';
                              final isSelected = _selectedMainCategoryId == catId;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMainCategoryId = catId;
                                    _selectedCategoryPath = [];
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(14),
                                    vertical: Responsive.h(8),
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.white,
                                    borderRadius: BorderRadius.circular(Responsive.w(20)),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.outliner,
                                      width: 1.2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (icon.isNotEmpty) ...[
                                          Text(icon, style: const TextStyle(fontSize: 13)),
                                          SizedBox(width: Responsive.w(5)),
                                        ],
                                        CustomText.title(
                                          catName,
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? Colors.white : AppColors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Secondary Sub-Category Filter Chips (Level 1)
                        if (subCategoryItems.isNotEmpty) ...[
                          SizedBox(height: Responsive.h(10)),
                          SizedBox(
                            height: Responsive.h(32),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: subCategoryItems.length,
                              separatorBuilder: (context, index) => SizedBox(width: Responsive.w(8)),
                              itemBuilder: (context, index) {
                                final item = subCategoryItems[index];
                                final subId = item['categoryId'] as String;
                                final subName = item['name'] as String;
                                final hasChildren = item['hasChildren'] == true;
                                final isSubSelected = _selectedSubCategoryId == subId;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (subId.isEmpty) {
                                        _selectedCategoryPath = [];
                                      } else {
                                        _selectedCategoryPath = [subId];
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.w(12),
                                      vertical: Responsive.h(5),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSubSelected
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(Responsive.w(16)),
                                      border: Border.all(
                                        color: isSubSelected ? AppColors.primary : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CustomText.body(
                                            subName,
                                            fontSize: 12,
                                            fontWeight: isSubSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSubSelected ? AppColors.primary : Colors.black87,
                                          ),
                                          if (hasChildren) ...[
                                            SizedBox(width: Responsive.w(3)),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              size: Responsive.w(14),
                                              color: isSubSelected ? AppColors.primary : Colors.grey.shade600,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        // Tertiary Child Category Filter Chips (Level 2 - Sub category's sub category)
                        if (childCategoryItems.isNotEmpty) ...[
                          SizedBox(height: Responsive.h(8)),
                          SizedBox(
                            height: Responsive.h(28),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: childCategoryItems.length,
                              separatorBuilder: (context, index) => SizedBox(width: Responsive.w(6)),
                              itemBuilder: (context, index) {
                                final item = childCategoryItems[index];
                                final childId = item['categoryId'] as String;
                                final childName = item['name'] as String;
                                final hasChildren = item['hasChildren'] == true;
                                final isChildSelected = childId.isEmpty
                                    ? (_selectedCategoryPath.length == 1)
                                    : (_selectedCategoryPath.length > 1 && _selectedCategoryPath[1] == childId);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (childId.isEmpty) {
                                        _selectedCategoryPath = [_selectedCategoryPath[0]];
                                      } else {
                                        _selectedCategoryPath = [_selectedCategoryPath[0], childId];
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.w(10),
                                      vertical: Responsive.h(4),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isChildSelected
                                          ? AppColors.primary
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(Responsive.w(14)),
                                      border: Border.all(
                                        color: isChildSelected ? AppColors.primary : Colors.grey.shade300,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CustomText.body(
                                            childName,
                                            fontSize: 11,
                                            fontWeight: isChildSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isChildSelected ? Colors.white : Colors.black87,
                                          ),
                                          if (hasChildren && childId.isNotEmpty) ...[
                                            SizedBox(width: Responsive.w(2)),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              size: Responsive.w(13),
                                              color: isChildSelected ? Colors.white : Colors.grey.shade600,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        // Dynamic Deeper Category Filter Chips (Level 3, 4, 5... Infinite Depth)
                        if (deeperCategoryItems.isNotEmpty) ...[
                          SizedBox(height: Responsive.h(6)),
                          SizedBox(
                            height: Responsive.h(28),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: deeperCategoryItems.length + (showDeeperBackChip ? 1 : 0),
                              separatorBuilder: (context, index) => SizedBox(width: Responsive.w(6)),
                              itemBuilder: (context, index) {
                                if (showDeeperBackChip && index == 0) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        final parentIdx = _selectedCategoryPath.indexOf(activeDeeperParentId);
                                        if (parentIdx > 1) {
                                          _selectedCategoryPath = _selectedCategoryPath.sublist(0, parentIdx);
                                        } else {
                                          _selectedCategoryPath = _selectedCategoryPath.sublist(0, 2);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.w(8),
                                        vertical: Responsive.h(3),
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.arrow_back_ios_rounded, size: 9, color: Colors.grey.shade800),
                                          SizedBox(width: Responsive.w(2)),
                                          Text(
                                            backTargetName,
                                            style: TextStyle(
                                              fontSize: Responsive.sp(9.5),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final item = deeperCategoryItems[showDeeperBackChip ? index - 1 : index];
                                final scId = item['categoryId'] as String;
                                final scName = item['name'] as String;
                                final hasChildren = item['hasChildren'] == true;
                                final isAllChip = item['isAllChip'] == true;

                                final bool isSelected = isAllChip
                                    ? (_selectedCategoryPath.last == activeDeeperParentId)
                                    : (_selectedCategoryPath.contains(scId) && (_selectedCategoryPath.last == scId || !hasChildren));

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      final parentIdx = _selectedCategoryPath.indexOf(activeDeeperParentId);
                                      if (parentIdx != -1) {
                                        _selectedCategoryPath = _selectedCategoryPath.sublist(0, parentIdx + 1);
                                      }
                                      if (!isAllChip && scId.isNotEmpty) {
                                        _selectedCategoryPath.add(scId);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.w(10),
                                      vertical: Responsive.h(4),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(Responsive.w(14)),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CustomText.body(
                                            scName,
                                            fontSize: 10.5,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? Colors.white : Colors.black87,
                                          ),
                                          if (hasChildren && scId.isNotEmpty) ...[
                                            SizedBox(width: Responsive.w(2)),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              size: Responsive.w(13),
                                              color: isSelected ? Colors.white : Colors.grey.shade600,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        SizedBox(height: Responsive.h(16)),
                      ],

                      // Product Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CustomText.header(
                              _selectedCategoryPath.isNotEmpty
                                  ? (_storeCategories.cast<Map<String, dynamic>?>().firstWhere(
                                      (c) => c?['categoryId'] == _selectedCategoryPath.last,
                                      orElse: () => null,
                                    )?['name'] ?? 'Products')
                                  : (_selectedMainCategoryId.isNotEmpty
                                      ? (_storeCategories.cast<Map<String, dynamic>?>().firstWhere(
                                          (c) => c?['categoryId'] == _selectedMainCategoryId,
                                          orElse: () => null,
                                        )?['name'] ?? 'Products')
                                      : 'All Items'),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          GestureDetector(
                            onTap: () async {
                              if (_isNavigating) return;
                              _isNavigating = true;
                              await Navigator.of(context).pushNamed(
                                RouteConstants.allProducts,
                                arguments: {
                                  'title': 'All Items',
                                  'products': allProducts,
                                  'storeType': widget.storeType,
                                  'categories': mainCategoryItems,
                                  'storeCategories': _storeCategories,
                                  'initialMainCategoryId': _selectedMainCategoryId,
                                  'initialSubCategoryId': _selectedSubCategoryId,
                                  'initialChildCategoryId': _selectedChildCategoryId,
                                  'initialSubChildCategoryId': _selectedSubChildCategoryId,
                                },
                              );
                              if (mounted) _isNavigating = false;
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
                  onTap: () async {
                    if (_isNavigating) return;
                    _isNavigating = true;
                    await Navigator.of(context).pushNamed(
                      RouteConstants.cart,
                      arguments: widget.storeType,
                    );
                    if (mounted) _isNavigating = false;
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
          // 1. Product Visual & Details (Base layer)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  if (_isNavigating) return;
                  _isNavigating = true;
                  await Navigator.of(context).pushNamed(
                    RouteConstants.productDetails,
                    arguments: {
                      'product': product,
                      'storeType': widget.storeType,
                    },
                  );
                  if (mounted) _isNavigating = false;
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: Responsive.h(16)),
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

          // 2. Stock Badge & Heart Icon (Foreground layer - always rendered on top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
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
                  const SizedBox.shrink(),

                // Favorite toggle
                CommonWishlistButton(product: product),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
