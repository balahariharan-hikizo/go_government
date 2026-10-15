import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/notification_service.dart';
import '../../service/firebase_service.dart';
import '../../hive/hive_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../network/api_service.dart';
import '../profile/profile_bloc.dart';
import '../profile/profile_event.dart';
import '../cart/cart_bloc.dart';
import '../cart/cart_event.dart';
import '../transaction/transaction_bloc.dart';
import '../transaction/transaction_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc()
      : super(
          (HiveService.isLoggedIn && HiveService.userName.trim().isNotEmpty)
              ? AuthSuccess()
              : AuthInitial(),
        ) {
    on<SendOtpEvent>((event, emit) async {
      emit(AuthLoading());
      await HiveService.setUserPhone(event.phone);

      final result = await ApiService.sendOtp(event.phone);
      if (result != null && result['success'] == true) {
        final otp = result['otp']?.toString();
        if (otp != null && otp.isNotEmpty) {
          await NotificationService.showOtpNotification(otp: otp);
        }
        emit(OtpSent(event.phone));
      } else {
        emit(AuthFailure(result?['message'] ?? 'Failed to send OTP. Please try again.'));
      }
    });

    on<VerifyOtpEvent>((event, emit) async {
      emit(AuthLoading());

      final phone = event.phone.isNotEmpty ? event.phone : HiveService.userPhone;
      final result = await ApiService.verifyOtp(phone, event.otp);

      if (result != null && result['success'] == true) {
        final userId = result['userId'] ?? result['user']?['userId'];
        if (userId != null && userId.toString().isNotEmpty) {
          await HiveService.setCitizenId(userId.toString());
        }

        final user = result['user'];
        if (user != null) {
          if (user['userName'] != null && user['userName'].toString().isNotEmpty) {
            await HiveService.setUserName(user['userName'].toString());
          }
          if (user['email'] != null && user['email'].toString().isNotEmpty) {
            await HiveService.setUserEmail(user['email'].toString());
          }
          if (user['profileImage'] != null && user['profileImage'].toString().isNotEmpty) {
            await HiveService.setUserProfileImage(user['profileImage'].toString());
          }
        }

        final bool isNewUser = result['isNewUser'] == true;
        if (!isNewUser) {
          // Returning user: already completed registration, can mark logged in immediately
          await HiveService.setLoggedIn(true);
          FirebaseService.syncFcmToken();
          ProfileBloc.instance.add(ReloadProfileEvent());
          TransactionBloc.instance.add(LoadTransactionsEvent());
          CartBloc.instance.add(FetchCartAndWishlistEvent());
        } else {
          // New user: Must complete registration screen before being marked logged in
          await HiveService.setLoggedIn(false);
          await HiveService.setUserName('');
          TransactionBloc.instance.add(ResetTransactionsEvent());
        }

        emit(AuthSuccess(isNewUser: isNewUser));
      } else {
        emit(AuthFailure(result?['message'] ?? 'Invalid OTP code. Please try again.'));
      }
    });

    on<LogoutEvent>((event, emit) async {
      emit(AuthLoading());
      final uid = HiveService.citizenId;
      final phone = HiveService.userPhone;
      if (uid.isNotEmpty || phone.isNotEmpty) {
        AuthApiService.logout(userId: uid, phone: phone);
      }
      await HiveService.clearAllHiveData();
      CartBloc.instance.add(ResetCartAndWishlistEvent());
      ProfileBloc.instance.add(ReloadProfileEvent());
      TransactionBloc.instance.add(ResetTransactionsEvent());
      await Future.delayed(const Duration(milliseconds: 300));
      emit(AuthInitial());
    });
  }
}
