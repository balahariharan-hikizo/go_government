import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/custom_text.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../constants/route_constants.dart';
import '../../bloc/report/report_bloc.dart';
import '../../bloc/report/report_state.dart';

import 'package:latlong2/latlong.dart';
import '../../hive/hive_service.dart';
import '../../service/location_service.dart';
import '../../widget/motion/bouncing_button.dart';
import '../../widget/motion/fade_slide_transition.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  String? _liveGpsAddress;
  bool _isLoadingLocation = false;
  bool _isLocationAvailable = true;
  bool _isPromptOpen = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptLocation(showPromptIfMissing: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final bool isCurrentScreen = route != null && route.isCurrent;
      _checkAndPromptLocation(showPromptIfMissing: isCurrentScreen);
    }
  }

  Future<void> _checkAndPromptLocation({
    bool showPromptIfMissing = true,
  }) async {
    // 1. If citizen already selected a manual location, everything works seamlessly!
    if (LocationService.hasManualLocation) {
      if (mounted) {
        setState(() {
          _isLocationAvailable = true;
          _isLoadingLocation = false;
        });
      }
      return;
    }

    // 2. Check if live GPS is currently active and permitted
    final bool available = await LocationService.isLocationAvailable();
    if (!available) {
      LocationService.clearGpsCache();
      if (mounted) {
        setState(() {
          _isLocationAvailable = false;
          _liveGpsAddress = null;
          _isLoadingLocation = false;
        });
        if (showPromptIfMissing && !_isPromptOpen) {
          _showLocationRequiredSheet();
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLocationAvailable = true;
          _isLoadingLocation = true;
        });
      }
      final addr = await LocationService.getEffectiveAddress();
      if (mounted) {
        setState(() {
          _liveGpsAddress = addr.isNotEmpty ? addr : null;
          _isLocationAvailable = addr.isNotEmpty;
          _isLoadingLocation = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Color _getStatusColor(dynamic colorVal, String? status) {
    if (colorVal is int) return Color(colorVal);
    if (colorVal is Color) return colorVal;
    switch ((status ?? '').toLowerCase()) {
      case 'resolved':
        return const Color(0xFF4CAF50);
      case 'in progress':
        return const Color(0xFFFF9100);
      default:
        return const Color(0xFFFF5252);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = context.watch<ProfileBloc>().state;
    final String name = profileState.name.trim();
    final bool hasName = name.isNotEmpty;
    final String greetingTitle = hasName
        ? '${_getGreeting()}, $name..'
        : '${_getGreeting()}! Welcome';
    final String greetingSubtitle = hasName
        ? 'Here are today\'s actions for you'
        : 'Tap your profile to set up your details';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Custom Header
        FadeSlideTransitionWidget(
          index: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.header(
                      greetingTitle,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: Responsive.h(4)),
                    CustomText.subtitle(
                      greetingSubtitle,
                      fontSize: 14,
                      color: AppColors.grayFont,
                    ),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(12)),
              BouncingButton(
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(RouteConstants.notification),
                child: _buildNotificationBell(context),
              ),
            ],
          ),
        ),

        // 1b. Active Location Chip
        FadeSlideTransitionWidget(
          index: 1,
          child: _buildLocationBanner(context),
        ),

        SizedBox(height: Responsive.h(20)),

        // 2. Bento Action Grid (2x2) with Micro-Spring Tactile Feedback
        FadeSlideTransitionWidget(
          index: 2,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: Responsive.w(16),
            mainAxisSpacing: Responsive.w(16),
            childAspectRatio: 1.18,
            children: [
              BouncingButton(
                onTap: () {
                  Navigator.of(
                    context,
                  ).pushNamed(RouteConstants.feedbackSurvey);
                },
                child: _buildActionCard(
                  imagePath: 'assets/images/feedback.png',
                  label: 'Near Feedback',
                  gradientColors: [const Color(0xFFF0F7FF), Colors.white],
                  iconBg: const Color(0xFFE0F2FE),
                  borderColor: const Color(0xFFBAE6FD),
                ),
              ),
              BouncingButton(
                onTap: () {
                  Navigator.of(context).pushNamed(RouteConstants.nearStores);
                },
                child: _buildActionCard(
                  imagePath: 'assets/images/stores.png',
                  label: 'Near Stores',
                  gradientColors: [const Color(0xFFFFF7ED), Colors.white],
                  iconBg: const Color(0xFFFFEDD5),
                  borderColor: const Color(0xFFFED7AA),
                ),
              ),
              BouncingButton(
                onTap: () {
                  Navigator.of(context).pushNamed(RouteConstants.nearBusStop);
                },
                child: _buildActionCard(
                  imagePath: 'assets/images/Bus.png',
                  label: 'Near Bus Stop',
                  gradientColors: [const Color(0xFFF5F3FF), Colors.white],
                  iconBg: const Color(0xFFEDE9FE),
                  borderColor: const Color(0xFFDDD6FE),
                ),
              ),
              BouncingButton(
                onTap: () {
                  Navigator.of(context).pushNamed(RouteConstants.nearToilet);
                },
                child: _buildActionCard(
                  imagePath: 'assets/images/toilet.png',
                  label: 'Near Toilet',
                  gradientColors: [const Color(0xFFF0FDF4), Colors.white],
                  iconBg: const Color(0xFFDCFCE7),
                  borderColor: const Color(0xFFBBF7D0),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.h(28)),

        // 3. Active Complaint Section
        FadeSlideTransitionWidget(
          index: 3,
          child: BlocBuilder<ReportBloc, ReportState>(
            builder: (context, reportState) {
              final myReports = reportState.myReports;

              // Empty state when user has no reports
              if (myReports.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.header(
                      'Civic Complaints',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: Responsive.h(4)),
                    CustomText.subtitle(
                      'Track and resolve neighborhood issues',
                      fontSize: 13,
                      color: AppColors.grayFont,
                    ),
                    SizedBox(height: Responsive.h(16)),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(28)),
                        border: Border.all(
                          color: AppColors.outliner,
                          width: Responsive.w(1.5),
                        ),
                      ),
                      padding: EdgeInsets.all(Responsive.w(20)),
                      child: Column(
                        children: [
                          Container(
                            width: Responsive.w(56),
                            height: Responsive.w(56),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF2EC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.assignment_turned_in_outlined,
                              color: AppColors.primary,
                              size: Responsive.w(28),
                            ),
                          ),
                          SizedBox(height: Responsive.h(12)),
                          CustomText.title(
                            'No Active Complaints',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          SizedBox(height: Responsive.h(6)),
                          CustomText.body(
                            'Notice broken streetlights, potholes, or sanitation issues near your home? Submit a report to get it resolved.',
                            textAlign: TextAlign.center,
                            color: AppColors.grayFont,
                            fontSize: 12,
                          ),
                          SizedBox(height: Responsive.h(16)),
                          BouncingButton(
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pushNamed(RouteConstants.addComplaint);
                            },
                            child: Container(
                              width: double.infinity,
                              height: Responsive.h(48),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(
                                  Responsive.w(24),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: Responsive.w(20),
                                  ),
                                  SizedBox(width: Responsive.w(8)),
                                  const Text(
                                    'File a Complaint',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final Map<String, dynamic> latestReport = myReports.first;
              final String category = latestReport['category'] ?? 'Road Damage';
              final String reportId =
                  latestReport['id']?.toString() ?? 'CMP000000';
              final String description = latestReport['description'] ?? '';
              final String address =
                  latestReport['userAddress'] ?? 'No address provided';
              final String status = latestReport['status'] ?? 'Under Review';
              final Color statusColor = _getStatusColor(
                latestReport['statusColor'],
                status,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText.header(
                              category,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: Responsive.h(4)),
                            CustomText.subtitle(
                              'ID: $reportId',
                              fontSize: 13,
                              color: AppColors.grayFont,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: Responsive.w(12)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(12),
                          vertical: Responsive.h(5),
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: CustomText.body(
                          status,
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // 4. Detail Info Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(Responsive.w(28)),
                      border: Border.all(
                        color: AppColors.outliner,
                        width: Responsive.w(1.5),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(16),
                      vertical: Responsive.h(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text box container (grey bubble)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(
                              Responsive.w(16),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(16),
                            vertical: Responsive.h(14),
                          ),
                          child: CustomText.body(
                            description,
                            color: const Color(0xFF4A4A4A),
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: Responsive.h(14)),
                        // Location detail row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: Responsive.w(42),
                              height: Responsive.h(42),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF2EC),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primary,
                                size: Responsive.w(20),
                              ),
                            ),
                            SizedBox(width: Responsive.w(12)),
                            Expanded(
                              child: CustomText.subtitle(
                                address,
                                fontSize: 13,
                                color: const Color(0xFF333333),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.h(14)),
                        // View Status & Overlapping Floating Button
                        Stack(
                          alignment: Alignment.centerLeft,
                          clipBehavior: Clip.none,
                          children: [
                            FractionallySizedBox(
                              widthFactor: 0.86,
                              child: Container(
                                height: Responsive.h(52),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(
                                    Responsive.w(26),
                                  ),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: Responsive.w(1.5),
                                  ),
                                ),
                                child: BouncingButton(
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                      RouteConstants.complaintDetails,
                                      arguments: {
                                        'report': latestReport,
                                        'userName':
                                            latestReport['userName'] ??
                                            (name.isNotEmpty
                                                ? name
                                                : 'Citizen'),
                                        'status': status,
                                        'statusColor': statusColor,
                                        'category': category,
                                        'description': description,
                                        'id': reportId,
                                        'imagePath': latestReport['imagePath'],
                                        'userAddress': address,
                                        'date': latestReport['date'] ?? 'Today',
                                      },
                                    );
                                  },
                                  child: Center(
                                    child: CustomText.title(
                                      'View Status',
                                      color: AppColors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: BouncingButton(
                                onTap: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(RouteConstants.addComplaint);
                                },
                                child: Container(
                                  width: Responsive.w(54),
                                  height: Responsive.h(54),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(
                                      Responsive.w(20),
                                    ),
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: Responsive.w(1.5),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: Responsive.w(8),
                                        offset: Offset(0, Responsive.h(4)),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: AppColors.primary,
                                    size: Responsive.w(32),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
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

  Widget _buildActionCard({
    required String imagePath,
    required String label,
    Color? iconBg,
    List<Color>? gradientColors,
    Color? borderColor,
  }) {
    final bgColors =
        gradientColors ?? [const Color(0xFFFAFAFA), AppColors.white];
    final border = borderColor ?? AppColors.outliner;
    final containerBg = iconBg ?? const Color(0xFFFFF2EC);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgColors,
        ),
        borderRadius: BorderRadius.circular(Responsive.w(24)),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: containerBg.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: Responsive.w(50),
            height: Responsive.w(50),
            decoration: BoxDecoration(
              color: containerBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: Responsive.w(30),
                height: Responsive.w(30),
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: Responsive.h(10)),
          CustomText.title(label, fontSize: 13.5, fontWeight: FontWeight.bold),
        ],
      ),
    );
  }

  Widget _buildLocationBanner(BuildContext context) {
    final hasManual = LocationService.hasManualLocation;
    final bool hasLocation =
        hasManual ||
        (_isLocationAvailable &&
            _liveGpsAddress != null &&
            _liveGpsAddress!.isNotEmpty);
    final rawAddress = hasManual
        ? (LocationService.manualAddress ?? 'Manual Location')
        : (_liveGpsAddress ??
              (LocationService.cachedGpsAddress ??
                  'Detecting GPS location...'));

    String primaryTitle = '';
    String secondarySubtitle = rawAddress;

    if (_isLoadingLocation) {
      primaryTitle = 'Detecting Location...';
      secondarySubtitle = 'Connecting to GPS & Ola Maps...';
    } else if (!hasLocation) {
      primaryTitle = 'Location Access Needed';
      secondarySubtitle = 'Tap to enable GPS or select address manually';
    } else {
      final commaIndex = rawAddress.indexOf(',');
      if (commaIndex != -1 && commaIndex < rawAddress.length - 1) {
        primaryTitle = rawAddress.substring(0, commaIndex).trim();
        secondarySubtitle = rawAddress.substring(commaIndex + 1).trim();
      } else {
        primaryTitle = rawAddress.isNotEmpty
            ? rawAddress
            : (hasManual ? 'Selected Location' : 'Current Location');
        secondarySubtitle = hasManual
            ? 'Custom pinned location'
            : 'Near your live coordinates';
      }
      if (primaryTitle.isEmpty) {
        primaryTitle = hasManual ? 'Selected Location' : 'Current Location';
      }
    }

    final Color borderColor = hasManual
        ? const Color(0xFFFFCC80)
        : (!hasLocation && !_isLoadingLocation
              ? const Color(0xFFFFB74D)
              : AppColors.outliner);

    return GestureDetector(
      onTap: () async {
        if (_isNavigating) return;
        if (!hasLocation && !_isLoadingLocation) {
          _showLocationRequiredSheet();
          return;
        }

        _isNavigating = true;
        try {
          final result = await Navigator.pushNamed(
            context,
            RouteConstants.pickLocation,
            arguments: {
              'initialLatLng': hasManual ? LocationService.defaultLocation : null,
              'initialAddress': hasManual
                  ? LocationService.manualAddress
                  : _liveGpsAddress,
              'isLiveGps': false,
            },
          );
          if (result is Map<String, dynamic>) {
            final isGps = result['isGps'] == true;
            if (isGps) {
              await HiveService.clearManualLocation();
              if (result['address'] != null &&
                  (result['address'] as String).isNotEmpty) {
                _liveGpsAddress = result['address'] as String;
              } else {
                _liveGpsAddress = await LocationService.getEffectiveAddress();
              }
            } else if (result['latLng'] != null && result['address'] != null) {
              final latLng = result['latLng'] as LatLng;
              final addr = result['address'] as String;
              await HiveService.setManualLocation(
                latitude: latLng.latitude,
                longitude: latLng.longitude,
                address: addr,
              );
            }
            if (mounted) {
              _checkAndPromptLocation(showPromptIfMissing: false);
            }
          }
        } finally {
          _isNavigating = false;
        }
      },
      child: Container(
        margin: EdgeInsets.only(top: Responsive.h(12)),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(14),
          vertical: Responsive.h(10),
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 1. Clean Leading Icon with Soft Rounded Background
            Container(
              width: Responsive.w(38),
              height: Responsive.w(38),
              decoration: BoxDecoration(
                color: hasManual
                    ? const Color(0xFFFFF3E0)
                    : (!hasLocation && !_isLoadingLocation
                          ? const Color(0xFFFFF3E0)
                          : AppColors.primary.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(Responsive.w(12)),
              ),
              child: Icon(
                hasManual
                    ? Icons.edit_location_alt_rounded
                    : (!hasLocation && !_isLoadingLocation
                          ? Icons.location_off_rounded
                          : Icons.my_location_rounded),
                color: hasManual
                    ? const Color(0xFFE65100)
                    : (!hasLocation && !_isLoadingLocation
                          ? const Color(0xFFE65100)
                          : AppColors.primary),
                size: Responsive.w(18),
              ),
            ),
            SizedBox(width: Responsive.w(10)),

            // 2. Main Title (Locality) + Status Tag + Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          primaryTitle,
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: Responsive.sp(13),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: Responsive.w(4)),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.grayFont,
                      ),
                      SizedBox(width: Responsive.w(6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(6),
                          vertical: Responsive.h(2),
                        ),
                        decoration: BoxDecoration(
                          color: hasManual
                              ? const Color(0xFFFFF3E0)
                              : (!hasLocation && !_isLoadingLocation
                                    ? const Color(0xFFFFEBEE)
                                    : const Color(0xFFE8F5E9)),
                          borderRadius: BorderRadius.circular(Responsive.w(6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!hasManual && hasLocation) ...[
                              const Icon(
                                Icons.gps_fixed,
                                size: 9,
                                color: Color(0xFF2E7D32),
                              ),
                              SizedBox(width: Responsive.w(3)),
                            ] else if (!hasLocation && !_isLoadingLocation) ...[
                              const Icon(
                                Icons.error_outline,
                                size: 9,
                                color: Color(0xFFD32F2F),
                              ),
                              SizedBox(width: Responsive.w(3)),
                            ],
                            Text(
                              hasManual
                                  ? 'Manual'
                                  : (!hasLocation && !_isLoadingLocation
                                        ? 'Disabled'
                                        : 'Live GPS'),
                              style: TextStyle(
                                fontSize: Responsive.sp(9),
                                fontWeight: FontWeight.bold,
                                color: hasManual
                                    ? const Color(0xFFE65100)
                                    : (!hasLocation && !_isLoadingLocation
                                          ? const Color(0xFFD32F2F)
                                          : const Color(0xFF2E7D32)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(2)),
                  Text(
                    secondarySubtitle,
                    style: TextStyle(
                      color: !hasLocation && !_isLoadingLocation
                          ? const Color(0xFFE65100)
                          : AppColors.grayFont,
                      fontSize: Responsive.sp(11),
                      fontWeight: !hasLocation && !_isLoadingLocation
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.w(8)),

            // 3. Right Action: "Use GPS" quick button (when in manual) OR "Enable" quick action OR chevron
            if (hasManual)
              GestureDetector(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isLoadingLocation = true);
                  final pos = await LocationService.switchToLiveGps();
                  if (pos != null) {
                    _liveGpsAddress =
                        await LocationService.getAddressFromCoordinates(
                          pos.latitude,
                          pos.longitude,
                        );
                  }
                  if (mounted) {
                    setState(() => _isLoadingLocation = false);
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.gps_fixed,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('Switched back to Live GPS Location'),
                          ],
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(10),
                    vertical: Responsive.h(6),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(Responsive.w(14)),
                    border: Border.all(
                      color: const Color(0xFFA5D6A7),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.my_location,
                        size: 12,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: Responsive.w(4)),
                      Text(
                        'Use GPS',
                        style: TextStyle(
                          color: const Color(0xFF2E7D32),
                          fontSize: Responsive.sp(11),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (!hasLocation && !_isLoadingLocation)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(10),
                  vertical: Responsive.h(6),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(Responsive.w(14)),
                  border: Border.all(color: const Color(0xFFFFCC80), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.settings,
                      size: 12,
                      color: Color(0xFFE65100),
                    ),
                    SizedBox(width: Responsive.w(4)),
                    Text(
                      'Enable',
                      style: TextStyle(
                        color: const Color(0xFFE65100),
                        fontSize: Responsive.sp(11),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLocationRequiredSheet() {
    if (_isPromptOpen || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _isPromptOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            _isPromptOpen = false;
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(24),
              vertical: Responsive.h(20),
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(Responsive.w(28)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: Responsive.w(40),
                      height: Responsive.h(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(Responsive.w(2)),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(20)),

                  // Visual Icon Badge
                  Container(
                    width: Responsive.w(68),
                    height: Responsive.w(68),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFE0B2),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.location_off_rounded,
                        color: const Color(0xFFE65100),
                        size: Responsive.w(34),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // Title
                  CustomText.header(
                    'Location Access Needed',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.h(8)),

                  // Explanatory Body Text
                  CustomText.body(
                    'To display nearby stores, bus routes, public toilets, and deliver your orders accurately, please enable device GPS or choose your location manually.',
                    fontSize: 13,
                    color: AppColors.grayFont,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.h(24)),

                  // Action Button 1: Enable GPS / Open Settings
                  BouncingButton(
                    onTap: () async {
                      Navigator.pop(ctx);
                      _isPromptOpen = false;
                      await LocationService.openAppropriateSettings();
                    },
                    child: Container(
                      width: double.infinity,
                      height: Responsive.h(50),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(Responsive.w(25)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            color: Colors.white,
                            size: Responsive.w(20),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          Text(
                            'Enable Device GPS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: Responsive.sp(14),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(12)),

                  // Action Button 2: Select Manually
                  BouncingButton(
                    onTap: () async {
                      if (_isNavigating) return;
                      _isNavigating = true;
                      Navigator.pop(ctx);
                      _isPromptOpen = false;
                      try {
                        final result = await Navigator.pushNamed(
                          context,
                          RouteConstants.pickLocation,
                          arguments: {
                            'initialLatLng': null,
                            'initialAddress': null,
                            'isLiveGps': false,
                          },
                        );
                        if (result is Map<String, dynamic> && mounted) {
                          if (result['latLng'] != null &&
                              result['address'] != null) {
                            final latLng = result['latLng'] as LatLng;
                            final addr = result['address'] as String;
                            await HiveService.setManualLocation(
                              latitude: latLng.latitude,
                              longitude: latLng.longitude,
                              address: addr,
                            );
                          }
                          _checkAndPromptLocation(showPromptIfMissing: false);
                        }
                      } finally {
                        _isNavigating = false;
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: Responsive.h(50),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(Responsive.w(25)),
                        border: Border.all(
                          color: const Color(0xFFFFCC80),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_rounded,
                            color: const Color(0xFFE65100),
                            size: Responsive.w(20),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          Text(
                            'Select Location Manually',
                            style: TextStyle(
                              color: const Color(0xFFE65100),
                              fontSize: Responsive.sp(14),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(10)),

                  // Text Button: Not Now
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _isPromptOpen = false;
                    },
                    child: Text(
                      'Not Now',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: Responsive.sp(13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isPromptOpen = false;
    });
  }
}
