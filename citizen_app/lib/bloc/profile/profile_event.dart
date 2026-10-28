abstract class ProfileEvent {}

class UpdateProfileEvent extends ProfileEvent {
  final String name;
  final String email;
  final String? imagePath;
  UpdateProfileEvent(this.name, this.email, [this.imagePath]);
}

class UpdatePhoneEvent extends ProfileEvent {
  final String phone;
  UpdatePhoneEvent(this.phone);
}

class UpdateProfileImageEvent extends ProfileEvent {
  final String imagePath;
  UpdateProfileImageEvent(this.imagePath);
}

class ReloadProfileEvent extends ProfileEvent {}

class FetchProfileEvent extends ProfileEvent {
  final String? userId;
  FetchProfileEvent([this.userId]);
}

