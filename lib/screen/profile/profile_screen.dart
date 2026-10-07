import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/custom_text.dart';
import '../../constants/route_constants.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';
import '../../network/api_client.dart';
import '../../network/feedback_api_service.dart';
import '../../hive/hive_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileBloc>().add(FetchProfileEvent());
      }
    });
  }

  void _showRatingDialog(BuildContext context) {
    int selectedRating = 5;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Responsive.w(24)),
              ),
              child: Padding(
                padding: EdgeInsets.all(Responsive.w(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: Responsive.w(54),
                      height: Responsive.w(54),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF2EC),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: AppColors.primary,
                        size: Responsive.w(32),
                      ),
                    ),
                    SizedBox(height: Responsive.h(12)),
                    CustomText.header(
                      'Rate GoGovernment',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Responsive.h(6)),
                    CustomText.subtitle(
                      'How has your experience been so far?',
                      fontSize: 13,
                      color: AppColors.grayFont,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Responsive.h(16)),
                    // 5 Stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        final isFilled = starIndex <= selectedRating;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedRating = starIndex;
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: Responsive.w(4)),
                            child: Icon(
                              isFilled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: isFilled
                                  ? const Color(0xFFFFB300)
                                  : Colors.grey.shade400,
                              size: Responsive.w(32),
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: Responsive.h(16)),
                    // Optional feedback box
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius:
                            BorderRadius.circular(Responsive.w(12)),
                        border: Border.all(
                            color: AppColors.outliner, width: 1.2),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: Responsive.w(12)),
                      child: TextField(
                        controller: feedbackController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Share your thoughts (Optional)',
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(20)),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              height: Responsive.h(44),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius:
                                    BorderRadius.circular(Responsive.w(22)),
                                border: Border.all(
                                  color: AppColors.grayFont
                                      .withValues(alpha: 0.5),
                                  width: Responsive.w(1.2),
                                ),
                              ),
                              child: Center(
                                child: CustomText.title(
                                  'Not Now',
                                  color: AppColors.grayFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final text = feedbackController.text.trim();
                              FeedbackApiService.submitFeedback(
                                userId: HiveService.userId.isNotEmpty ? HiveService.userId : 'USER_GUEST',
                                userName: HiveService.userName.isNotEmpty ? HiveService.userName : 'Citizen',
                                phone: HiveService.userPhone,
                                type: 'app_rating',
                                rating: selectedRating.toDouble(),
                                comments: text,
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Thank you for rating us $selectedRating stars!'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        Responsive.w(12)),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              height: Responsive.h(44),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius:
                                    BorderRadius.circular(Responsive.w(22)),
                              ),
                              child: Center(
                                child: CustomText.title(
                                  'Submit',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(28)),
          ),
          child: Padding(
            padding: EdgeInsets.all(Responsive.w(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText.header(
                  'Are you sure you want to log out of your account?',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  textAlign: TextAlign.center,
                  height: 1.4,
                ),
                SizedBox(height: Responsive.h(24)),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: Responsive.h(44),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(22)),
                            border: Border.all(
                              color: AppColors.grayFont.withValues(alpha: 0.5),
                              width: Responsive.w(1.2),
                            ),
                          ),
                          child: Center(
                            child: CustomText.title(
                              'Cancel',
                              color: AppColors.grayFont,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.w(12)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.read<AuthBloc>().add(LogoutEvent());
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Logged out successfully!'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Responsive.w(12)),
                              ),
                            ),
                          );
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            RouteConstants.login,
                            (route) => false,
                          );
                        },
                        child: Container(
                          height: Responsive.h(44),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(22)),
                            border: Border.all(
                              color: AppColors.primary,
                              width: Responsive.w(1.2),
                            ),
                          ),
                          child: Center(
                            child: CustomText.title(
                              'Log Out',
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(28)),
          ),
          child: Padding(
            padding: EdgeInsets.all(Responsive.w(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText.header(
                  'Are you sure you want to delete your account?',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  textAlign: TextAlign.center,
                  height: 1.4,
                ),
                SizedBox(height: Responsive.h(24)),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: Responsive.h(44),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(22)),
                            border: Border.all(
                              color: AppColors.grayFont.withValues(alpha: 0.5),
                              width: Responsive.w(1.2),
                            ),
                          ),
                          child: Center(
                            child: CustomText.title(
                              'Cancel',
                              color: AppColors.grayFont,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.w(12)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.read<AuthBloc>().add(LogoutEvent());
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Account deleted successfully!'),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Responsive.w(12)),
                              ),
                            ),
                          );
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            RouteConstants.login,
                            (route) => false,
                          );
                        },
                        child: Container(
                          height: Responsive.h(44),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(22)),
                            border: Border.all(
                              color: AppColors.error,
                              width: Responsive.w(1.2),
                            ),
                          ),
                          child: Center(
                            child: CustomText.title(
                              'Delete Account',
                              color: AppColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final String name = state.name;
        final String email = state.email;
        final String phone = state.phone;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full width curved header with reserved layout height
            SizedBox(
              height: Responsive.h(244),
              child: Transform.translate(
                offset: Offset(0, -Responsive.h(16)),
                child: OverflowBox(
                  maxWidth: screenWidth,
                  minWidth: screenWidth,
                  child: Container(
                    width: screenWidth,
                    height: Responsive.h(260),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.outliner, // Lighter peach/orange on the left
                          AppColors.primary,  // Darker orange-red on the right
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(Responsive.w(36)),
                        bottomRight: Radius.circular(Responsive.w(36)),
                      ),
                    ),
                    padding: EdgeInsets.only(
                      top: Responsive.h(16),
                      left: Responsive.w(20),
                      right: Responsive.w(20),
                    ),
                    child: Column(
                      children: [
                        // App bar items
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CustomText.header(
                              'Profile',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            // Rounded Edit Profile button
                            GestureDetector(
                              onTap: () async {
                                final res = await Navigator.of(context).pushNamed(
                                  RouteConstants.editProfile,
                                  arguments: {
                                    'initialName': name,
                                    'initialEmail': email,
                                    'initialImagePath': state.imagePath,
                                  },
                                );
                                if (res != null && res is Map<String, dynamic>) {
                                  if (!context.mounted) return;
                                  context.read<ProfileBloc>().add(
                                        UpdateProfileEvent(
                                          res['name'] as String,
                                          res['email'] as String,
                                          res['imagePath'] as String?,
                                        ),
                                      );
                                }
                              },
                              child: Container(
                                width: Responsive.w(40),
                                height: Responsive.w(40),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.black,
                                  size: Responsive.w(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.h(10)),
                        // Avatar or First Letter Initial / Guide Icon
                        Builder(
                          builder: (context) {
                            final String normalizedPath = ApiClient.normalizeImageUrl(state.imagePath);
                            final bool isNetwork = normalizedPath.startsWith('http://') ||
                                normalizedPath.startsWith('https://');
                            final bool isLocalFile = !isNetwork &&
                                normalizedPath.isNotEmpty &&
                                File(normalizedPath).existsSync();
                            final bool hasImage = isNetwork || isLocalFile;
                            final bool hasName = name.trim().isNotEmpty;
                            final String initialLetter = hasName
                                ? name.trim()[0].toUpperCase()
                                : '';

                            Widget fallbackAvatar() => Center(
                                  child: hasName
                                      ? Text(
                                          initialLetter,
                                          style: TextStyle(
                                            fontSize: Responsive.sp(32),
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontFamily: 'Valley Sans',
                                          ),
                                        )
                                      : Icon(
                                          Icons.person_outline_rounded,
                                          size: Responsive.w(38),
                                          color: AppColors.primary,
                                        ),
                                );

                            return Container(
                              width: Responsive.w(80),
                              height: Responsive.w(80),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white,
                                  width: Responsive.w(2.5),
                                ),
                                color: hasImage ? Colors.transparent : Colors.white,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: isNetwork
                                    ? Image.network(
                                        normalizedPath,
                                        width: Responsive.w(80),
                                        height: Responsive.w(80),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) => fallbackAvatar(),
                                      )
                                    : (isLocalFile
                                        ? Image.file(
                                            File(normalizedPath),
                                            width: Responsive.w(80),
                                            height: Responsive.w(80),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stack) => fallbackAvatar(),
                                          )
                                        : fallbackAvatar()),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: Responsive.h(10)),
                        CustomText.header(
                          name.trim().isNotEmpty ? name : 'Set Up Your Profile',
                          fontSize: name.trim().isNotEmpty ? 20 : 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        SizedBox(height: Responsive.h(2)),
                        CustomText.subtitle(
                          email.trim().isNotEmpty ? email : 'Tap the edit icon to add details',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: Responsive.h(12)),

            // Menu Options list
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileOption(
                      icon: Icons.phone_outlined,
                      title: phone.trim().isNotEmpty ? phone : 'Add Phone Number',
                      onTap: () async {
                        final res = await Navigator.of(context).pushNamed(
                          RouteConstants.editPhone,
                          arguments: phone,
                        );
                        if (res != null && res is String) {
                          if (!context.mounted) return;
                          context.read<ProfileBloc>().add(UpdatePhoneEvent(res));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Phone number updated successfully!'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Responsive.w(12)),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    SizedBox(height: Responsive.h(10)),
                    _buildProfileOption(
                      icon: Icons.map_outlined,
                      title: 'Address Book',
                      onTap: () async {
                        await Navigator.of(context).pushNamed(RouteConstants.addressBook);
                      },
                    ),
                    SizedBox(height: Responsive.h(6)),
                    _buildProfileOption(
                      icon: Icons.receipt_long_outlined,
                      title: 'Your Orders',
                      onTap: () {
                        Navigator.of(context).pushNamed(RouteConstants.yourOrders);
                      },
                    ),
                    SizedBox(height: Responsive.h(6)),
                    _buildProfileOption(
                      icon: Icons.favorite_outline,
                      title: 'Wishlist',
                      onTap: () {
                        Navigator.of(context).pushNamed(RouteConstants.wishlist);
                      },
                    ),
                    SizedBox(height: Responsive.h(6)),
                    _buildProfileOption(
                      icon: Icons.translate_outlined,
                      title: 'Language',
                      onTap: () {
                        Navigator.of(context).pushNamed(RouteConstants.selectLanguage);
                      },
                    ),
                    SizedBox(height: Responsive.h(6)),
                    _buildProfileOption(
                      icon: Icons.star_outline,
                      title: 'Rate Us',
                      onTap: () => _showRatingDialog(context),
                    ),
                    SizedBox(height: Responsive.h(6)),
                    _buildProfileOption(
                      icon: Icons.logout_outlined,
                      title: 'Logout',
                      onTap: () => _showLogoutDialog(context),
                    ),
                    SizedBox(height: Responsive.h(6)),
                    _buildProfileOption(
                      icon: Icons.delete_outline,
                      title: 'Delete',
                      onTap: () => _showDeleteDialog(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    Color color = AppColors.black,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(16)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(color: AppColors.outliner, width: Responsive.w(1.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: Responsive.w(24)),
                SizedBox(width: Responsive.w(16)),
                CustomText.title(title, fontSize: 15, color: color, fontWeight: FontWeight.w500),
              ],
            ),
            Icon(Icons.chevron_right_outlined, color: color.withValues(alpha: 0.5), size: Responsive.w(24)),
          ],
        ),
      ),
    );
  }
}
