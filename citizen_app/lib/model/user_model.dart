class UserModel {
  final String name;
  final String email;
  final String phone;
  final bool isLoggedIn;

  UserModel({
    required this.name,
    required this.email,
    required this.phone,
    this.isLoggedIn = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'isLoggedIn': isLoggedIn,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      isLoggedIn: map['isLoggedIn'] as bool? ?? false,
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    bool? isLoggedIn,
  }) {
    return UserModel(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}
