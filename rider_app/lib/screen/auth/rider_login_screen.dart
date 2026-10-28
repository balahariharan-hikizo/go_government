import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/rider_auth_bloc.dart';
import '../../bloc/auth/rider_auth_event.dart';
import '../../bloc/auth/rider_auth_state.dart';
import '../../constants/route_constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class RiderLoginScreen extends StatefulWidget {
  const RiderLoginScreen({super.key});

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onSendOtp() {
    if (_formKey.currentState!.validate()) {
      final phone = '+91${_phoneController.text.trim()}';
      context.read<RiderAuthBloc>().add(SendRiderOtpEvent(phone));
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      body: BlocConsumer<RiderAuthBloc, RiderAuthState>(
        listener: (context, state) {
          if (state is RiderOtpSentState) {
            if (ModalRoute.of(context)?.isCurrent == true) {
              Navigator.pushNamed(
                context,
                RouteConstants.otp,
                arguments: {
                  'phone': state.phone,
                  'otp': state.otp,
                },
              );
            }
          } else if (state is RiderAuthFailureState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is RiderAuthLoading;

          return CommonBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(24)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: Responsive.h(40)),
                      
                      // Hero Icon & Badge
                      Center(
                        child: Container(
                          width: Responsive.w(90),
                          height: Responsive.w(90),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.outliner],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(24)),

                      Center(
                        child: CustomText.heading(
                          'GoGovernment Rider',
                          fontSize: Responsive.sp(24),
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      SizedBox(height: Responsive.h(6)),
                      Center(
                        child: CustomText.body(
                          'Delivery Partner Portal · Fast & Reliable',
                          fontSize: Responsive.sp(13),
                          color: AppColors.grayFont,
                        ),
                      ),
                      SizedBox(height: Responsive.h(48)),

                      CustomText.title(
                        'Mobile Number',
                        fontSize: Responsive.sp(15),
                        fontWeight: FontWeight.w600,
                      ),
                      SizedBox(height: Responsive.h(8)),

                      // Phone Input Field
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(14)),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(14),
                          vertical: Responsive.h(4),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '🇮🇳 +91',
                              style: TextStyle(
                                fontSize: Responsive.sp(15),
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                            SizedBox(width: Responsive.w(12)),
                            Container(
                              width: 1,
                              height: Responsive.h(24),
                              color: AppColors.border,
                            ),
                            SizedBox(width: Responsive.w(12)),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: const InputDecoration(
                                  hintText: 'Enter 10-digit number',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: AppColors.grayFont),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().length != 10) {
                                    return 'Please enter a valid 10-digit phone number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.h(32)),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: Responsive.h(52),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _onSendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Responsive.w(14)),
                            ),
                            elevation: 3,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Send OTP',
                                  style: TextStyle(
                                    fontSize: Responsive.sp(16),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(24)),

                      // Features summary card
                      Container(
                        padding: EdgeInsets.all(Responsive.w(16)),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(Responsive.w(14)),
                          border: Border.all(color: AppColors.outliner.withOpacity(0.4)),
                        ),
                        child: Column(
                          children: [
                            _featureRow(Icons.wallet_outlined, 'Per-order instant payouts & incentives'),
                            SizedBox(height: Responsive.h(10)),
                            _featureRow(Icons.verified_outlined, 'Direct contact with citizens & government stores'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: Responsive.w(18), color: AppColors.primary),
        SizedBox(width: Responsive.w(10)),
        Expanded(
          child: CustomText.body(
            text,
            fontSize: Responsive.sp(12.5),
            color: AppColors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
