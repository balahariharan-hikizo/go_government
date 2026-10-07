class ProductVariant {
  final String variantId;
  final String unit;
  final double price;
  final double originalPrice;
  final String discountPercentage;
  final int stock;
  final bool isAvailable;
  final String image;

  ProductVariant({
    required this.variantId,
    required this.unit,
    required this.price,
    this.originalPrice = 0.0,
    this.discountPercentage = '',
    this.stock = 10,
    this.isAvailable = true,
    this.image = '',
  });

  factory ProductVariant.fromJson(Map<dynamic, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    return ProductVariant(
      variantId: json['variantId']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '1 Units',
      price: parseDouble(json['price'], 0.0),
      originalPrice: parseDouble(json['originalPrice'], 0.0),
      discountPercentage: json['discountPercentage']?.toString() ?? '',
      stock: parseInt(json['stock'], 10),
      isAvailable: json['isAvailable'] == true || json['isAvailable'] == 'true' || json['isAvailable'] == null,
      image: json['image']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variantId': variantId,
      'unit': unit,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercentage': discountPercentage,
      'stock': stock,
      'isAvailable': isAvailable,
      'image': image,
    };
  }
}

class ProductModel {
  final String productId;
  final String storeId;
  final String title;
  final String category;
  final String unit;
  final double price;
  final double originalPrice;
  final String discountPercentage;
  final int stock;
  final bool isAvailable;
  final String image;
  final List<String> images;
  final bool hasVariants;
  final List<ProductVariant> variants;
  final String description;

  // Citizen App Highlights & Specs
  final String brand;
  final String packOf;
  final String type;
  final String shelfLife;
  final String formFactor;
  final String origin;

  // Government Subsidized / Ration Fields
  final bool isSubsidized;
  final String subsidyLimit;

  ProductModel({
    this.productId = '',
    required this.storeId,
    required this.title,
    this.category = 'general',
    this.unit = '1 Units',
    required this.price,
    this.originalPrice = 0.0,
    this.discountPercentage = '',
    this.stock = 10,
    this.isAvailable = true,
    this.image = '',
    this.images = const [],
    this.hasVariants = false,
    this.variants = const [],
    this.description = '',
    this.brand = 'Unbranded',
    this.packOf = '1',
    this.type = '',
    this.shelfLife = '7 Days',
    this.formFactor = 'Whole',
    this.origin = 'India',
    this.isSubsidized = false,
    this.subsidyLimit = '',
  });

  String get stockBadge {
    if (!isAvailable || stock <= 0) return 'Out of Stock';
    if (stock <= 3) return 'Only $stock left';
    return 'In Stock';
  }

  factory ProductModel.fromJson(Map<dynamic, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    // Parse images array with fallback to primary image
    List<String> parsedImages = [];
    if (json['images'] is List) {
      parsedImages = (json['images'] as List)
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final primaryImg = json['image']?.toString() ?? '';
    if (parsedImages.isEmpty && primaryImg.isNotEmpty) {
      parsedImages = [primaryImg];
    }

    // Parse variants list
    List<ProductVariant> parsedVariants = [];
    if (json['variants'] is List) {
      parsedVariants = (json['variants'] as List)
          .map((v) => ProductVariant.fromJson(v is Map ? v : {}))
          .toList();
    }

    final hasVars = json['hasVariants'] == true || parsedVariants.isNotEmpty;

    return ProductModel(
      productId: json['productId']?.toString() ?? json['id']?.toString() ?? '',
      storeId: json['storeId']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      unit: json['unit']?.toString() ?? (parsedVariants.isNotEmpty ? parsedVariants[0].unit : '1 Units'),
      price: parseDouble(json['price'], 0.0),
      originalPrice: parseDouble(json['originalPrice'], 0.0),
      discountPercentage: json['discountPercentage']?.toString() ?? '',
      stock: parseInt(json['stock'], 10),
      isAvailable: json['isAvailable'] == true || json['isAvailable'] == 'true' || json['isAvailable'] == null,
      image: primaryImg.isNotEmpty ? primaryImg : (parsedImages.isNotEmpty ? parsedImages[0] : ''),
      images: parsedImages,
      hasVariants: hasVars,
      variants: parsedVariants,
      description: json['description']?.toString() ?? '',
      brand: json['brand']?.toString() ?? 'Unbranded',
      packOf: json['packOf']?.toString() ?? '1',
      type: json['type']?.toString() ?? '',
      shelfLife: json['shelfLife']?.toString() ?? '7 Days',
      formFactor: json['formFactor']?.toString() ?? 'Whole',
      origin: json['origin']?.toString() ?? 'India',
      isSubsidized: json['isSubsidized'] == true || json['isSubsidized'] == 'true',
      subsidyLimit: json['subsidyLimit']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'storeId': storeId,
      'title': title,
      'category': category,
      'unit': unit,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercentage': discountPercentage,
      'stock': stock,
      'isAvailable': isAvailable,
      'image': image.isNotEmpty ? image : (images.isNotEmpty ? images[0] : ''),
      'images': images,
      'hasVariants': hasVariants,
      'variants': variants.map((v) => v.toJson()).toList(),
      'description': description,
      'brand': brand,
      'packOf': packOf,
      'type': type,
      'shelfLife': shelfLife,
      'formFactor': formFactor,
      'origin': origin,
      'isSubsidized': isSubsidized,
      'subsidyLimit': subsidyLimit,
    };
  }

  ProductModel copyWith({
    String? productId,
    String? storeId,
    String? title,
    String? category,
    String? unit,
    double? price,
    double? originalPrice,
    String? discountPercentage,
    int? stock,
    bool? isAvailable,
    String? image,
    List<String>? images,
    bool? hasVariants,
    List<ProductVariant>? variants,
    String? description,
    String? brand,
    String? packOf,
    String? type,
    String? shelfLife,
    String? formFactor,
    String? origin,
    bool? isSubsidized,
    String? subsidyLimit,
  }) {
    return ProductModel(
      productId: productId ?? this.productId,
      storeId: storeId ?? this.storeId,
      title: title ?? this.title,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      image: image ?? this.image,
      images: images ?? this.images,
      hasVariants: hasVariants ?? this.hasVariants,
      variants: variants ?? this.variants,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      packOf: packOf ?? this.packOf,
      type: type ?? this.type,
      shelfLife: shelfLife ?? this.shelfLife,
      formFactor: formFactor ?? this.formFactor,
      origin: origin ?? this.origin,
      isSubsidized: isSubsidized ?? this.isSubsidized,
      subsidyLimit: subsidyLimit ?? this.subsidyLimit,
    );
  }
}
