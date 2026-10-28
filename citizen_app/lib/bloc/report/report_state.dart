import '../../hive/hive_service.dart';

class ReportState {
  final bool isMyActivity;
  final String selectedFilter;
  final List<Map<String, dynamic>> myReports;
  final List<Map<String, dynamic>> otherReports;

  ReportState({
    required this.isMyActivity,
    required this.selectedFilter,
    required this.myReports,
    required this.otherReports,
  });

  factory ReportState.initial() {
    final stored = HiveService.getMyComplaints();
    final List<Map<String, dynamic>> initialMyReports = List.from(stored);

    return ReportState(
      isMyActivity: true,
      selectedFilter: 'All',
      myReports: initialMyReports,
      otherReports: const [],
    );
  }

  ReportState copyWith({
    bool? isMyActivity,
    String? selectedFilter,
    List<Map<String, dynamic>>? myReports,
    List<Map<String, dynamic>>? otherReports,
  }) {
    return ReportState(
      isMyActivity: isMyActivity ?? this.isMyActivity,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      myReports: myReports ?? this.myReports,
      otherReports: otherReports ?? this.otherReports,
    );
  }
}
