import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../bloc/store/store_bloc.dart';
import '../../bloc/store/store_event.dart';
import '../../hive/hive_service.dart';
import '../../network/auth_api_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static final AuthBloc instance = AuthBloc._internal();

  factory AuthBloc() => instance;

  AuthBloc._internal() : super(HiveService.isLoggedIn ? AuthSuccessState(
    userId: HiveService.userId,
    phone: HiveService.userPhone,
  ) : AuthInitial()) {

    on<CheckAuthSessionEvent>((event, emit) {
      if (HiveService.isLoggedIn) {
        emit(AuthSuccessState(
          userId: HiveService.userId,
          phone: HiveService.userPhone,
        ));
      } else {
        emit(AuthInitial());
      }
    });

    on<SendOtpEvent>((event, emit) async {
      emit(AuthLoading());
      await HiveService.setUserPhone(event.phone);

      final res = await AuthApiService.sendOtp(event.phone);

      if (res != null && res['success'] == true) {
        final otp = res['otp']?.toString();
        if (otp != null && otp.isNotEmpty) {
          await NotificationService.showOtpNotification(otp: otp);
        }
        emit(OtpSentState(phone: event.phone, otp: otp));
      } else {
        emit(AuthFailureState(res?['error'] ?? res?['message'] ?? 'Failed to send OTP'));
      }
    });

    on<VerifyOtpEvent>((event, emit) async {
      emit(AuthLoading());

      final res = await AuthApiService.verifyOtp(event.phone, event.otp);

      if (res != null && res['success'] == true) {
        final userId = (res['storeId'] != null && res['storeId'].toString().isNotEmpty)
            ? res['storeId'].toString()
            : (res['phone'] != null && res['phone'].toString().isNotEmpty)
                ? res['phone'].toString()
                : (res['userId']?.toString() ?? event.phone);
        final isNewUser = res['isNewUser'] == true;

        await HiveService.setLoggedIn(true);
        await HiveService.setUserPhone(event.phone);
        await HiveService.setUserId(userId);
        await HiveService.setUserRole('store_owner');

        if (res['user'] != null && res['user']['userName'] != null) {
          await HiveService.setUserName(res['user']['userName'].toString());
        }

        emit(AuthSuccessState(
          userId: userId,
          phone: event.phone,
          isNewUser: isNewUser,
          userData: res['user'] as Map<String, dynamic>?,
        ));
      } else {
        emit(AuthFailureState(res?['error'] ?? 'Invalid OTP code'));
      }
    });

    on<LogoutEvent>((event, emit) async {
      emit(AuthLoading());

      final currentUserId = HiveService.userId;
      final currentPhone = HiveService.userPhone;

      // 1. Disconnect and dispose store socket
      try {
        StoreSocketService().dispose();
      } catch (e) {
        debugPrint('⚠️ [StoreAuthBloc] Socket dispose error: $e');
      }

      // 2. Call backend /api/auth/logout to wipe FCM token & registry
      try {
        if (currentUserId.isNotEmpty || currentPhone.isNotEmpty) {
          await AuthApiService.logout(userId: currentUserId, phone: currentPhone);
        }
      } catch (e) {
        debugPrint('⚠️ [StoreAuthBloc] Backend logout error: $e');
      }

      // 3. Delete local FCM token
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        debugPrint('⚠️ [StoreAuthBloc] FCM delete token error: $e');
      }

      // 4. Reset StoreBloc state
      try {
        StoreBloc.instance.add(const ResetStoreEvent());
      } catch (_) {}

      // 5. Await clearing Hive auth & store boxes completely
      await HiveService.clearAuth();

      emit(AuthInitial());
    });
  }
}
