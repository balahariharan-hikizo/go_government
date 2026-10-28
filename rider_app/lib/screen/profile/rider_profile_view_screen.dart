import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/rider_auth_bloc.dart';
import '../../bloc/auth/rider_auth_event.dart';
import '../../bloc/auth/rider_auth_state.dart';
import '../../bloc/delivery/delivery_bloc.dart';
import '../../bloc/delivery/delivery_event.dart';
import '../../constants/route_constants.dart';
import '../../hive/hive_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../widget/rider_bottom_nav_bar.dart';

class RiderProfileViewScreen extends StatelessWidget {
  const RiderProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushNamedAndRemoveUntil(context, RouteConstants.dashboard, (route) => false);
        }
      },
      child: BlocListener<RiderAuthBloc, RiderAuthState>(
        listener: (context, state) {
          if (state is RiderAuthInitial) {
            Navigator.pushNamedAndRemoveUntil(context, RouteConstants.login, (route) => false);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: CustomText.title('Rider Profile', fontWeight: FontWeight.bold),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushNamedAndRemoveUntil(context, RouteConstants.dashboard, (route) => false);
                }
              },
            ),
          ),
        body: CommonBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.w(18)),
              child: Column(
                children: [
                  // Profile Avatar & Name
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: Responsive.w(36),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: const Icon(Icons.two_wheeler_rounded, size: 40, color: AppColors.primary),
                        ),
                        SizedBox(height: Responsive.h(12)),
                        CustomText.heading(
                          HiveService.userName.isNotEmpty ? HiveService.userName : 'Partner Rider',
                          fontSize: Responsive.sp(18),
                        ),
                        CustomText.body(HiveService.userPhone, fontSize: Responsive.sp(13)),
                        SizedBox(height: Responsive.h(6)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(3)),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(Responsive.w(10)),
                          ),
                          child: const Text(
                            '✓ Verified Government Delivery Partner',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.h(24)),

                  // Vehicle Details Card
                  _sectionTitle('Vehicle & Partner Info'),
                  SizedBox(height: Responsive.h(8)),
                  _infoTile(Icons.pedal_bike_rounded, 'Vehicle Category', HiveService.vehicleType),
                  _infoTile(Icons.confirmation_number_outlined, 'Vehicle Plate Number', HiveService.vehicleNumber.isNotEmpty ? HiveService.vehicleNumber : 'Not Provided'),
                  _infoTile(Icons.fingerprint_rounded, 'Rider ID', HiveService.userId.isNotEmpty ? HiveService.userId : 'Not Assigned'),
                  SizedBox(height: Responsive.h(20)),

                  // Preferences & Duty
                  _sectionTitle('Duty Preferences'),
                  SizedBox(height: Responsive.h(8)),
                  Container(
                    padding: EdgeInsets.all(Responsive.w(14)),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(Responsive.w(14)),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText.title('Online Duty Status', fontSize: Responsive.sp(14)),
                            CustomText.caption('Receive order delivery alerts nearby', color: AppColors.grayFont),
                          ],
                        ),
                        Switch(
                          value: HiveService.isOnline,
                          activeThumbColor: AppColors.success,
                          onChanged: (val) {
                            context.read<DeliveryBloc>().add(ToggleDutyEvent(val));
                            (context as Element).markNeedsBuild();
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.h(24)),

                  // Support & Logout
                  _sectionTitle('Settings & Account'),
                  SizedBox(height: Responsive.h(8)),
                  _actionTile(
                    Icons.headset_mic_outlined,
                    'Government Dispatcher Helpdesk',
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Helpdesk hotline: 1800-425-0012 (Toll Free)')),
                      );
                    },
                  ),
                  SizedBox(height: Responsive.h(10)),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: Responsive.h(50),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showLogoutDialog(context);
                      },
                      icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                      label: const Text(
                        'Log Out of Rider App',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(20)),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: const RiderBottomNavBar(currentIndex: 2),
      ),
    ),
  );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: CustomText.caption(
        title.toUpperCase(),
        fontWeight: FontWeight.bold,
        color: AppColors.grayFont,
        fontSize: 11,
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(8)),
      padding: EdgeInsets.all(Responsive.w(14)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          SizedBox(width: Responsive.w(12)),
          Expanded(child: CustomText.body(label, fontSize: Responsive.sp(13))),
          CustomText.title(value, fontSize: Responsive.sp(13), fontWeight: FontWeight.bold),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Responsive.w(14)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(12)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            SizedBox(width: Responsive.w(12)),
            Expanded(child: CustomText.title(label, fontSize: Responsive.sp(13))),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.grayFont),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the GoGovernment Rider App?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RiderAuthBloc>().add(RiderLogoutEvent());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
