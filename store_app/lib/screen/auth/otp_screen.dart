import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/store/store_bloc.dart';
import '../../bloc/store/store_event.dart';
import '../../bloc/store/store_state.dart';
import '../../constants/route_constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String? testOtp;

  const OtpScreen({
    super.key,
    required this.phone,
    this.testOtp,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 30;
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
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _resendOtp() {
    if (!_canResend) return;
    for (var c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    context.read<AuthBloc>().add(SendOtpEvent(widget.phone));
    _startTimer();
  }

  void _verifyOtp() {
    final otp = _otpCode.trim();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 4-digit code'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(VerifyOtpEvent(widget.phone, otp));
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthSuccessState) {
              // Successfully verified OTP. Check if store profile already exists
              context.read<StoreBloc>().add(FetchMyStoreEvent(state.userId));
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
        ),
        BlocListener<StoreBloc, StoreState>(
          listener: (context, state) {
            if (state is StoreLoaded) {
              if (state.store.status == 'approved') {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  RouteConstants.storeDashboard,
                  (route) => false,
                  arguments: {'store': state.store},
                );
              } else {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  RouteConstants.applicationStatus,
                  (route) => false,
                  arguments: {'store': state.store, 'justSubmitted': false},
                );
              }
            } else if (state is StoreNotFound) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                RouteConstants.registerStore,
                (route) => false,
                arguments: {'initialPhone': widget.phone},
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.screenColor,
        appBar: AppBar(
          backgroundColor: AppColors.screenColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: CommonBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(24)),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: Responsive.h(16)),

                  // Shield Icon
                  Container(
                    width: Responsive.w(80),
                    height: Responsive.w(80),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outliner, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 36),
                    ),
                  ),
                  SizedBox(height: Responsive.h(24)),

                  // Title & Mobile Subtitle
                  CustomText.header('Verify Mobile Number', fontSize: 22, color: AppColors.black),
                  SizedBox(height: Responsive.h(8)),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: Responsive.sp(13),
                        color: AppColors.grayFont,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Enter the 4-digit code sent to\n'),
                        TextSpan(
                          text: '+91 ${widget.phone}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.black),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.h(36)),

                  // 4 OTP Box Cells
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) => _buildOtpBox(index)),
                  ),
                  SizedBox(height: Responsive.h(32)),

                  // Resend Timer Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomText.body(
                        _canResend ? "Didn't receive code? " : 'Resend code in ',
                        fontSize: 13,
                        color: AppColors.grayFont,
                      ),
                      if (!_canResend)
                        CustomText.title(
                          '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                          fontSize: 13,
                          color: AppColors.primary,
                        )
                      else
                        GestureDetector(
                          onTap: _resendOtp,
                          child: CustomText.title(
                            'Resend Code',
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(36)),

                  // Verify Button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      return BlocBuilder<StoreBloc, StoreState>(
                        builder: (context, storeState) {
                          final isLoading = authState is AuthLoading || storeState is StoreLoading;

                          return SizedBox(
                            width: double.infinity,
                            height: Responsive.h(52),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _verifyOtp,
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
                                        const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                        SizedBox(width: Responsive.w(8)),
                                        CustomText.title('Verify & Proceed', fontSize: 15, color: Colors.white),
                                      ],
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  SizedBox(height: Responsive.h(24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: Responsive.w(60),
      height: Responsive.w(64),
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(6)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(
          color: _controllers[index].text.isNotEmpty ? AppColors.primary : AppColors.outliner,
          width: _controllers[index].text.isNotEmpty ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: TextStyle(
            fontSize: Responsive.sp(22),
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (index < 3) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
                _verifyOtp();
              }
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            setState(() {});
          },
        ),
      ),
    );
  }
}
