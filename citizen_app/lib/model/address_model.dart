class AddressModel {
  String? id;
  String type;
  String description;
  String phone;
  String? name;
  String? floor;
  String? landmark;
  String? imagePath;
  bool isDefault;
  double? latitude;
  double? longitude;

  AddressModel({
    this.id,
    required this.type,
    required this.description,
    required this.phone,
    this.name,
    this.floor,
    this.landmark,
    this.imagePath,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'description': description,
      'phone': phone,
      'name': name,
      'floor': floor,
      'landmark': landmark,
      'imagePath': imagePath,
      'isDefault': isDefault,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: (map['id'] ?? map['addressId'] ?? map['_id'])?.toString(),
      type: map['type']?.toString() ?? 'Home',
      description: map['description']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      name: map['name']?.toString(),
      floor: map['floor']?.toString(),
      landmark: map['landmark']?.toString(),
      imagePath: map['imagePath']?.toString(),
      isDefault: map['isDefault'] == true,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
    );
  }
}
