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

  factory ProductVariant.fromMap(Map<dynamic, dynamic> map) {
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
      variantId: map['variantId']?.toString() ?? '',
      unit: map['unit']?.toString() ?? '1 Units',
      price: parseDouble(map['price'], 0.0),
      originalPrice: parseDouble(map['originalPrice'], 0.0),
      discountPercentage: map['discountPercentage']?.toString() ?? '',
      stock: parseInt(map['stock'], 10),
      isAvailable: map['isAvailable'] == true || map['isAvailable'] == 'true' || map['isAvailable'] == null,
      image: map['image']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
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
  final String id;
  final String title;
  final String price;
  final String originalPrice;
  final String image;
  final List<String> images;
  final bool hasVariants;
  final List<ProductVariant> variants;
  final String unit;
  final double rating;
  final int reviewsCount;
  final String category;
  final String? discount;
  final String description;
  final int stock;

  ProductModel({
    required this.id,
    required this.title,
    required this.price,
    this.originalPrice = '',
    required this.image,
    this.images = const [],
    this.hasVariants = false,
    this.variants = const [],
    this.unit = '1 kg',
    this.rating = 4.5,
    this.reviewsCount = 0,
    this.category = '',
    this.discount,
    this.description = '',
    this.stock = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'originalPrice': originalPrice,
      'image': image,
      'images': images,
      'hasVariants': hasVariants,
      'variants': variants.map((v) => v.toMap()).toList(),
      'unit': unit,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'category': category,
      'discount': discount,
      'description': description,
      'stock': stock,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedImages = [];
    if (map['images'] is List) {
      parsedImages = (map['images'] as List)
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final primaryImg = map['image']?.toString() ?? '';
    if (parsedImages.isEmpty && primaryImg.isNotEmpty) {
      parsedImages = [primaryImg];
    }

    List<ProductVariant> parsedVariants = [];
    if (map['variants'] is List) {
      parsedVariants = (map['variants'] as List)
          .map((v) => ProductVariant.fromMap(v is Map ? v : {}))
          .toList();
    }

    return ProductModel(
      id: map['id']?.toString() ?? map['productId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      price: map['price']?.toString() ?? '',
      originalPrice: map['originalPrice']?.toString() ?? '',
      image: primaryImg.isNotEmpty ? primaryImg : (parsedImages.isNotEmpty ? parsedImages[0] : ''),
      images: parsedImages,
      hasVariants: map['hasVariants'] == true || parsedVariants.isNotEmpty,
      variants: parsedVariants,
      unit: map['unit']?.toString() ?? (parsedVariants.isNotEmpty ? parsedVariants[0].unit : '1 kg'),
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      reviewsCount: (map['reviewsCount'] as num?)?.toInt() ?? 0,
      category: map['category']?.toString() ?? '',
      discount: map['discount']?.toString() ?? map['discountPercentage']?.toString(),
      description: map['description']?.toString() ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 5,
    );
  }
}
