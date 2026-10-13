abstract class ReportEvent {}

class LoadReportsEvent extends ReportEvent {}
class ClearAllComplaintsEvent extends ReportEvent {}

class ToggleActivityTypeEvent extends ReportEvent {
  final bool isMyActivity;
  ToggleActivityTypeEvent(this.isMyActivity);
}

class ChangeReportFilterEvent extends ReportEvent {
  final String filter;
  ChangeReportFilterEvent(this.filter);
}

class AddNewReportEvent extends ReportEvent {
  final Map<String, dynamic> report;
  AddNewReportEvent(this.report);
}

class ToggleLikeReportEvent extends ReportEvent {
  final String reportId;
  ToggleLikeReportEvent(this.reportId);
}

class AddCommentToReportEvent extends ReportEvent {
  final String reportId;
  final String comment;
  final String userName;
  AddCommentToReportEvent(this.reportId, this.comment, {this.userName = 'You'});
}

class LoadSingleComplaintEvent extends ReportEvent {
  final String complaintId;
  LoadSingleComplaintEvent(this.complaintId);
}
