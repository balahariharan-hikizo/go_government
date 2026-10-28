import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../constants/route_constants.dart';
import '../../hive/hive_service.dart';



class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final bool isOtpComplete = _otpCode.length == 4;

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            if (state.isNewUser) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Verification successful! Please complete your registration.'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.of(context).pushNamedAndRemoveUntil(
                RouteConstants.editProfile,
                (route) => false,
                arguments: {'isRegistration': true},
              );
            } else {
              final welcomeName = HiveService.userName.isNotEmpty ? ', ${HiveService.userName}' : '';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Welcome back$welcomeName!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              final targetRoute = HiveService.hasSeenPermissionScreen
                  ? RouteConstants.main
                  : RouteConstants.permission;
              Navigator.of(context).pushNamedAndRemoveUntil(
                targetRoute,
                (route) => false,
              );
            }
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red,
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
                SizedBox(height: Responsive.h(16)),
                // Back Button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
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
                SizedBox(height: Responsive.h(40)),

                // Header
                CustomText.header(
                  'OTP Verification',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: Responsive.h(8)),
                Text.rich(
                  TextSpan(
                    text: 'We have sent a 4-digit verification code to ',
                    style: TextStyle(
                      fontSize: Responsive.sp(13),
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: '+91\u{00A0}${widget.phoneNumber}',
                        style: TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: Responsive.sp(13),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(36)),

                // OTP Digits Input Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    return Container(
                      width: Responsive.w(64),
                      height: Responsive.w(64),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(16)),
                        border: Border.all(
                          color: _controllers[index].text.isNotEmpty
                              ? AppColors.primary
                              : AppColors.outliner,
                          width: Responsive.w(1.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        style: TextStyle(
                          fontSize: Responsive.sp(20),
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            if (index < 3) {
                              _focusNodes[index + 1].requestFocus();
                            } else {
                              _focusNodes[index].unfocus();
                            }
                          } else {
                            if (index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          }
                          setState(() {});
                        },
                      ),
                    );
                  }),
                ),
                SizedBox(height: Responsive.h(32)),

                // Timer & Resend Button
                Center(
                  child: _canResend
                      ? GestureDetector(
                          onTap: () {
                            _startTimer();
                            context
                                .read<AuthBloc>()
                                .add(SendOtpEvent(widget.phoneNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('OTP resent successfully!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(
                            'Resend OTP',
                            style: TextStyle(
                              fontSize: Responsive.sp(14),
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Text(
                          'Resend OTP in ${_secondsRemaining.toString().padLeft(2, '0')}s',
                          style: TextStyle(
                            fontSize: Responsive.sp(13),
                            color: Colors.grey.shade500,
                          ),
                        ),
                ),
                SizedBox(height: Responsive.h(48)),

                // Verify Button
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final bool isLoading = state is AuthLoading;
                    return GestureDetector(
                      onTap: (isOtpComplete && !isLoading)
                          ? () {
                              context.read<AuthBloc>().add(
                                    VerifyOtpEvent(widget.phoneNumber, _otpCode),
                                  );
                            }
                          : null,
                      child: Container(
                        width: double.infinity,
                        height: Responsive.h(52),
                        decoration: BoxDecoration(
                          color: isOtpComplete ? AppColors.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(Responsive.w(26)),
                          boxShadow: isOtpComplete
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
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              )
                            : CustomText.title(
                                'Verify & Proceed',
                                color: isOtpComplete ? Colors.white : Colors.grey.shade500,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                      ),
                    );
                  },
                ),

              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

