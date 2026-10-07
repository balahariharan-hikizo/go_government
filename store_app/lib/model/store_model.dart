import 'bank_details_model.dart';

class StoreModel {
  final String storeId;
  final String name;
  final String ownerName;
  final String phone;
  final String email;
  final String category;
  final String address;
  final String pincode;
  final double lat;
  final double lng;
  final String storeImage;
  final BankDetailsModel bankDetails;
  final String status;
  final String rejectionReason;
  final Map<String, String> timings;
  final bool isOnline;
  final double rating;

  StoreModel({
    this.storeId = '',
    this.name = '',
    this.ownerName = '',
    this.phone = '',
    this.email = '',
    this.category = 'general',
    this.address = '',
    this.pincode = '',
    this.lat = 13.0827,
    this.lng = 80.2707,
    this.storeImage = '',
    BankDetailsModel? bankDetails,
    this.status = 'pending',
    this.rejectionReason = '',
    Map<String, String>? timings,
    this.isOnline = true,
    this.rating = 4.5,
  })  : bankDetails = bankDetails ?? BankDetailsModel(),
        timings = timings ?? {'open': '08:00 AM', 'close': '08:30 PM'};

  factory StoreModel.fromJson(Map<dynamic, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    final loc = json['location'] is Map ? json['location'] as Map : null;
    final double latitude = loc != null ? parseDouble(loc['lat'], 13.0827) : parseDouble(json['lat'], 13.0827);
    final double longitude = loc != null ? parseDouble(loc['lng'], 80.2707) : parseDouble(json['lng'], 80.2707);

    final timingsMap = <String, String>{};
    if (json['timings'] != null && json['timings'] is Map) {
      timingsMap['open'] = json['timings']['open']?.toString() ?? '08:00 AM';
      timingsMap['close'] = json['timings']['close']?.toString() ?? '08:30 PM';
    } else {
      timingsMap['open'] = '08:00 AM';
      timingsMap['close'] = '08:30 PM';
    }

    final bankJson = json['bankDetails'] is Map ? json['bankDetails'] as Map : null;

    return StoreModel(
      storeId: json['storeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      address: json['address']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      lat: latitude,
      lng: longitude,
      storeImage: json['storeImage']?.toString() ?? '',
      bankDetails: BankDetailsModel.fromJson(bankJson),
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejectionReason']?.toString() ?? '',
      timings: timingsMap,
      isOnline: json['isOnline'] == true || json['isOnline'] == 'true',
      rating: parseDouble(json['rating'], 4.5),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storeId': storeId,
      'name': name,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'category': category,
      'address': address,
      'pincode': pincode,
      'lat': lat,
      'lng': lng,
      'storeImage': storeImage,
      'bankDetails': bankDetails.toJson(),
      'status': status,
      'rejectionReason': rejectionReason,
      'timings': timings,
      'isOnline': isOnline,
      'rating': rating,
    };
  }
}
