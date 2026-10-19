import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/custom_text.dart';
import '../../constants/route_constants.dart';
import '../../bloc/report/report_bloc.dart';
import '../../bloc/report/report_event.dart';
import '../../bloc/report/report_state.dart';
import '../../hive/hive_service.dart';
import '../../widget/complaint_image_widget.dart';
import '../../widget/motion/bouncing_button.dart';
import '../../widget/motion/fade_slide_transition.dart';
import '../../widget/motion/sliding_segmented_bar.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReportBloc>().add(LoadReportsEvent());
  }

  Color _getStatusColor(dynamic rawColor, String? status) {
    if (rawColor is Color) return rawColor;
    if (rawColor is int) return Color(rawColor);
    switch (status) {
      case 'Under Review':
        return const Color(0xFFFF5252);
      case 'In Progress':
        return const Color(0xFFFF9100);
      case 'Resolved':
        return const Color(0xFF4CAF50);
      default:
        return AppColors.primary;
    }
  }

  List<Map<String, dynamic>> _filteredReports(
    bool isMyActivity,
    String selectedFilter,
    List<Map<String, dynamic>> myReports,
    List<Map<String, dynamic>> otherReports,
  ) {
    final baseList = isMyActivity ? myReports : otherReports;
    if (selectedFilter == 'All') {
      return baseList;
    }
    return baseList.where((report) => report['status'] == selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        final bool isMyActivity = state.isMyActivity;
        final String selectedFilter = state.selectedFilter;
        final filteredList = _filteredReports(
          isMyActivity,
          selectedFilter,
          state.myReports,
          state.otherReports,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. App Bar Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.header(
                        'Reports',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: Responsive.h(4)),
                      CustomText.subtitle(
                        'Track and review citizen filings',
                        fontSize: 14,
                        color: AppColors.grayFont,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.w(12)),
                _buildNotificationBell(),
              ],
            ),
            SizedBox(height: Responsive.h(20)),

            // 2. Custom Sliding Segmented Bar with Smooth Pill Motion
            SlidingSegmentedBar(
              labels: const ['My Activity', 'Community'],
              selectedIndex: isMyActivity ? 0 : 1,
              onTabSelected: (index) {
                context.read<ReportBloc>().add(ToggleActivityTypeEvent(index == 0));
              },
            ),
            SizedBox(height: Responsive.h(20)),

            // 3. Horizontal Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip(context, 'All', selectedFilter),
                  SizedBox(width: Responsive.w(10)),
                  _buildFilterChip(context, 'Under Review', selectedFilter),
                  SizedBox(width: Responsive.w(10)),
                  _buildFilterChip(context, 'In Progress', selectedFilter),
                  SizedBox(width: Responsive.w(10)),
                  _buildFilterChip(context, 'Resolved', selectedFilter),
                ],
              ),
            ),
            SizedBox(height: Responsive.h(20)),

            // 4. Staggered animated report cards
            if (filteredList.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(24),
                    vertical: Responsive.h(40),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: Responsive.w(56),
                        height: Responsive.w(56),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF2EC),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.assignment_outlined,
                          color: AppColors.primary,
                          size: Responsive.w(28),
                        ),
                      ),
                      SizedBox(height: Responsive.h(12)),
                      CustomText.header(
                        isMyActivity
                            ? 'No Complaints Reported Yet'
                            : 'No Activity Found',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: Responsive.h(4)),
                      CustomText.subtitle(
                        isMyActivity
                            ? 'Report civic issues in your area like road damage or sanitation'
                            : 'Community complaints and updates will appear here',
                        fontSize: 12,
                        color: AppColors.grayFont,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final report = filteredList[index];
                  return FadeSlideTransitionWidget(
                    key: ValueKey(report['id'] ?? index),
                    index: index,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: Responsive.h(16)),
                      child: _buildReportCard(context, report),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationBell() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(RouteConstants.notification);
      },
      child: Container(
        padding: EdgeInsets.all(Responsive.w(10)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(14)),
          border: Border.all(
            color: AppColors.outliner,
            width: Responsive.w(1.5),
          ),
        ),
        child: Icon(
          Icons.notifications_outlined,
          color: AppColors.black,
          size: Responsive.w(26),
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String selectedFilter) {
    final bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () {
        context.read<ReportBloc>().add(ChangeReportFilterEvent(label));
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(16),
          vertical: Responsive.h(8),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(
            color: isSelected ? AppColors.black : AppColors.outliner,
            width: Responsive.w(1.5),
          ),
        ),
        child: CustomText.title(
          label,
          color: isSelected ? AppColors.white : AppColors.black,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showCommentsBottomSheet(BuildContext context, Map<String, dynamic> report) {
    final TextEditingController commentController = TextEditingController();
    final String reportId = report['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return BlocBuilder<ReportBloc, ReportState>(
          builder: (ctx, state) {
            final allReports = [...state.myReports, ...state.otherReports];
            final liveReport = allReports.firstWhere(
              (r) => r['id'] == reportId,
              orElse: () => report,
            );
            final List<dynamic> comments = List.from(liveReport['comments'] ?? []);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                height: Responsive.h(480),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(Responsive.w(24)),
                  ),
                ),
                padding: EdgeInsets.all(Responsive.w(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: Responsive.w(40),
                        height: Responsive.h(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomText.header(
                          'Comments (${comments.length})',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: comments.isEmpty
                          ? Center(
                              child: CustomText.subtitle(
                                'No comments yet. Be the first to comment!',
                                color: AppColors.grayFont,
                                fontSize: 13,
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: comments.length,
                              separatorBuilder: (context, index) => SizedBox(height: Responsive.h(12)),
                              itemBuilder: (context, index) {
                                final c = comments[index] is Map ? comments[index] as Map : {};
                                return Container(
                                  padding: EdgeInsets.all(Responsive.w(12)),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9F6F4),
                                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          CustomText.title(
                                            c['userName']?.toString() ?? 'Citizen',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          CustomText.subtitle(
                                            c['date']?.toString() ?? 'Just now',
                                            fontSize: 10,
                                            color: AppColors.grayFont,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: Responsive.h(4)),
                                      CustomText.body(
                                        c['comment']?.toString() ?? '',
                                        fontSize: 12,
                                        color: AppColors.black,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    SizedBox(height: Responsive.h(12)),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(Responsive.w(20)),
                              border: Border.all(
                                color: AppColors.outliner,
                                width: 1,
                              ),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                            child: TextField(
                              controller: commentController,
                              style: TextStyle(fontSize: Responsive.sp(14)),
                              decoration: const InputDecoration(
                                hintText: 'Write a comment...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),
                        GestureDetector(
                          onTap: () {
                            final text = commentController.text.trim();
                            if (text.isNotEmpty) {
                              final profileName = HiveService.userName.isNotEmpty
                                  ? HiveService.userName
                                  : 'You';
                              context.read<ReportBloc>().add(
                                    AddCommentToReportEvent(
                                      reportId,
                                      text,
                                      userName: profileName,
                                    ),
                                  );
                              commentController.clear();
                            }
                          },
                          child: Container(
                            width: Responsive.w(44),
                            height: Responsive.w(44),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> report) {
    final String reportId = report['id']?.toString() ?? '';
    final likedBy = List<dynamic>.from(report['likedBy'] ?? []);
    final bool isLiked = report['isLiked'] == true || likedBy.contains(HiveService.citizenId);
    final int likesCount = (report['likesCount'] as num?)?.toInt() ?? 0;
    final List<dynamic> comments = List.from(report['comments'] ?? []);
    final String status = report['status']?.toString() ?? 'Under Review';
    final Color statusColor = _getStatusColor(report['statusColor'], status);

    return BouncingButton(
      scaleFactor: 0.98,
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteConstants.complaintDetails,
          arguments: {
            'report': report,
            'userName': report['userName'] ?? 'User',
            'status': status,
            'statusColor': statusColor,
            'category': report['category'] ?? 'Road Damage',
            'description': report['description'] ?? '',
            'id': reportId,
            'imagePath': report['imagePath'],
            'userAddress': report['userAddress'],
            'date': report['date'],
          },
        );
      },
      child: Container(
        padding: EdgeInsets.all(Responsive.w(16)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(22)),
          border: Border.all(
            color: AppColors.outliner,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: statusColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row + Glowing Status Pill
            Row(
              children: [
                Container(
                  width: Responsive.w(40),
                  height: Responsive.w(40),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/images/avatar.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: Responsive.w(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.title(
                        report['userName'] ?? 'Citizen',
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: Responsive.h(2)),
                      CustomText.subtitle(
                        report['userAddress'] ?? 'HSR Layout, Bengaluru',
                        fontSize: 10.5,
                        color: AppColors.grayFont,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                // Glowing Status Badge Pill
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(10),
                    vertical: Responsive.h(4),
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: Responsive.w(5)),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: Responsive.sp(11),
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(12)),

            // ID
            CustomText.subtitle(
              'ID: ${report['id'] ?? 'N/A'}',
              fontSize: 11,
              color: AppColors.grayFont,
            ),
            SizedBox(height: Responsive.h(4)),

            // Category
            CustomText.title(
              report['category'] ?? 'Road Damage',
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: Responsive.h(4)),

            // Description
            CustomText.body(
              report['description'] ?? '',
              fontSize: 12.5,
              color: Colors.grey.shade700,
              maxLines: 2,
            ),
            if (report['imagePath'] != null &&
                report['imagePath'].toString().trim().isNotEmpty &&
                report['imagePath'].toString().trim() != 'assets/images/report1.png') ...[
              SizedBox(height: Responsive.h(12)),
              ClipRRect(
                borderRadius: BorderRadius.circular(Responsive.w(16)),
                child: SizedBox(
                  height: Responsive.h(160),
                  width: double.infinity,
                  child: ComplaintImageWidget(
                    imagePath: report['imagePath']?.toString(),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            SizedBox(height: Responsive.h(12)),

            // Divider
            Divider(color: Colors.grey.shade100, height: 1),
            SizedBox(height: Responsive.h(10)),

            // Like + Comment row with Bouncing Buttons
            Row(
              children: [
                BouncingButton(
                  scaleFactor: 0.88,
                  onTap: () {
                    if (reportId.isNotEmpty) {
                      context.read<ReportBloc>().add(ToggleLikeReportEvent(reportId));
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(10),
                      vertical: Responsive.h(6),
                    ),
                    decoration: BoxDecoration(
                      color: isLiked ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(Responsive.w(10)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: Responsive.w(16),
                          color: isLiked ? const Color(0xFF2E7D32) : AppColors.grayFont,
                        ),
                        SizedBox(width: Responsive.w(6)),
                        CustomText.subtitle(
                          '$likesCount',
                          fontSize: 12,
                          fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                          color: isLiked ? const Color(0xFF2E7D32) : AppColors.grayFont,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: Responsive.w(16)),
                BouncingButton(
                  scaleFactor: 0.88,
                  onTap: () => _showCommentsBottomSheet(context, report),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(10),
                      vertical: Responsive.h(6),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(Responsive.w(10)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: Responsive.w(16),
                          color: AppColors.grayFont,
                        ),
                        SizedBox(width: Responsive.w(6)),
                        CustomText.subtitle(
                          '${comments.length}',
                          fontSize: 12,
                          color: AppColors.grayFont,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
