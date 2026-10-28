import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive/hive_service.dart';
import 'report_event.dart';
import 'report_state.dart';
import '../../network/api_service.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc() : super(ReportState.initial()) {
    on<LoadReportsEvent>((event, emit) async {
      final myId = HiveService.citizenId;

      // 1. Instant offline display from Hive cache
      final stored = HiveService.getMyComplaints();
      if (stored.isNotEmpty) {
        emit(state.copyWith(myReports: stored));
      }

      // 2. Fetch My Complaints (10.4) and Community Complaints (10.2) in parallel
      try {
        final results = await Future.wait([
          ComplaintApiService.fetchMyComplaints(myId),
          ComplaintApiService.fetchComplaints(),
        ]);

        final myComplaints = results[0];
        final allComplaints = results[1];

        final processedMy = myComplaints.map((c) {
          final m = Map<String, dynamic>.from(c);
          final likedBy = List<dynamic>.from(m['likedBy'] ?? []);
          m['isLiked'] = likedBy.contains(myId) || m['isLiked'] == true;
          return m;
        }).toList();

        final otherReports = allComplaints
            .where((c) => c['citizenId'] != myId && c['userId'] != myId)
            .map((c) {
              final m = Map<String, dynamic>.from(c);
              final likedBy = List<dynamic>.from(m['likedBy'] ?? []);
              m['isLiked'] = likedBy.contains(myId) || m['isLiked'] == true;
              return m;
            }).toList();

        await HiveService.saveAllComplaints(processedMy);

        emit(state.copyWith(
          myReports: processedMy,
          otherReports: otherReports,
        ));
      } catch (e) {
        debugPrint('[ReportBloc] Initial load error: $e');
      }

      // 3. Keep real-time socket stream active for live changes
      await emit.forEach(
        ApiService.streamAllComplaints(),
        onData: (List<Map<String, dynamic>> allComplaints) {
          final currentMyId = HiveService.citizenId;
          final processed = allComplaints.map((c) {
            final complaintMap = Map<String, dynamic>.from(c);
            final likedBy = List<dynamic>.from(complaintMap['likedBy'] ?? []);
            complaintMap['isLiked'] = likedBy.contains(currentMyId) || complaintMap['isLiked'] == true;
            return complaintMap;
          }).toList();

          final myReports = processed.where((c) => c['citizenId'] == currentMyId || c['userId'] == currentMyId).toList();
          final otherReports = processed.where((c) => c['citizenId'] != currentMyId && c['userId'] != currentMyId).toList();
          
          return state.copyWith(
            myReports: myReports,
            otherReports: otherReports,
          );
        },
        onError: (error, stackTrace) {
          debugPrint('[ReportBloc] Error listening to complaints: $error');
          return state;
        },
      );
    });

    on<ClearAllComplaintsEvent>((event, emit) async {
      await HiveService.clearComplaints();
      emit(state.copyWith(myReports: []));
    });

    on<ToggleActivityTypeEvent>((event, emit) {
      emit(state.copyWith(isMyActivity: event.isMyActivity));
    });

    on<ChangeReportFilterEvent>((event, emit) {
      emit(state.copyWith(selectedFilter: event.filter));
    });

    on<AddNewReportEvent>((event, emit) {
      final updated = List<Map<String, dynamic>>.from(state.myReports);
      updated.insert(0, event.report);
      HiveService.saveAllComplaints(updated);
      emit(state.copyWith(myReports: updated));
    });

    on<ToggleLikeReportEvent>((event, emit) async {
      final myId = HiveService.citizenId;
      final allReports = [...state.myReports, ...state.otherReports];
      final targetIndex = allReports.indexWhere((r) => r['id'] == event.reportId);
      
      if (targetIndex != -1) {
        final target = Map<String, dynamic>.from(allReports[targetIndex]);
        final likedBy = List<dynamic>.from(target['likedBy'] ?? []);
        final isCurrentlyLiked = likedBy.contains(myId) || target['isLiked'] == true;
        final currentCount = (target['likesCount'] as num?)?.toInt() ?? 0;

        final newIsLiked = !isCurrentlyLiked;
        final newLikedBy = List<dynamic>.from(likedBy);
        if (newIsLiked) {
          if (!newLikedBy.contains(myId)) newLikedBy.add(myId);
        } else {
          newLikedBy.remove(myId);
        }
        final newCount = (currentCount + (newIsLiked ? 1 : -1)).clamp(0, 999999);

        target['isLiked'] = newIsLiked;
        target['likedBy'] = newLikedBy;
        target['likesCount'] = newCount;

        final updatedMy = state.myReports.map((r) {
          return r['id'] == event.reportId ? target : r;
        }).toList();
        final updatedOther = state.otherReports.map((r) {
          return r['id'] == event.reportId ? target : r;
        }).toList();

        emit(state.copyWith(
          myReports: updatedMy,
          otherReports: updatedOther,
        ));

        await ApiService.toggleLike(event.reportId, isCurrentlyLiked);
      }
    });

    on<AddCommentToReportEvent>((event, emit) async {
      await ApiService.addComment(event.reportId, event.comment, event.userName);
    });

    on<LoadSingleComplaintEvent>((event, emit) async {
      try {
        final freshDoc = await ComplaintApiService.fetchComplaintById(event.complaintId);
        if (freshDoc != null) {
          final myId = HiveService.citizenId;
          final updatedDoc = Map<String, dynamic>.from(freshDoc);
          final likedBy = List<dynamic>.from(updatedDoc['likedBy'] ?? []);
          updatedDoc['isLiked'] = likedBy.contains(myId) || updatedDoc['isLiked'] == true;

          bool foundInMy = false;
          final updatedMy = state.myReports.map((c) {
            final isMatch = c['id'] == event.complaintId || c['complaintId'] == event.complaintId;
            if (isMatch) foundInMy = true;
            return isMatch ? updatedDoc : c;
          }).toList();

          bool foundInOther = false;
          final updatedOther = state.otherReports.map((c) {
            final isMatch = c['id'] == event.complaintId || c['complaintId'] == event.complaintId;
            if (isMatch) foundInOther = true;
            return isMatch ? updatedDoc : c;
          }).toList();

          if (!foundInMy && !foundInOther) {
            final isMy = updatedDoc['citizenId'] == myId || updatedDoc['userId'] == myId;
            if (isMy) {
              updatedMy.insert(0, updatedDoc);
            } else {
              updatedOther.insert(0, updatedDoc);
            }
          }

          emit(state.copyWith(
            myReports: updatedMy,
            otherReports: updatedOther,
          ));
        }
      } catch (e) {
        debugPrint('[ReportBloc] Error loading single complaint: $e');
      }
    });
  }
}
