class CategoryModel {
  final String categoryId;
  final String storeId;
  final String name;
  final String description;
  final String icon;
  final String image;
  final int displayOrder;
  final bool isActive;
  final int productCount;
  final DateTime? createdAt;

  CategoryModel({
    required this.categoryId,
    required this.storeId,
    required this.name,
    this.description = '',
    this.icon = '',
    this.image = '',
    this.displayOrder = 0,
    this.isActive = true,
    this.productCount = 0,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<dynamic, dynamic> json) {
    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    return CategoryModel(
      categoryId: json['categoryId']?.toString() ?? '',
      storeId: json['storeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      displayOrder: parseInt(json['displayOrder'], 0),
      isActive: json['isActive'] != false,
      productCount: parseInt(json['productCount'], 0),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'storeId': storeId,
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
    String? name,
    String? description,
    String? icon,
    String? image,
    int? displayOrder,
    bool? isActive,
    int? productCount,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      image: image ?? this.image,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
