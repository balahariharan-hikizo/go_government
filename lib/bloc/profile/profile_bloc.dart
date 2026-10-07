import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive/hive_service.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../network/api_service.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  static final ProfileBloc instance = ProfileBloc._();

  ProfileBloc._() : super(ProfileState.initial()) {
    on<UpdateProfileEvent>((event, emit) async {
      HiveService.saveProfile(
        name: event.name,
        email: event.email,
        imagePath: event.imagePath,
      );
      emit(state.copyWith(
        name: event.name,
        email: event.email,
        imagePath: event.imagePath ?? state.imagePath,
      ));

      String? remoteUrl = event.imagePath;
      if (event.imagePath != null &&
          event.imagePath!.isNotEmpty &&
          !event.imagePath!.startsWith('http') &&
          !event.imagePath!.startsWith('assets/')) {
        final uploaded = await ApiService.uploadProfileImage(event.imagePath!);
        if (uploaded != null) remoteUrl = uploaded;
      }

      await ApiService.updateProfile(
        userId: HiveService.citizenId,
        userName: event.name,
        email: event.email,
        profileImage: remoteUrl,
      );
    });

    on<UpdatePhoneEvent>((event, emit) {
      HiveService.setUserPhone(event.phone);
      emit(state.copyWith(
        phone: event.phone,
      ));
    });

    on<UpdateProfileImageEvent>((event, emit) async {
      HiveService.setUserProfileImage(event.imagePath);
      emit(state.copyWith(
        imagePath: event.imagePath,
      ));

      String? remoteUrl = event.imagePath;
      if (!event.imagePath.startsWith('http') &&
          !event.imagePath.startsWith('assets/')) {
        final uploaded = await ApiService.uploadProfileImage(event.imagePath);
        if (uploaded != null) remoteUrl = uploaded;
      }

      await ApiService.updateProfile(
        userId: HiveService.citizenId,
        userName: state.name.isNotEmpty ? state.name : HiveService.userName,
        email: state.email.isNotEmpty ? state.email : HiveService.userEmail,
        profileImage: remoteUrl,
      );
    });

    on<ReloadProfileEvent>((event, emit) {
      emit(ProfileState.initial());
    });

    on<FetchProfileEvent>((event, emit) async {
      final uid = event.userId ?? HiveService.citizenId;
      if (uid.isEmpty) return;

      final userData = await ApiService.getUserProfile(uid);
      if (userData != null) {
        final name = (userData['userName'] ?? userData['name'] ?? '').toString();
        final email = (userData['email'] ?? '').toString();
        final phone = (userData['phone'] ?? '').toString();
        final img = (userData['profileImage'] ?? '').toString();

        if (name.isNotEmpty) await HiveService.setUserName(name);
        if (email.isNotEmpty) await HiveService.setUserEmail(email);
        if (phone.isNotEmpty) await HiveService.setUserPhone(phone);
        if (img.isNotEmpty) await HiveService.setUserProfileImage(img);

        emit(state.copyWith(
          name: name.isNotEmpty ? name : state.name,
          email: email.isNotEmpty ? email : state.email,
          phone: phone.isNotEmpty ? phone : state.phone,
          imagePath: img.isNotEmpty ? img : state.imagePath,
        ));
      }
    });
  }
}
