import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../constants/route_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isValidPhone = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {
        _isValidPhone = _phoneController.text.length == 10;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OtpSent) {
            if (ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).pushNamed(
                RouteConstants.otp,
                arguments: state.phone,
              );
            }
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: CommonBackground(

        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: Responsive.h(40)),
                // Logo & App Name Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: Responsive.w(80),
                        height: Responsive.w(80),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: Icon(
                          Icons.gavel_rounded,
                          color: AppColors.primary,
                          size: Responsive.w(40),
                        ),
                      ),
                      SizedBox(height: Responsive.h(16)),
                      CustomText.header(
                        'GoGovernment',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: Responsive.h(4)),
                      CustomText.subtitle(
                        'Citizen Empowerment Platform',
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(60)),

                // Login Form Card
                CustomText.header(
                  'Welcome Back',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: Responsive.h(8)),
                CustomText.subtitle(
                  'Enter your mobile number to sign in or create a new account.',
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
                SizedBox(height: Responsive.h(28)),

                // Phone Input Field
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(Responsive.w(16)),
                    border: Border.all(
                      color: _isValidPhone ? AppColors.primary : AppColors.outliner,
                      width: Responsive.w(1.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(16),
                    vertical: Responsive.h(4),
                  ),
                  child: Row(
                    children: [
                      // Country Code prefix
                      Text(
                        '+91',
                        style: TextStyle(
                          fontSize: Responsive.sp(16),
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      SizedBox(width: Responsive.w(12)),
                      Container(
                        width: 1,
                        height: Responsive.h(24),
                        color: AppColors.outliner,
                      ),
                      SizedBox(width: Responsive.w(12)),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: const InputDecoration(
                            hintText: 'Enter 10-digit mobile number',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          style: TextStyle(
                            fontSize: Responsive.sp(15),
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(32)),

                // Continue Button
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final bool isLoading = state is AuthLoading;
                    return GestureDetector(
                      onTap: (_isValidPhone && !isLoading)
                          ? () {
                              context.read<AuthBloc>().add(
                                    SendOtpEvent(_phoneController.text),
                                  );
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: Responsive.h(52),
                        decoration: BoxDecoration(
                          color: _isValidPhone ? AppColors.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(Responsive.w(26)),
                          boxShadow: _isValidPhone
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: isLoading
                            ? SizedBox(
                                width: Responsive.w(20),
                                height: Responsive.w(20),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : CustomText.title(
                                'Get OTP',
                                color: _isValidPhone ? Colors.white : Colors.grey.shade500,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                      ),
                    );
                  },
                ),

                SizedBox(height: Responsive.h(40)),

                // Terms & Privacy Agreement Text at bottom
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                    child: Text.rich(
                      TextSpan(
                        text: 'By continuing, you agree to our ',
                        style: TextStyle(
                          fontSize: Responsive.sp(11),
                          color: Colors.grey.shade500,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: Responsive.h(20)),
              ],
            ),
          ),
        ),
      ),)
    );
  }
}

