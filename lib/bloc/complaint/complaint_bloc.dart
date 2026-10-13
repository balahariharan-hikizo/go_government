import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive/hive_service.dart';
import 'complaint_event.dart';
import 'complaint_state.dart';
import '../../network/api_service.dart';

class ComplaintBloc extends Bloc<ComplaintEvent, ComplaintState> {
  ComplaintBloc() : super(ComplaintState.initial()) {
    on<SelectComplaintCategoryEvent>((event, emit) {
      emit(state.copyWith(selectedCategory: event.category));
    });

    on<PickComplaintImageEvent>((event, emit) {
      emit(state.copyWith(imageFile: event.image));
    });

    on<SubmitComplaintEvent>((event, emit) async {
      emit(state.copyWith(isSubmitting: true));

      final now = DateTime.now();
      final timeStr =
          "${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

      final rawPath = event.imagePath ?? state.imageFile?.path;
      String? remoteImagePath = rawPath;
      if (rawPath != null && rawPath.isNotEmpty && !rawPath.startsWith('assets/')) {
        final uploaded = await ApiService.uploadComplaintImage(rawPath);
        if (uploaded != null && uploaded.isNotEmpty) {
          remoteImagePath = uploaded;
        }
      }

      final newComplaint = {
        'userId': HiveService.citizenId,
        'userName': HiveService.userName.isNotEmpty ? HiveService.userName : 'Citizen',
        'userAddress': (event.location != null && event.location!.isNotEmpty)
            ? event.location!
            : 'Location not specified',
        'category': event.category.isNotEmpty ? event.category : 'Road Damage',
        'description': event.description,
        'status': 'Under Review',
        'statusColor': 0xFFFF5252,
        'imagePath': remoteImagePath,
        'lat': event.lat,
        'lng': event.lng,
        'latitude': event.lat,
        'longitude': event.lng,
        'date': 'Today, $timeStr',
        'likesCount': 0,
        'isLiked': false,
        'comments': <Map<String, dynamic>>[],
      };
      
      // Upload to Node.js & MongoDB (Backend generates official CMP_XXXXX sequence atomically)
      final created = await ApiService.submitComplaint(newComplaint);
      
      // Save locally to Hive with official backend data
      if (created != null) {
        await HiveService.saveComplaint(created);
      } else {
        // Fallback for offline mode
        final offlineFallback = Map<String, dynamic>.from(newComplaint);
        offlineFallback['complaintId'] = 'PENDING_${DateTime.now().millisecondsSinceEpoch}';
        offlineFallback['id'] = offlineFallback['complaintId'];
        await HiveService.saveComplaint(offlineFallback);
      }

      emit(state.copyWith(isSubmitting: false, isSubmitted: true));
    });

    on<ClearComplaintEvent>((event, emit) {
      emit(ComplaintState.initial());
    });
  }
}
