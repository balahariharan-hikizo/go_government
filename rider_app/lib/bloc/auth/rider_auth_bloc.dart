import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../bloc/delivery/delivery_bloc.dart';
import '../../bloc/delivery/delivery_event.dart';
import '../../hive/hive_service.dart';
import '../../network/rider_api_service.dart';
import '../../service/socket_service.dart';
import '../../services/notification_service.dart';
import 'rider_auth_event.dart';
import 'rider_auth_state.dart';

class RiderAuthBloc extends Bloc<RiderAuthEvent, RiderAuthState> {
  static final RiderAuthBloc instance = RiderAuthBloc._internal();

  factory RiderAuthBloc() => instance;

  RiderAuthBloc._internal()
      : super(
          (HiveService.isLoggedIn && HiveService.isProfileCompleted)
              ? RiderAuthSuccessState(
                  userId: HiveService.userId,
                  name: HiveService.userName,
                  phone: HiveService.userPhone,
                  vehicleType: HiveService.vehicleType,
                  vehicleNumber: HiveService.vehicleNumber,
                )
              : RiderAuthInitial(),
        ) {
    on<CheckRiderAuthSessionEvent>((event, emit) {
      if (HiveService.isLoggedIn && HiveService.isProfileCompleted) {
        emit(RiderAuthSuccessState(
          userId: HiveService.userId,
          name: HiveService.userName,
          phone: HiveService.userPhone,
          vehicleType: HiveService.vehicleType,
          vehicleNumber: HiveService.vehicleNumber,
        ));
      } else {
        emit(RiderAuthInitial());
      }
    });

    on<SendRiderOtpEvent>((event, emit) async {
      emit(RiderAuthLoading());
      await HiveService.setUserPhone(event.phone);

      final res = await RiderApiService.sendOtp(event.phone);

      if (res['success'] == true) {
        final otp = res['otp']?.toString();
        if (otp != null && otp.isNotEmpty) {
          await NotificationService.showOtpNotification(otp: otp);
        }
        emit(RiderOtpSentState(phone: event.phone, otp: otp));
      } else {
        emit(RiderAuthFailureState(res['error'] ?? res['message'] ?? 'Failed to send OTP'));
      }
    });

    on<VerifyRiderOtpEvent>((event, emit) async {
      emit(RiderAuthLoading());

      final res = await RiderApiService.verifyOtp(event.phone, event.otp);

      if (res['success'] == true) {
        final userId = res['userId']?.toString() ?? res['user']?['userId']?.toString() ?? '';
        final isNewUser = res['isNewUser'] == true;

        await HiveService.setUserPhone(event.phone);
        await HiveService.setUserId(userId);

        final userObj = res['user'];
        final name = (userObj != null && userObj['userName'] != null)
            ? userObj['userName'].toString().trim()
            : '';
        final vType = (userObj != null && userObj['vehicleType'] != null && userObj['vehicleType'].toString().trim().isNotEmpty)
            ? userObj['vehicleType'].toString().trim()
            : 'Motorcycle';
        final vNum = (userObj != null && userObj['vehicleNumber'] != null)
            ? userObj['vehicleNumber'].toString().trim().toUpperCase()
            : '';

        // Only consider the profile complete if BOTH name AND vehicleNumber exist
        final hasCompleteProfile = !isNewUser && name.isNotEmpty && vNum.isNotEmpty;

        if (hasCompleteProfile) {
          await HiveService.setUserName(name);
          await HiveService.setVehicleType(vType);
          await HiveService.setVehicleNumber(vNum);
          await HiveService.setLoggedIn(true);

          DeliveryBloc.instance.add(LoadDeliveriesEvent());

          emit(RiderAuthSuccessState(
            userId: userId,
            name: name,
            phone: event.phone,
            vehicleType: vType,
            vehicleNumber: vNum,
          ));
        } else {
          // Setup is pending: save known fields but do NOT mark logged in yet
          if (name.isNotEmpty) await HiveService.setUserName(name);
          if (vType.isNotEmpty) await HiveService.setVehicleType(vType);
          if (vNum.isNotEmpty) await HiveService.setVehicleNumber(vNum);
          await HiveService.setLoggedIn(false);

          emit(RiderProfilePendingState(userId: userId, phone: event.phone));
        }
      } else {
        emit(RiderAuthFailureState(res['error'] ?? 'Invalid verification code'));
      }
    });

    on<SaveRiderProfileEvent>((event, emit) async {
      emit(RiderAuthLoading());

      final userId = HiveService.userId;

      // 1. Update backend with Name, Vehicle Type, and Vehicle Number
      final success = await RiderApiService.updateProfile(
        userId: userId,
        userName: event.name,
        vehicleType: event.vehicleType,
        vehicleNumber: event.vehicleNumber,
      );

      if (!success) {
        emit(const RiderAuthFailureState('Failed to save profile. Please try again.'));
        return;
      }

      // 2. Save locally and mark logged in only after profile is completed
      await HiveService.setUserName(event.name);
      await HiveService.setVehicleType(event.vehicleType);
      await HiveService.setVehicleNumber(event.vehicleNumber);
      await HiveService.setLoggedIn(true);

      DeliveryBloc.instance.add(LoadDeliveriesEvent());

      emit(RiderAuthSuccessState(
        userId: userId,
        name: event.name,
        phone: HiveService.userPhone,
        vehicleType: event.vehicleType,
        vehicleNumber: event.vehicleNumber,
      ));
    });

    on<RiderLogoutEvent>((event, emit) async {
      final currentUserId = HiveService.userId;
      final currentPhone = HiveService.userPhone;

      // 1. Tell backend socket immediately that rider is OFFLINE before wiping credentials
      try {
        RiderSocketService().sendGpsPing(0, 0, false);
        RiderSocketService().dispose();
      } catch (e) {
        debugPrint('⚠️ [RiderAuthBloc] Error disconnecting rider socket on logout: $e');
      }

      // 2. Stop and clear foreground background service
      try {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
        await FlutterForegroundTask.saveData(key: 'riderId', value: '');
        await FlutterForegroundTask.saveData(key: 'lastLat', value: 0.0);
        await FlutterForegroundTask.saveData(key: 'lastLng', value: 0.0);
      } catch (e) {
        debugPrint('⚠️ [RiderAuthBloc] Error stopping foreground task on logout: $e');
      }

      // 3. Inform backend API to clear FCM token and remove from riderRegistry
      try {
        if (currentUserId.isNotEmpty || currentPhone.isNotEmpty) {
          await RiderApiService.logout(
            userId: currentUserId,
            phone: currentPhone,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [RiderAuthBloc] Error calling backend logout: $e');
      }

      // 4. Delete FCM token locally on device so old token is invalidated
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        debugPrint('⚠️ [RiderAuthBloc] Error deleting FCM token on logout: $e');
      }

      // 5. Clear duty status and local auth
      await HiveService.setIsOnline(false);
      await HiveService.clearAuth();

      // 6. Reset delivery bloc duty toggle to offline
      try {
        DeliveryBloc.instance.add(const ToggleDutyEvent(false));
      } catch (_) {}

      emit(RiderAuthInitial());
    });
  }
}
