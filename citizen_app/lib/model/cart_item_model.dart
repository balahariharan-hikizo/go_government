class CartItemModel {
  final String productId;
  final int quantity;
  final Map<String, dynamic> details;

  CartItemModel({
    required this.productId,
    required this.quantity,
    this.details = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'quantity': quantity,
      'details': details,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      productId: map['productId']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      details: map['details'] != null
          ? Map<String, dynamic>.from(map['details'] as Map)
          : {},
    );
  }
}
