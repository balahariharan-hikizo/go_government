class DeliveryOrderItem {
  final String productId;
  final String variantId;
  final String title;
  final double price;
  final int quantity;
  final String unit;
  final String image;

  DeliveryOrderItem({
    required this.productId,
    this.variantId = '',
    required this.title,
    required this.price,
    required this.quantity,
    this.unit = '1 Units',
    this.image = '',
  });

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderItem(
      productId: json['productId']?.toString() ?? '',
      variantId: json['variantId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Item',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unit: json['unit']?.toString() ?? '1 Units',
      image: json['image']?.toString() ?? '',
    );
  }
}

class DeliveryOrder {
  final String orderId;
  final String userId;
  final String storeId;
  final List<DeliveryOrderItem> items;
  final double itemTotal;
  final double deliveryCharge;
  final double grandTotal;
  final String paymentMethod;
  final String paymentStatus;
  
  // Customer info & dropoff
  final String dropAddress;
  final double dropLat;
  final double dropLng;
  final String receiverName;
  final String receiverPhone;

  // Store info & pickup
  final String storeName;
  final String storeAddress;
  final double storeLat;
  final double storeLng;
  final String storePhone;

  final String status;
  final String riderId;
  final DateTime? createdAt;

  DeliveryOrder({
    required this.orderId,
    required this.userId,
    required this.storeId,
    required this.items,
    required this.itemTotal,
    required this.deliveryCharge,
    required this.grandTotal,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.dropAddress,
    required this.dropLat,
    required this.dropLng,
    required this.receiverName,
    required this.receiverPhone,
    required this.storeName,
    required this.storeAddress,
    required this.storeLat,
    required this.storeLng,
    required this.storePhone,
    required this.status,
    required this.riderId,
    this.createdAt,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    final itemsList = rawItems.map((i) => DeliveryOrderItem.fromJson(Map<String, dynamic>.from(i))).toList();

    final deliveryAddr = json['deliveryAddress'] as Map? ?? {};
    final storeDet = json['storeDetails'] as Map? ?? {};
    final agent = json['deliveryAgent'] as Map? ?? {};

    return DeliveryOrder(
      orderId: json['orderId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      storeId: json['storeId']?.toString() ?? '',
      items: itemsList,
      itemTotal: (json['itemTotal'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 30.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'Cash on Delivery',
      paymentStatus: json['paymentStatus']?.toString() ?? 'paid',
      
      dropAddress: deliveryAddr['address']?.toString() ?? 'Drop location',
      dropLat: (deliveryAddr['latitude'] as num?)?.toDouble() ?? 12.9716,
      dropLng: (deliveryAddr['longitude'] as num?)?.toDouble() ?? 77.5946,
      receiverName: deliveryAddr['receiverName']?.toString() ?? 'Customer',
      receiverPhone: deliveryAddr['receiverPhone']?.toString() ?? '',

      storeName: storeDet['name']?.toString() ?? 'Government Store',
      storeAddress: storeDet['address']?.toString() ?? 'Store Location',
      storeLat: (storeDet['latitude'] as num?)?.toDouble() ?? 12.9716,
      storeLng: (storeDet['longitude'] as num?)?.toDouble() ?? 77.5946,
      storePhone: storeDet['phone']?.toString() ?? '',

      status: json['status']?.toString() ?? 'placed',
      riderId: agent['riderId']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  // Hybrid model: Guaranteed base ₹40 or customer deliveryCharge if higher
  double get estimatedPayout => deliveryCharge > 40.0 ? deliveryCharge : 40.0;

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'userId': userId,
      'storeId': storeId,
      'itemTotal': itemTotal,
      'deliveryCharge': deliveryCharge,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'status': status,
      'deliveryAddress': {
        'address': dropAddress,
        'latitude': dropLat,
        'longitude': dropLng,
        'receiverName': receiverName,
        'receiverPhone': receiverPhone,
      },
      'storeDetails': {
        'name': storeName,
        'address': storeAddress,
        'latitude': storeLat,
        'longitude': storeLng,
        'phone': storePhone,
      },
      'deliveryAgent': {
        'riderId': riderId,
      },
      'countdownSecs': 30,
    };
  }
}
