abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class OtpSent extends AuthState {
  final String phone;
  OtpSent(this.phone);
}

class AuthSuccess extends AuthState {
  final bool isNewUser;
  AuthSuccess({this.isNewUser = false});
}

class AuthFailure extends AuthState {
  final String error;
  AuthFailure(this.error);
}
