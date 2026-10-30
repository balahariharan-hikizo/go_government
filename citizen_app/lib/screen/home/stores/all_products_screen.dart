import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../widget/common_cart_badge.dart';
import '../../../constants/route_constants.dart';
import '../../../service/cart_manager.dart';
import '../../../widget/common_wishlist_button.dart';
import '../../../network/api_client.dart';

class AllProductsScreen extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> products;
  final String storeType;
  final List<Map<String, dynamic>>? categories;
  final List<Map<String, dynamic>>? storeCategories;
  final String? initialMainCategoryId;
  final String? initialSubCategoryId;
  final String? initialChildCategoryId;
  final String? initialSubChildCategoryId;

  const AllProductsScreen({
    super.key,
    required this.title,
    required this.products,
    required this.storeType,
    this.categories,
    this.storeCategories,
    this.initialMainCategoryId,
    this.initialSubCategoryId,
    this.initialChildCategoryId,
    this.initialSubChildCategoryId,
  });

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen> {
  String _searchQuery = '';
  String _selectedMainCategoryId = ''; // '' means All
  List<String> _selectedCategoryPath = []; // Path of subcategory IDs [level1, level2, level3, ... infinite]

  late final ValueNotifier<String> _activeCategoryNotifier;
  final ScrollController _leftRailController = ScrollController();
  final ScrollController _productsScrollController = ScrollController();
  final GlobalKey _scrollableKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _railItemKeys = {};
  bool _isProgrammaticScroll = false;

  String get _selectedSubCategoryId =>
      _selectedCategoryPath.isNotEmpty ? _selectedCategoryPath[0] : '';

  late final VoidCallback _cartListener;
  late final VoidCallback _favListener;

  @override
  void initState() {
    super.initState();
    _selectedMainCategoryId = widget.initialMainCategoryId ?? '';
    _activeCategoryNotifier = ValueNotifier<String>(_selectedMainCategoryId);
    _selectedCategoryPath = [];
    if (widget.initialSubCategoryId != null && widget.initialSubCategoryId!.isNotEmpty) {
      _selectedCategoryPath.add(widget.initialSubCategoryId!);
      if (widget.initialChildCategoryId != null && widget.initialChildCategoryId!.isNotEmpty) {
        _selectedCategoryPath.add(widget.initialChildCategoryId!);
        if (widget.initialSubChildCategoryId != null && widget.initialSubChildCategoryId!.isNotEmpty) {
          _selectedCategoryPath.add(widget.initialSubChildCategoryId!);
        }
      }
    }

    _productsScrollController.addListener(_onProductsScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedMainCategoryId.isNotEmpty && _selectedCategoryPath.isEmpty) {
        _onCategoryRailTap(_selectedMainCategoryId);
      }
    });

    _cartListener = () {
      if (mounted) setState(() {});
    };
    _favListener = () {
      if (mounted) setState(() {});
    };
    CartManager.instance.cartItems.addListener(_cartListener);
    WishlistManager.instance.favoriteIds.addListener(_favListener);
  }

  @override
  void dispose() {
    _productsScrollController.removeListener(_onProductsScroll);
    _productsScrollController.dispose();
    _leftRailController.dispose();
    _activeCategoryNotifier.dispose();
    CartManager.instance.cartItems.removeListener(_cartListener);
    WishlistManager.instance.favoriteIds.removeListener(_favListener);
    super.dispose();
  }

  Map<String, double> _categoryOffsets = {};

  void _onCategoryRailTap(String catId) {
    _isProgrammaticScroll = true;
    _activeCategoryNotifier.value = catId;
    _selectedMainCategoryId = catId;
    _autoScrollLeftRail(catId);

    if (_selectedCategoryPath.isNotEmpty) {
      setState(() {
        _selectedCategoryPath = [];
      });
    }

    final double targetOffset = _categoryOffsets[catId] ?? 0.0;
    if (_productsScrollController.hasClients) {
      _productsScrollController.animateTo(
        targetOffset.clamp(0.0, _productsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      ).then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _isProgrammaticScroll = false;
        });
      });
    } else {
      _isProgrammaticScroll = false;
    }
  }

  void _autoScrollLeftRail(String catId) {
    final catKey = catId.isNotEmpty ? catId : 'All';
    final key = _railItemKeys[catKey] ?? _railItemKeys[catId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  void _onProductsScroll() {
    if (_isProgrammaticScroll) return;
    if (_selectedCategoryPath.isNotEmpty || _searchQuery.isNotEmpty) return;
    if (!_productsScrollController.hasClients) return;

    final double offset = _productsScrollController.offset;
    String activeId = '';

    for (final entry in _categoryOffsets.entries) {
      if (entry.key.isEmpty) continue;
      if (offset >= entry.value - 60) {
        activeId = entry.key;
      }
    }

    if (offset < 40 && _categoryOffsets.isNotEmpty) {
      activeId = _categoryOffsets.keys.firstWhere((k) => k.isNotEmpty, orElse: () => '');
    }

    if (activeId.isNotEmpty && activeId != _activeCategoryNotifier.value) {
      _activeCategoryNotifier.value = activeId;
      _selectedMainCategoryId = activeId;
      _autoScrollLeftRail(activeId);
    }
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
    final int totalCartCount = CartManager.instance.totalCartCount;

    final allStoreCats = widget.storeCategories ?? widget.categories ?? [];

    // 1. Root / Main Categories (parentCategoryId is empty or null, level == 0)
    final rootCats = allStoreCats.where((c) {
      final pid = (c['parentCategoryId'] ?? '').toString().trim();
      final lvl = c['level'] is num ? (c['level'] as num).toInt() : 0;
      return pid.isEmpty || lvl == 0;
    }).toList();

    // Main category rail items: starts with 'All'
    final List<Map<String, dynamic>> mainCategoryItems = [
      {'categoryId': '', 'name': 'All', 'icon': '🛍️', 'productCount': widget.products.length}
    ];

    if (rootCats.isNotEmpty) {
      for (final cat in rootCats) {
        final name = (cat['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          mainCategoryItems.add({
            'categoryId': cat['categoryId']?.toString() ?? '',
            'name': name,
            'icon': (cat['icon'] != null && cat['icon'].toString().isNotEmpty) ? cat['icon'].toString() : '🏷️',
            'productCount': cat['productCount'] ?? 0,
          });
        }
      }
    } else {
      // Fallback: extract distinct category names from products if no storeCategories configured
      final Set<String> seen = {};
      for (final p in widget.products) {
        final cat = p['category']?.toString().trim() ?? '';
        if (cat.isNotEmpty && !seen.contains(cat.toLowerCase())) {
          seen.add(cat.toLowerCase());
          mainCategoryItems.add({'categoryId': '', 'name': cat, 'icon': '🏷️', 'productCount': 0});
        }
      }
    }

    // 2. Sub-categories under the currently selected main category (Level 1)
    final List<Map<String, dynamic>> subCategoryItems = [];
    if (_selectedMainCategoryId.isNotEmpty) {
      final subCats = allStoreCats.where((c) {
        final pid = (c['parentCategoryId'] ?? '').toString().trim();
        return pid == _selectedMainCategoryId;
      }).toList();

      if (subCats.isNotEmpty) {
        final selectedMain = allStoreCats.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['categoryId'] == _selectedMainCategoryId,
          orElse: () => null,
        );
        final mainName = selectedMain?['name'] ?? 'All';
        subCategoryItems.add({
          'categoryId': '',
          'name': 'All $mainName',
          'hasChildren': false,
        });
        for (final sub in subCats) {
          final subName = (sub['name'] ?? '').toString().trim();
          final subId = sub['categoryId']?.toString() ?? '';
          if (subName.isNotEmpty) {
            final hasChildren = allStoreCats.any((c) => (c['parentCategoryId'] ?? '').toString().trim() == subId);
            subCategoryItems.add({
              'categoryId': subId,
              'name': subName,
              'hasChildren': hasChildren,
            });
          }
        }
      }
    }

    // 3. Nested Child Categories under the currently selected sub-category (Level 2)
    final List<Map<String, dynamic>> childCategoryItems = [];
    if (_selectedSubCategoryId.isNotEmpty) {
      final childCats = allStoreCats.where((c) {
        final pid = (c['parentCategoryId'] ?? '').toString().trim();
        return pid == _selectedSubCategoryId;
      }).toList();

      if (childCats.isNotEmpty) {
        final selectedSub = allStoreCats.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['categoryId'] == _selectedSubCategoryId,
          orElse: () => null,
        );
        final subName = selectedSub?['name'] ?? 'All';
        childCategoryItems.add({
          'categoryId': '',
          'name': 'All $subName',
          'hasChildren': false,
        });
        for (final child in childCats) {
          final childName = (child['name'] ?? '').toString().trim();
          final childId = child['categoryId']?.toString() ?? '';
          if (childName.isNotEmpty) {
            final hasChildren = allStoreCats.any((c) => (c['parentCategoryId'] ?? '').toString().trim() == childId);
            childCategoryItems.add({
              'categoryId': childId,
              'name': childName,
              'hasChildren': hasChildren,
            });
          }
        }
      }
    }

    // 3. Dynamic Deeper Categories (Level 3, Level 4, Level 5... Infinite Depth!)
    final List<Map<String, dynamic>> deeperCategoryItems = [];
    bool showDeeperBackChip = false;
    String backTargetName = '';
    String activeDeeperParentId = '';

    if (_selectedCategoryPath.length >= 2) {
      final lastId = _selectedCategoryPath.last;
      final directChildrenOfLast = allStoreCats.where((c) {
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
        final deeperCats = allStoreCats.where((c) {
          final pid = (c['parentCategoryId'] ?? '').toString().trim();
          return pid == activeDeeperParentId;
        }).toList();

        if (deeperCats.isNotEmpty) {
          // Show back chip ONLY if we drilled down deeper than Level 3 (Level 4+)
          final parentIdx = _selectedCategoryPath.indexOf(activeDeeperParentId);
          if (parentIdx > 1) {
            showDeeperBackChip = true;
            final prevCatId = _selectedCategoryPath[parentIdx - 1];
            final prevCat = allStoreCats.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c?['categoryId'] == prevCatId,
              orElse: () => null,
            );
            backTargetName = prevCat?['name'] ?? 'Back';
          }

          final parentCat = allStoreCats.cast<Map<String, dynamic>?>().firstWhere(
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
            final scName = (sc['name'] ?? '').toString().trim();
            final scId = sc['categoryId']?.toString() ?? '';
            if (scName.isNotEmpty) {
              final hasChildren = allStoreCats.any((c) => (c['parentCategoryId'] ?? '').toString().trim() == scId);
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

    // 4. Target Category for Multi-level Product Filtering (Infinite depth target)
    final String targetCatId = _selectedCategoryPath.isNotEmpty
        ? _selectedCategoryPath.last
        : _selectedMainCategoryId;

    final Set<String> targetIds = targetCatId.isNotEmpty
        ? _getDescendantIds(targetCatId, allStoreCats)
        : const {};
    final Set<String> targetNames = targetCatId.isNotEmpty
        ? _getDescendantNames(targetCatId, allStoreCats)
        : const {};

    // 5. Multi-level Filtered Products
    final filteredProducts = widget.products.where((p) {
      final name = p['title'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty || name.contains(query);
      if (!matchesSearch) return false;

      // If 'All' is selected overall
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
          child: Column(
            children: [
              // Top Bar & Search Input
              _buildTopBar(context),

              // Blinkit / Zepto Split-View Layout
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Left Vertical Main Category Rail
                    _buildLeftCategoryRail(mainCategoryItems),

                    // 2. Right Products Section
                    Expanded(
                      child: Container(
                        key: _scrollableKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Smooth Animated Size for Chips to prevent layout jumping
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (subCategoryItems.isNotEmpty)
                                    _buildSubCategoryChips(subCategoryItems),
                                  if (childCategoryItems.isNotEmpty)
                                    _buildChildCategoryChips(childCategoryItems),
                                  if (deeperCategoryItems.isNotEmpty)
                                    _buildDeeperCategoryChips(
                                      deeperCategoryItems,
                                      showBackChip: showDeeperBackChip,
                                      backTargetName: backTargetName,
                                      activeParentId: activeDeeperParentId,
                                    ),
                                ],
                              ),
                            ),

                            // Product Stream (Continuous Grouped Scroll or Filtered Grid)
                            Expanded(
                              child: _buildProductStream(
                                allStoreCats: allStoreCats,
                                mainCategoryItems: mainCategoryItems,
                                filteredProducts: filteredProducts,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: CommonCartBadge(
        itemCount: totalCartCount,
        onTap: () {
          Navigator.of(context).pushNamed(
            RouteConstants.cart,
            arguments: widget.storeType,
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.w(16),
        Responsive.h(6),
        Responsive.w(16),
        Responsive.h(10),
      ),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: Responsive.w(38),
                  height: Responsive.w(38),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black87),
                ),
              ),
              SizedBox(width: Responsive.w(12)),
              Expanded(
                child: CustomText.header(
                  widget.title,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(8)),
          Container(
            height: Responsive.h(40),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(Responsive.w(12)),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey, size: 18),
                SizedBox(width: Responsive.w(8)),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search items in catalog...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: const Icon(Icons.cancel, color: Colors.grey, size: 16),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftCategoryRail(List<Map<String, dynamic>> items) {
    return Container(
      width: Responsive.w(82),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: ValueListenableBuilder<String>(
        valueListenable: _activeCategoryNotifier,
        builder: (context, activeCatId, _) {
          return ListView.builder(
            controller: _leftRailController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(vertical: Responsive.h(6)),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final catId = item['categoryId'] as String;
              final catName = item['name'] as String;
              final icon = item['icon'] as String? ?? '🏷️';
              final isSelected = activeCatId == catId;
              final catKey = catId.isNotEmpty ? catId : 'All';

              return GestureDetector(
                key: _railItemKeys.putIfAbsent(catKey, () => GlobalKey()),
                onTap: () => _onCategoryRailTap(catId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.symmetric(
                    horizontal: Responsive.w(isSelected ? 3 : 5),
                    vertical: Responsive.h(isSelected ? 4 : 3),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(isSelected ? 6 : 5),
                    vertical: Responsive.h(isSelected ? 10 : 7),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (isSelected)
                        Positioned(
                          left: -Responsive.w(6),
                          top: Responsive.h(6),
                          bottom: Responsive.h(6),
                          child: Container(
                            width: Responsive.w(3.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: Responsive.w(isSelected ? 44 : 35),
                            height: Responsive.w(isSelected ? 44 : 35),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              icon,
                              style: TextStyle(
                                fontSize: Responsive.sp(isSelected ? 21 : 17),
                              ),
                            ),
                          ),
                          SizedBox(height: Responsive.h(isSelected ? 5 : 4)),
                          Text(
                            catName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.sp(isSelected ? 11 : 9.5),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primary : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getProductsForCategory(
    String catId,
    String catName,
    List<Map<String, dynamic>> allCats,
  ) {
    if (catId.isNotEmpty) {
      final targetIds = _getDescendantIds(catId, allCats);
      final targetNames = _getDescendantNames(catId, allCats);

      return widget.products.where((p) {
        final name = p['title'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        final matchesSearch = query.isEmpty || name.contains(query);
        if (!matchesSearch) return false;

        final pCatId = (p['categoryId'] ?? '').toString().trim();
        final pPath = p['categoryPath'] is List
            ? (p['categoryPath'] as List).map((e) => e.toString().trim()).toList()
            : <String>[];
        final pCatName = (p['category'] ?? '').toString().toLowerCase().trim();

        return targetIds.contains(pCatId) ||
            pPath.any((id) => targetIds.contains(id)) ||
            targetNames.contains(pCatName);
      }).toList();
    } else {
      final targetName = catName.toLowerCase().trim();
      return widget.products.where((p) {
        final name = p['title'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        final matchesSearch = query.isEmpty || name.contains(query);
        if (!matchesSearch) return false;

        final pCatName = (p['category'] ?? '').toString().toLowerCase().trim();
        return pCatName == targetName;
      }).toList();
    }
  }

  Widget _buildSectionHeader({
    required Key key,
    required String title,
    required String icon,
    required int count,
  }) {
    return Container(
      key: key,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(8),
        Responsive.h(12),
        Responsive.w(8),
        Responsive.h(6),
      ),
      child: Row(
        children: [
          if (icon.isNotEmpty) ...[
            Text(icon, style: TextStyle(fontSize: Responsive.sp(14))),
            SizedBox(width: Responsive.w(6)),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: Responsive.sp(13),
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(8),
              vertical: Responsive.h(2),
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(Responsive.w(10)),
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: Text(
              '$count items',
              style: TextStyle(
                fontSize: Responsive.sp(9.5),
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductStream({
    required List<Map<String, dynamic>> allStoreCats,
    required List<Map<String, dynamic>> mainCategoryItems,
    required List<Map<String, dynamic>> filteredProducts,
  }) {
    // Mode 1: Search query or drilled-down specific sub-category
    if (_searchQuery.isNotEmpty || _selectedCategoryPath.isNotEmpty) {
      if (filteredProducts.isEmpty) {
        return _buildEmptyState();
      }
      return GridView.builder(
        key: const ValueKey('filtered_grid_view'),
        controller: _productsScrollController,
        padding: EdgeInsets.fromLTRB(
          Responsive.w(8),
          Responsive.h(8),
          Responsive.w(10),
          Responsive.h(80),
        ),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: Responsive.w(8),
          mainAxisSpacing: Responsive.h(10),
          childAspectRatio: 0.65,
        ),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index];
          return _buildProductCard(product);
        },
      );
    }

    // Mode 2: Continuous Synchronized Multi-Category Scroll Stream (Blinkit / Zepto)
    final List<Widget> slivers = [];
    final Set<String> renderedProductIds = {};
    final Map<String, double> computedOffsets = {'': 0.0};
    double currentOffset = 0.0;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double railWidth = Responsive.w(82);
    final double rightWidth = screenWidth - railWidth;
    final double gridPaddingH = Responsive.w(18); // left 8 + right 10
    final double crossSpacing = Responsive.w(8);
    final double itemWidth = (rightWidth - gridPaddingH - crossSpacing) / 2;
    final double cardHeight = itemWidth / 0.65;
    final double rowHeight = cardHeight + Responsive.h(10);
    final double headerHeight = Responsive.h(44);
    final double sectionPaddingV = Responsive.h(16); // top 4 + bottom 12

    for (final cat in mainCategoryItems) {
      final catId = cat['categoryId']?.toString() ?? '';
      final catName = cat['name']?.toString() ?? '';
      final icon = cat['icon']?.toString() ?? '🏷️';
      if (catId.isEmpty && catName.toLowerCase() == 'all') continue;

      final catKey = catId.isNotEmpty ? catId : catName;
      final categoryProducts = _getProductsForCategory(catId, catName, allStoreCats);

      if (categoryProducts.isNotEmpty) {
        computedOffsets[catKey] = currentOffset;
        if (catId.isNotEmpty) computedOffsets[catId] = currentOffset;

        final int rows = (categoryProducts.length + 1) ~/ 2;
        currentOffset += headerHeight + (rows * rowHeight) + sectionPaddingV;

        for (final p in categoryProducts) {
          final pid = (p['_id'] ?? p['id'] ?? p['title']).toString();
          renderedProductIds.add(pid);
        }

        // Section Header
        slivers.add(
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              key: _sectionKeys.putIfAbsent(catKey, () => GlobalKey()),
              title: catName,
              icon: icon,
              count: categoryProducts.length,
            ),
          ),
        );

        // Section Product Grid
        slivers.add(
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Responsive.w(8),
              Responsive.h(4),
              Responsive.w(10),
              Responsive.h(12),
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: Responsive.w(8),
                mainAxisSpacing: Responsive.h(10),
                childAspectRatio: 0.65,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildProductCard(categoryProducts[index]);
                },
                childCount: categoryProducts.length,
              ),
            ),
          ),
        );
      }
    }

    // Remaining / other products
    final remainingProducts = widget.products.where((p) {
      final pid = (p['_id'] ?? p['id'] ?? p['title']).toString();
      return !renderedProductIds.contains(pid);
    }).toList();

    if (remainingProducts.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _buildSectionHeader(
            key: _sectionKeys.putIfAbsent('other', () => GlobalKey()),
            title: 'Other Products',
            icon: '📦',
            count: remainingProducts.length,
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            Responsive.w(8),
            Responsive.h(4),
            Responsive.w(10),
            Responsive.h(80),
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: Responsive.w(8),
              mainAxisSpacing: Responsive.h(10),
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildProductCard(remainingProducts[index]);
              },
              childCount: remainingProducts.length,
            ),
          ),
        ),
      );
    } else {
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(height: Responsive.h(80)),
        ),
      );
    }

    if (slivers.isEmpty) {
      return _buildEmptyState();
    }

    _categoryOffsets = computedOffsets;

    return CustomScrollView(
      key: const ValueKey('continuous_custom_scroll_view'),
      controller: _productsScrollController,
      scrollCacheExtent: const ScrollCacheExtent.viewport(5),
      physics: const BouncingScrollPhysics(),
      slivers: slivers,
    );
  }

  Widget _buildSubCategoryChips(List<Map<String, dynamic>> subItems) {
    return Container(
      height: Responsive.h(38),
      padding: EdgeInsets.symmetric(vertical: Responsive.h(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
        itemCount: subItems.length,
        separatorBuilder: (_, _) => SizedBox(width: Responsive.w(6)),
        itemBuilder: (context, idx) {
          final sub = subItems[idx];
          final subId = sub['categoryId'] as String;
          final subName = sub['name'] as String;
          final hasChildren = sub['hasChildren'] == true;
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
                horizontal: Responsive.w(10),
                vertical: Responsive.h(4),
              ),
              decoration: BoxDecoration(
                color: isSubSelected ? AppColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(Responsive.w(14)),
                border: Border.all(
                  color: isSubSelected ? AppColors.primary : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subName,
                      style: TextStyle(
                        fontSize: Responsive.sp(11),
                        fontWeight: isSubSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSubSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (hasChildren) ...[
                      SizedBox(width: Responsive.w(3)),
                      Icon(
                        Icons.arrow_drop_down,
                        size: Responsive.w(14),
                        color: isSubSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChildCategoryChips(List<Map<String, dynamic>> childItems) {
    return Container(
      height: Responsive.h(34),
      padding: EdgeInsets.symmetric(vertical: Responsive.h(3)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // subtle slate contrast for Level 2
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
        itemCount: childItems.length,
        separatorBuilder: (_, _) => SizedBox(width: Responsive.w(6)),
        itemBuilder: (context, idx) {
          final item = childItems[idx];
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
                horizontal: Responsive.w(9),
                vertical: Responsive.h(3),
              ),
              decoration: BoxDecoration(
                color: isChildSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(Responsive.w(12)),
                border: Border.all(
                  color: isChildSelected ? AppColors.primary : Colors.grey.shade300,
                  width: 0.8,
                ),
                boxShadow: isChildSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      childName,
                      style: TextStyle(
                        fontSize: Responsive.sp(10.5),
                        fontWeight: isChildSelected ? FontWeight.bold : FontWeight.w500,
                        color: isChildSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (hasChildren) ...[
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
    );
  }

  Widget _buildDeeperCategoryChips(
    List<Map<String, dynamic>> items, {
    required bool showBackChip,
    required String backTargetName,
    required String activeParentId,
  }) {
    final int extraCount = showBackChip ? 1 : 0;
    return Container(
      height: Responsive.h(32),
      padding: EdgeInsets.symmetric(vertical: Responsive.h(2.5)),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0), // distinct contrast for Deeper Levels (Level 3, 4, 5... Infinite)
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.8)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
        itemCount: items.length + extraCount,
        separatorBuilder: (_, index) => SizedBox(width: Responsive.w(6)),
        itemBuilder: (context, idx) {
          if (showBackChip && idx == 0) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  final parentIdx = _selectedCategoryPath.indexOf(activeParentId);
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
                  vertical: Responsive.h(2.5),
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(Responsive.w(10)),
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

          final item = items[showBackChip ? idx - 1 : idx];
          final scId = item['categoryId'] as String;
          final scName = item['name'] as String;
          final hasChildren = item['hasChildren'] == true;
          final isAllChip = item['isAllChip'] == true;

          final bool isSelected = isAllChip
              ? (_selectedCategoryPath.last == activeParentId)
              : (_selectedCategoryPath.contains(scId) && (_selectedCategoryPath.last == scId || !hasChildren));

          return GestureDetector(
            onTap: () {
              setState(() {
                final parentIdx = _selectedCategoryPath.indexOf(activeParentId);
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
                horizontal: Responsive.w(8),
                vertical: Responsive.h(2.5),
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(Responsive.w(10)),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  width: 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scName,
                      style: TextStyle(
                        fontSize: Responsive.sp(10),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: Responsive.w(48), color: Colors.grey.shade400),
            SizedBox(height: Responsive.h(10)),
            CustomText.title('No items found', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            SizedBox(height: Responsive.h(4)),
            Text(
              'Try changing category or search keyword',
              style: TextStyle(fontSize: Responsive.sp(12), color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
        key: ValueKey(normalized),
        gaplessPlayback: true,
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
      key: ValueKey(imagePath),
      gaplessPlayback: true,
      height: Responsive.h(90),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => buildPlaceholder(),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String id = (product['id'] ?? product['_id'] ?? product['title']).toString();
    final int qty = CartManager.instance.getQuantity(id);
    final int stock = CartManager.instance.getStock(product);
    final bool isOutOfStock = stock <= 0;
    final bool isMaxStock = qty >= stock;

    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final double origPrice = (product['originalPrice'] as num?)?.toDouble() ?? price;
    final int discount = (product['discountPercentage'] as num?)?.toInt() ?? 0;

    return Container(
      key: ValueKey('prod_$id'),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(color: AppColors.outliner, width: Responsive.w(1.2)),
      ),
      padding: EdgeInsets.all(Responsive.w(10)),
      child: Stack(
        children: [
          // 1. Main details (Base layer)
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
                    SizedBox(height: Responsive.h(16)),
                    Center(
                      child: _buildProductCardImage(product['image'], widget.storeType),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    CustomText.title(product['title'], fontSize: 12, fontWeight: FontWeight.bold, maxLines: 1),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(8),
                          ),
                          child: const Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                      Text(
                        qty.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          CartManager.instance.updateQuantity(product, qty + 1, context: context);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(8),
                          ),
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
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.primary,
                        size: 16,
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
