abstract class AuthEvent {}

class SendOtpEvent extends AuthEvent {
  final String phone;
  SendOtpEvent(this.phone);
}

class VerifyOtpEvent extends AuthEvent {
  final String phone;
  final String otp;
  VerifyOtpEvent(this.phone, this.otp);
}

class LogoutEvent extends AuthEvent {}
