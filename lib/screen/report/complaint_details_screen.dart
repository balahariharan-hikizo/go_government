import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../widget/common_map.dart';
import '../../widget/common_directions_button.dart';
import '../../bloc/report/report_bloc.dart';
import '../../bloc/report/report_event.dart';
import '../../bloc/report/report_state.dart';
import '../../hive/hive_service.dart';
import '../../widget/complaint_image_widget.dart';
import '../../widget/image_preview_dialog.dart';
import 'package:latlong2/latlong.dart';
import '../../widget/motion/tilt_3d_card.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? report;
  final String userName;
  final String status;
  final Color statusColor;
  final String category;
  final String description;
  final String id;
  final String? imagePath;
  final String? userAddress;
  final String? date;

  const ComplaintDetailsScreen({
    super.key,
    this.report,
    required this.userName,
    required this.status,
    required this.statusColor,
    this.category = 'Road Damage',
    this.description = '',
    this.id = '',
    this.imagePath,
    this.userAddress,
    this.date,
  });

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _showAllComments = false;

  @override
  void initState() {
    super.initState();
    final targetId = widget.id.isNotEmpty
        ? widget.id
        : (widget.report?['complaintId']?.toString() ?? widget.report?['id']?.toString() ?? '');
    if (targetId.isNotEmpty) {
      context.read<ReportBloc>().add(LoadSingleComplaintEvent(targetId));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _addComment(String reportId) {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final name = HiveService.userName.isNotEmpty ? HiveService.userName : 'You';
    context.read<ReportBloc>().add(
          AddCommentToReportEvent(
            reportId,
            text,
            userName: name,
          ),
        );
    setState(() {
      _showAllComments = true;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  Widget _buildHeaderImage(String? imagePath) {
    return ComplaintImageWidget(
      imagePath: imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: Responsive.h(280),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveId = widget.id.isNotEmpty
        ? widget.id
        : (widget.report?['id']?.toString() ?? '');

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: Responsive.w(70),
        leading: Padding(
          padding: EdgeInsets.only(left: Responsive.w(20)),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: Responsive.w(44),
                height: Responsive.w(44),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.outliner,
                    width: Responsive.w(1.5),
                  ),
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: AppColors.black,
                  size: Responsive.w(24),
                ),
              ),
            ),
          ),
        ),
        title: CustomText.header(
          'Complaint Details',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: false,
      ),
      body: BlocBuilder<ReportBloc, ReportState>(
        builder: (context, state) {
          final allReports = [...state.myReports, ...state.otherReports];
          final liveReport = allReports.firstWhere(
            (r) =>
                (r['id'] != null && r['id'] == effectiveId) ||
                (r['complaintId'] != null && r['complaintId'] == effectiveId),
            orElse: () => widget.report ?? {},
          );

          final String userName = liveReport['userName']?.toString() ?? widget.userName;
          final String status = liveReport['status']?.toString() ?? widget.status;
          final String category = liveReport['category']?.toString() ?? widget.category;
          final String title = liveReport['title']?.toString() ?? category;
          final String description = liveReport['description']?.toString() ?? widget.description;
          final String id = liveReport['id']?.toString() ?? widget.id;
          final String? imagePath = liveReport['imagePath']?.toString() ?? widget.imagePath;
          final String userAddress = liveReport['userAddress']?.toString() ??
              widget.userAddress ??
              'Location not specified';
          final String date = liveReport['date']?.toString() ?? widget.date ?? 'Today';
          final likedBy = List<dynamic>.from(liveReport['likedBy'] ?? []);
          final bool isLiked = liveReport['isLiked'] == true || likedBy.contains(HiveService.citizenId);
          final int likesCount = (liveReport['likesCount'] as num?)?.toInt() ?? 0;
          final List<dynamic> comments = List.from(liveReport['comments'] ?? []);

          final rawLat = liveReport['lat'] ?? liveReport['latitude'];
          final rawLng = liveReport['lng'] ?? liveReport['longitude'];
          final double? complaintLat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '');
          final double? complaintLng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '');
          final LatLng? destCoords = (complaintLat != null && complaintLng != null) ? LatLng(complaintLat, complaintLng) : null;

          return CommonBackground(
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  if (effectiveId.isNotEmpty) {
                    context.read<ReportBloc>().add(LoadSingleComplaintEvent(effectiveId));
                    await Future.delayed(const Duration(milliseconds: 600));
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(20),
                    vertical: Responsive.h(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Image Header Section
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Responsive.w(28)),
                        child: Container(
                          height: Responsive.h(280),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.outliner,
                              width: Responsive.w(1.5),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  ImagePreviewDialog.show(
                                    context,
                                    imagePath: imagePath,
                                    title: title.isNotEmpty ? title : 'Complaint Photo Evidence',
                                    subtitle: '$category • $userAddress',
                                  );
                                },
                                child: _buildHeaderImage(imagePath),
                              ),
                              // Dark gradient overlay
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: Responsive.h(90),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.85),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Zoom Preview badge top right
                              Positioned(
                                top: Responsive.h(12),
                                right: Responsive.w(12),
                                child: GestureDetector(
                                  onTap: () {
                                    ImagePreviewDialog.show(
                                      context,
                                      imagePath: imagePath,
                                      title: title.isNotEmpty ? title : 'Complaint Photo Evidence',
                                      subtitle: '$category • $userAddress',
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.w(8),
                                      vertical: Responsive.h(4),
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(Responsive.w(12)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in, color: Colors.white, size: Responsive.w(14)),
                                        SizedBox(width: Responsive.w(4)),
                                        Text(
                                          'Preview',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: Responsive.sp(10),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Citizen avatar + details row inside image
                              Positioned(
                                bottom: Responsive.h(16),
                                left: Responsive.w(16),
                                right: Responsive.w(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: Responsive.w(44),
                                      height: Responsive.w(44),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.person,
                                          color: AppColors.primary,
                                          size: Responsive.w(24),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: Responsive.w(12)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CustomText.title(
                                            userName,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            maxLines: 1,
                                          ),
                                          CustomText.subtitle(
                                            date,
                                            fontSize: 11,
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(20)),

                      // 2. Complaint details card (Interactive 3D Perspective Tilt Card)
                      Tilt3DCard(
                        borderRadius: BorderRadius.circular(Responsive.w(24)),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(Responsive.w(16)),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(24)),
                            border: Border.all(
                              color: AppColors.outliner,
                              width: Responsive.w(1.5),
                            ),
                          ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status
                            Row(
                              children: [
                                CustomText.title(
                                  'Status: ',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                CustomText.title(
                                  status,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: widget.statusColor,
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(12)),

                            // Category Title
                            CustomText.header(
                              category,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            SizedBox(height: Responsive.h(8)),

                            // Description
                            CustomText.body(
                              description.isNotEmpty
                                  ? description
                                  : 'No additional details provided.',
                              color: const Color(0xFF4A4A4A),
                              fontSize: 13,
                              height: 1.4,
                            ),
                            SizedBox(height: Responsive.h(16)),

                            // Metadata rows
                            Row(
                              children: [
                                CustomText.title(
                                  'ID: ',
                                  fontSize: 13,
                                  color: AppColors.grayFont,
                                  fontWeight: FontWeight.bold,
                                ),
                                CustomText.body(
                                  id.isNotEmpty ? id : 'N/A',
                                  fontSize: 13,
                                  color: AppColors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(8)),
                            Row(
                              children: [
                                CustomText.title(
                                  'Engineer\'s Name : ',
                                  fontSize: 13,
                                  color: AppColors.grayFont,
                                  fontWeight: FontWeight.bold,
                                ),
                                Expanded(
                                  child: CustomText.body(
                                    liveReport['engineerName']?.toString() ?? 'Ward Civic Engineer (Assigned on review)',
                                    fontSize: 13,
                                    color: AppColors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(8)),
                            Row(
                              children: [
                                CustomText.title(
                                  'Engineer\'s Contact : ',
                                  fontSize: 13,
                                  color: AppColors.grayFont,
                                  fontWeight: FontWeight.bold,
                                ),
                                Expanded(
                                  child: CustomText.body(
                                    liveReport['engineerContact']?.toString() ?? 'Ward Helpline: 1912',
                                    fontSize: 13,
                                    color: AppColors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(16)),

                            // Miniature Map outline
                            Container(
                              height: Responsive.h(100),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(Responsive.w(20)),
                                border: Border.all(
                                  color: AppColors.outliner,
                                  width: Responsive.w(1.5),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CommonMap(
                                interactive: false,
                                showUserLocation: false,
                                center: destCoords,
                              ),
                            ),
                            SizedBox(height: Responsive.h(16)),

                            // Directions button
                            CommonDirectionsButton(
                              title: '$category Location',
                              address: userAddress,
                              destinationCoords: destCoords,
                              style: DirectionsButtonStyle.wide,
                            ),
                            SizedBox(height: Responsive.h(16)),

                            // Divider
                            Divider(
                              color: AppColors.outliner,
                              height: 1,
                              thickness: Responsive.w(1.2),
                            ),
                            SizedBox(height: Responsive.h(12)),

                            // Bottom toolbar reactions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (effectiveId.isNotEmpty) {
                                      context.read<ReportBloc>().add(
                                            ToggleLikeReportEvent(effectiveId),
                                          );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLiked
                                            ? Icons.thumb_up
                                            : Icons.thumb_up_alt_outlined,
                                        color: isLiked
                                            ? const Color(0xFF2E7D32)
                                            : AppColors.black,
                                        size: Responsive.w(20),
                                      ),
                                      SizedBox(width: Responsive.w(6)),
                                      CustomText.title(
                                        '$likesCount',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isLiked
                                            ? const Color(0xFF2E7D32)
                                            : AppColors.black,
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_outlined,
                                      color: AppColors.black,
                                      size: Responsive.w(20),
                                    ),
                                    SizedBox(width: Responsive.w(6)),
                                    CustomText.title(
                                      '${comments.length}',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                      SizedBox(height: Responsive.h(20)),

                      // 3. Comments heading
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(4)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CustomText.header(
                              'Comments (${comments.length})',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            if (comments.length > 1)
                              GestureDetector(
                                onTap: () => setState(() => _showAllComments = !_showAllComments),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(10),
                                    vertical: Responsive.h(4),
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomText.body(
                                        _showAllComments ? 'Show Less' : 'View All (${comments.length})',
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      SizedBox(width: Responsive.w(4)),
                                      Icon(
                                        _showAllComments ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.h(12)),

                      // 4. Comments list & Add Comment
                      if (comments.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(Responsive.w(16)),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(20)),
                            border: Border.all(
                              color: AppColors.outliner,
                              width: Responsive.w(1.2),
                            ),
                          ),
                          child: Center(
                            child: CustomText.subtitle(
                              'No comments yet. Leave a note below.',
                              color: AppColors.grayFont,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else ...[
                        ...(_showAllComments ? comments : comments.take(1)).map((c) {
                          final item = c is Map ? c : {};
                          final String author = item['userName']?.toString() ?? 'Official';
                          final String time = item['date']?.toString() ?? 'Recent';
                          final String text = item['comment']?.toString() ?? '';

                          return Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: Responsive.h(12)),
                            padding: EdgeInsets.all(Responsive.w(16)),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(Responsive.w(20)),
                              border: Border.all(
                                color: AppColors.outliner,
                                width: Responsive.w(1.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: Responsive.w(36),
                                      height: Responsive.w(36),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF5F5F5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.person,
                                          color: AppColors.primary,
                                          size: Responsive.w(20),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: Responsive.w(10)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CustomText.title(
                                            author,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          CustomText.subtitle(
                                            time,
                                            fontSize: 10,
                                            color: AppColors.grayFont,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: Responsive.h(8)),
                                CustomText.body(
                                  text,
                                  color: const Color(0xFF333333),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                          );
                        }),
                        
                      ],

                      SizedBox(height: Responsive.h(8)),

                      // 5. Add Comment Input Row
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(16),
                          vertical: Responsive.h(6),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(24)),
                          border: Border.all(
                            color: AppColors.outliner,
                            width: Responsive.w(1.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                style: TextStyle(fontSize: Responsive.sp(14)),
                                decoration: const InputDecoration(
                                  hintText: 'Write a comment or update...',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            SizedBox(width: Responsive.w(8)),
                            GestureDetector(
                              onTap: () => _addComment(effectiveId),
                              child: Container(
                                width: Responsive.w(40),
                                height: Responsive.w(40),
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
                      ),
                      SizedBox(height: Responsive.h(30)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
}
