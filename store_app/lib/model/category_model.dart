class CategoryModel {
  final String categoryId;
  final String storeId;
  final String parentCategoryId;
  final int level;
  final List<String> ancestors;
  final String name;
  final String description;
  final String icon;
  final String image;
  final int displayOrder;
  final bool isActive;
  final int productCount;
  final int subCategoryCount;
  final bool hasChildren;
  final DateTime? createdAt;

  CategoryModel({
    required this.categoryId,
    required this.storeId,
    this.parentCategoryId = '',
    this.level = 0,
    this.ancestors = const [],
    required this.name,
    this.description = '',
    this.icon = '',
    this.image = '',
    this.displayOrder = 0,
    this.isActive = true,
    this.productCount = 0,
    this.subCategoryCount = 0,
    this.hasChildren = false,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<dynamic, dynamic> json) {
    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    final rawAncestors = json['ancestors'];
    final List<String> parsedAncestors = rawAncestors is List
        ? rawAncestors.map((e) => e.toString()).toList()
        : const [];

    return CategoryModel(
      categoryId: json['categoryId']?.toString() ?? '',
      storeId: json['storeId']?.toString() ?? '',
      parentCategoryId: json['parentCategoryId']?.toString() ?? '',
      level: parseInt(json['level'], 0),
      ancestors: parsedAncestors,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      displayOrder: parseInt(json['displayOrder'], 0),
      isActive: json['isActive'] != false,
      productCount: parseInt(json['productCount'], 0),
      subCategoryCount: parseInt(json['subCategoryCount'], 0),
      hasChildren: json['hasChildren'] == true || parseInt(json['subCategoryCount'], 0) > 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'storeId': storeId,
      'parentCategoryId': parentCategoryId,
      'level': level,
      'ancestors': ancestors,
      'name': name,
      'description': description,
      'icon': icon,
      'image': image,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };
  }

  CategoryModel copyWith({
    String? categoryId,
    String? storeId,
    String? parentCategoryId,
    int? level,
    List<String>? ancestors,
    String? name,
    String? description,
    String? icon,
    String? image,
    int? displayOrder,
    bool? isActive,
    int? productCount,
    int? subCategoryCount,
    bool? hasChildren,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId,
      storeId: storeId ?? this.storeId,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      level: level ?? this.level,
      ancestors: ancestors ?? this.ancestors,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      image: image ?? this.image,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      productCount: productCount ?? this.productCount,
      subCategoryCount: subCategoryCount ?? this.subCategoryCount,
      hasChildren: hasChildren ?? this.hasChildren,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
