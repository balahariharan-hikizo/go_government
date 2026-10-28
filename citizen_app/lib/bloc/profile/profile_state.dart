import '../../hive/hive_service.dart';

class ProfileState {
  final String name;
  final String email;
  final String phone;
  final String imagePath;

  ProfileState({
    required this.name,
    required this.email,
    required this.phone,
    this.imagePath = '',
  });

  factory ProfileState.initial() {
    final storedName = HiveService.userName;
    final storedEmail = HiveService.userEmail;
    final storedPhone = HiveService.userPhone;
    final storedImage = HiveService.userProfileImage;

    return ProfileState(
      name: storedName,
      email: storedEmail,
      phone: storedPhone,
      imagePath: storedImage,
    );
  }

  ProfileState copyWith({
    String? name,
    String? email,
    String? phone,
    String? imagePath,
  }) {
    return ProfileState(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
