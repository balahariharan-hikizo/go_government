import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../constants/route_constants.dart';
import '../../hive/hive_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _checkSavedSession() {
    if (HiveService.userPhone.isNotEmpty) {
      _phoneController.text = HiveService.userPhone;
    }
  }

  void _requestOtp() {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    context.read<AuthBloc>().add(SendOtpEvent(phone));
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is OtpSentState) {
          if (ModalRoute.of(context)?.isCurrent == true) {
            Navigator.of(context).pushNamed(
              RouteConstants.otp,
              arguments: {'phone': state.phone, 'testOtp': state.otp},
            );
          }
        } else if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.screenColor,
        body: CommonBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(24)),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: Responsive.h(32)),

                    // Top Civic Brand Badge
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Responsive.w(20)),
                          border: Border.all(color: AppColors.outliner),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, color: AppColors.primary, size: 16),
                            SizedBox(width: Responsive.w(6)),
                            CustomText.title(
                              'CIVIC COMMERCE PARTNER',
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(28)),

                    // Emblem & Storefront Icon Hero
                    Center(
                      child: Container(
                        width: Responsive.w(90),
                        height: Responsive.w(90),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.outliner, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: Responsive.w(70),
                            height: Responsive.w(70),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(24)),

                    // Titles
                    Center(
                      child: CustomText.header(
                        'Merchant Partner Portal',
                        fontSize: 22,
                        color: AppColors.black,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    Center(
                      child: CustomText.body(
                        'Enter your registered mobile number to manage your municipal supply outlet and civic orders',
                        fontSize: 13,
                        color: AppColors.grayFont,
                        textAlign: TextAlign.center,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: Responsive.h(36)),

                    // Mobile Number Input Card
                    Container(
                      padding: EdgeInsets.all(Responsive.w(20)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(20)),
                        border: Border.all(color: AppColors.outliner),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.title('Merchant Mobile Number', fontSize: 13, color: AppColors.black),
                          SizedBox(height: Responsive.h(10)),

                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            style: TextStyle(
                              fontSize: Responsive.sp(16),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: AppColors.black,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length != 10) {
                                return 'Enter a valid 10-digit mobile number';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '98765 43210',
                              hintStyle: TextStyle(
                                fontSize: Responsive.sp(14),
                                color: AppColors.grayFont.withValues(alpha: 0.5),
                                letterSpacing: 1.0,
                              ),
                              prefixIcon: Padding(
                                padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                    SizedBox(width: Responsive.w(6)),
                                    CustomText.title('+91', fontSize: 14, color: AppColors.black),
                                    SizedBox(width: Responsive.w(8)),
                                    Container(width: 1, height: 20, color: AppColors.outliner),
                                  ],
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.screenColor,
                              contentPadding: EdgeInsets.symmetric(vertical: Responsive.h(14)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(Responsive.w(12)),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(Responsive.w(12)),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.h(24)),

                    // Continue / Get OTP Button
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;

                        return SizedBox(
                          width: double.infinity,
                          height: Responsive.h(52),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _requestOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Responsive.w(16)),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CustomText.title('Get Verification Code', fontSize: 15, color: Colors.white),
                                      SizedBox(width: Responsive.w(8)),
                                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: Responsive.h(32)),

                    // Security Banner
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.grayFont),
                          SizedBox(width: Responsive.w(6)),
                          CustomText.body(
                            'Secured by Government Single Sign-On Gateway',
                            fontSize: 11,
                            color: AppColors.grayFont,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.h(24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
