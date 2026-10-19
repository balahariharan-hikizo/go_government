import 'package:flutter/material.dart';
import '../../../constants/route_constants.dart';
import '../../../hive/hive_service.dart';
import '../../../model/notification_model.dart';
import '../../../network/notification_api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;
  List<NotificationModel> _notifications = [];

  String get _currentUserId {
    final uid = HiveService.userId;
    if (uid.isNotEmpty) return uid;
    final phone = HiveService.userPhone;
    if (phone.isNotEmpty) return phone;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final list = await NotificationApiService.getNotifications(_currentUserId);
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final hasUnread = _notifications.any((n) => !n.isRead);
    if (!hasUnread) return;

    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });

    await NotificationApiService.markAllAsRead(_currentUserId);
  }

  void _onNotificationTap(NotificationModel item) {
    if (!item.isRead) {
      setState(() {
        final idx = _notifications.indexWhere((n) => n.notificationId == item.notificationId);
        if (idx != -1) {
          _notifications[idx] = item.copyWith(isRead: true);
        }
      });
      NotificationApiService.markAsRead(item.notificationId);
    }

    if (item.type == 'complaint' && item.referenceId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        RouteConstants.complaintDetails,
        arguments: {'id': item.referenceId},
      );
    } else if (item.type == 'order' && item.referenceId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        RouteConstants.orderStatus,
        arguments: {'orderId': item.referenceId},
      );
    } else if (item.type == 'wallet') {
      Navigator.pushNamed(context, RouteConstants.transaction);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays == 0 && now.day == dt.day) {
      return 'Today, $timeStr';
    } else if (diff.inDays <= 1 || (diff.inDays == 1 && now.day != dt.day)) {
      return 'Yesterday, $timeStr';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[dt.month - 1];
      return '${dt.day} $monthStr, $timeStr';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'complaint':
        return Icons.report_problem_rounded;
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'complaint':
        return const Color(0xFFE11D48); // Rose red
      case 'order':
        return const Color(0xFF0284C7); // Sky blue
      case 'wallet':
        return const Color(0xFF16A34A); // Green
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

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
          'Notifications',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
        centerTitle: false,
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: EdgeInsets.only(right: Responsive.w(16)),
              child: TextButton.icon(
                onPressed: _markAllAsRead,
                icon: Icon(
                  Icons.done_all_rounded,
                  size: Responsive.w(16),
                  color: AppColors.primary,
                ),
                label: CustomText.body(
                  'Mark all read',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _fetchNotifications,
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(20),
                          vertical: Responsive.h(12),
                        ),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, index) => SizedBox(height: Responsive.h(14)),
                        itemBuilder: (context, index) {
                          return _buildNotificationCard(_notifications[index]);
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(40)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: Responsive.w(80),
                height: Responsive.w(80),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: Responsive.w(40),
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: Responsive.h(20)),
              CustomText.header(
                'No Notifications Yet',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
              SizedBox(height: Responsive.h(8)),
              CustomText.body(
                "You're all caught up! Updates regarding your civic complaints and grocery orders will appear here.",
                fontSize: 13,
                color: Colors.grey.shade600,
                textAlign: TextAlign.center,
                height: 1.4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel item) {
    final typeColor = _getTypeColor(item.type);
    final typeIcon = _getTypeIcon(item.type);

    return InkWell(
      onTap: () => _onNotificationTap(item),
      borderRadius: BorderRadius.circular(Responsive.w(18)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(Responsive.w(16)),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : const Color(0xFFF0FDF4), // slight tint for unread
          borderRadius: BorderRadius.circular(Responsive.w(18)),
          border: Border.all(
            color: item.isRead ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.3),
            width: item.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: item.isRead ? 0.02 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              width: Responsive.w(40),
              height: Responsive.w(40),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                typeIcon,
                color: typeColor,
                size: Responsive.w(20),
              ),
            ),
            SizedBox(width: Responsive.w(14)),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomText.body(
                          item.title,
                          fontSize: 14,
                          fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      if (!item.isRead) ...[
                        SizedBox(width: Responsive.w(6)),
                        Container(
                          width: Responsive.w(8),
                          height: Responsive.w(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: Responsive.h(6)),
                  CustomText.body(
                    item.message,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.35,
                  ),
                  SizedBox(height: Responsive.h(10)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CustomText.subtitle(
                        _formatTimestamp(item.createdAt),
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      if (item.referenceId.isNotEmpty)
                        Row(
                          children: [
                            CustomText.body(
                              'View Details',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: Responsive.w(2)),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: Responsive.w(10),
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
