import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/notification_service.dart';
import '../../hive/hive_service.dart';
import '../../network/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class EditPhoneScreen extends StatefulWidget {
  final String initialPhone;

  const EditPhoneScreen({
    super.key,
    required this.initialPhone,
  });

  @override
  State<EditPhoneScreen> createState() => _EditPhoneScreenState();
}

class _EditPhoneScreenState extends State<EditPhoneScreen> {
  late TextEditingController _phoneController;
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(4, (_) => FocusNode());

  int _step = 1; // 1: Enter Phone, 2: Verify OTP
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  Timer? _timer;
  int _secondsRemaining = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    // Strip "+91", spaces, hyphens to get raw 10 digits if available
    final digitsOnly = widget.initialPhone.replaceAll(RegExp(r'\D'), '');
    final raw10 = digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : '';
    _phoneController = TextEditingController(text: raw10);
    _phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentRawInitial {
    final digitsOnly = widget.initialPhone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : '';
  }

  bool get _isValidPhone {
    final text = _phoneController.text.trim();
    return text.length == 10 && RegExp(r'^\d{10}$').hasMatch(text);
  }

  bool get _isSameAsCurrent {
    final text = _phoneController.text.trim();
    return _currentRawInitial.isNotEmpty && text == _currentRawInitial;
  }

  bool get _canSendOtp {
    return _isValidPhone && !_isSameAsCurrent && !_isSendingOtp;
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();
  bool get _isOtpComplete => _otpCode.length == 4;

  void _handleGetOtpPress() {
    if (_isSendingOtp) return;

    final text = _phoneController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your new mobile number'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isValidPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isSameAsCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a new number (different from your current number)'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _sendOtp();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _canResend = true;
          _secondsRemaining = 0;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
    });

    final newPhone = _phoneController.text.trim();
    final userId = HiveService.citizenId;
    final currentPhone = widget.initialPhone.isNotEmpty
        ? widget.initialPhone
        : HiveService.userPhone;

    final result = await ApiService.sendPhoneUpdateOtp(
      userId: userId,
      newPhone: newPhone,
      currentPhone: currentPhone,
    );

    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
    });

    if (result != null && result['success'] == true) {
      setState(() {
        _step = 2;
      });

      _startTimer();

      final otp = result['otp']?.toString();
      if (otp != null && otp.isNotEmpty) {
        NotificationService.showOtpNotification(otp: otp);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent to +91 $newPhone'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(12)),
          ),
        ),
      );

      // Auto focus first OTP box
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _otpFocusNodes.isNotEmpty) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['message'] ?? 'Failed to send OTP. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(12)),
          ),
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (!_isOtpComplete || _isVerifyingOtp) return;

    setState(() {
      _isVerifyingOtp = true;
    });

    final newPhone = _phoneController.text.trim();
    final userId = HiveService.citizenId;
    final currentPhone = widget.initialPhone.isNotEmpty
        ? widget.initialPhone
        : HiveService.userPhone;

    final result = await ApiService.verifyPhoneUpdateOtp(
      userId: userId,
      newPhone: newPhone,
      otp: _otpCode,
      currentPhone: currentPhone,
    );

    if (!mounted) return;

    setState(() {
      _isVerifyingOtp = false;
    });

    if (result != null && result['success'] == true) {
      final formattedPhone =
          '+91 ${newPhone.substring(0, 5)} ${newPhone.substring(5)}';
      Navigator.pop(context, formattedPhone);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['message'] ?? 'Invalid OTP code. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(12)),
          ),
        ),
      );
    }
  }

  void _backToPhoneInput() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.clear();
    }
    setState(() {
      _step = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: () {
                if (_step == 2) {
                  _backToPhoneInput();
                } else {
                  Navigator.pop(context);
                }
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
          ),
        ),
        title: CustomText.header(
          _step == 1 ? 'Edit Phone Number' : 'Verify OTP',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
        centerTitle: false,
      ),
      body: CommonBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(24)),
            child: _step == 1 ? _buildStep1PhoneInput() : _buildStep2OtpVerification(),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1PhoneInput() {
    final enteredText = _phoneController.text.trim();
    final bool hasStartedTyping = enteredText.isNotEmpty;
    final bool showError = hasStartedTyping && !_isValidPhone;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: Responsive.h(20)),

                // Top Icon Badge
                Center(
                  child: Container(
                    width: Responsive.w(72),
                    height: Responsive.w(72),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF2EC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phone_iphone_rounded,
                      color: AppColors.primary,
                      size: Responsive.w(36),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.h(24)),

                // Header & Subtitle
                CustomText.header(
                  'Update Mobile Number',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: Responsive.h(6)),
                CustomText.subtitle(
                  'Enter your new 10-digit mobile number. We\'ll send a 4-digit verification code to confirm.',
                  fontSize: 13,
                  color: AppColors.grayFont,
                  height: 1.4,
                ),
                SizedBox(height: Responsive.h(20)),

                // Current Phone Card (if available)
                if (widget.initialPhone.trim().isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(16),
                      vertical: Responsive.h(12),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7F2),
                      borderRadius: BorderRadius.circular(Responsive.w(14)),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primary,
                          size: Responsive.w(18),
                        ),
                        SizedBox(width: Responsive.w(10)),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: Responsive.sp(12),
                                color: AppColors.black,
                              ),
                              children: [
                                const TextSpan(text: 'Current registered number: '),
                                TextSpan(
                                  text: widget.initialPhone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.h(20)),
                ],

                // Phone Input Field
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(Responsive.w(16)),
                    border: Border.all(
                      color: showError
                          ? AppColors.error
                          : (_isValidPhone
                              ? AppColors.primary
                              : AppColors.outliner.withValues(alpha: 0.5)),
                      width: Responsive.w(1.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(16),
                    vertical: Responsive.h(4),
                  ),
                  child: Row(
                    children: [
                      // Country code prefix
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
                        width: 1.2,
                        height: Responsive.h(24),
                        color: AppColors.outliner,
                      ),
                      SizedBox(width: Responsive.w(12)),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: TextStyle(
                            fontSize: Responsive.sp(16),
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                            letterSpacing: 1.1,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            hintText: 'Enter 10-digit mobile number',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                      if (_isValidPhone && !_isSameAsCurrent)
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: Responsive.w(20),
                        ),
                    ],
                  ),
                ),

                // Error / Helper text
                if (showError) ...[
                  SizedBox(height: Responsive.h(6)),
                  Padding(
                    padding: EdgeInsets.only(left: Responsive.w(8)),
                    child: CustomText.subtitle(
                      'Please enter a valid 10-digit mobile number (starts with 6-9)',
                      fontSize: 11,
                      color: AppColors.error,
                    ),
                  ),
                ] else if (_isSameAsCurrent) ...[
                  SizedBox(height: Responsive.h(6)),
                  Padding(
                    padding: EdgeInsets.only(left: Responsive.w(8)),
                    child: CustomText.subtitle(
                      'This is already your current registered mobile number',
                      fontSize: 11,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Send OTP CTA Button
        GestureDetector(
          onTap: _handleGetOtpPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: Responsive.h(52),
            margin: EdgeInsets.only(bottom: Responsive.h(20)),
            decoration: BoxDecoration(
              color: _canSendOtp ? AppColors.primary : const Color(0xFFF4EDE8),
              borderRadius: BorderRadius.circular(Responsive.w(26)),
              boxShadow: _canSendOtp
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: _isSendingOtp
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : CustomText.title(
                      'Get OTP',
                      color: _canSendOtp ? Colors.white : const Color(0xFFC0B3AC),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2OtpVerification() {
    final phoneText = _phoneController.text.trim();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: Responsive.h(20)),

                // Top Icon Badge
                Center(
                  child: Container(
                    width: Responsive.w(72),
                    height: Responsive.w(72),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF2EC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.primary,
                      size: Responsive.w(36),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.h(24)),

                // Header
                CustomText.header(
                  'Verify Mobile Number',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: Responsive.h(6)),

                // Subtitle with Phone and Change button
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: Responsive.sp(13),
                            color: AppColors.grayFont,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(text: 'Enter the 4-digit code sent to '),
                            TextSpan(
                              text: '+91 $phoneText',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _backToPhoneInput,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(4)),
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: Responsive.sp(13),
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                          color: _otpControllers[index].text.isNotEmpty
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
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                              _otpFocusNodes[index + 1].requestFocus();
                            } else {
                              _otpFocusNodes[index].unfocus();
                            }
                          } else {
                            if (index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
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
                          onTap: () async {
                            _startTimer();
                            final newPhone = _phoneController.text.trim();
                            final userId = HiveService.citizenId;
                            final currentPhone = widget.initialPhone.isNotEmpty
                                ? widget.initialPhone
                                : HiveService.userPhone;

                            final result = await ApiService.sendPhoneUpdateOtp(
                              userId: userId,
                              newPhone: newPhone,
                              currentPhone: currentPhone,
                            );

                            if (!mounted) return;

                            if (result != null && result['success'] == true) {
                              final otp = result['otp']?.toString();
                              if (otp != null && otp.isNotEmpty) {
                                NotificationService.showOtpNotification(otp: otp);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('OTP resent successfully!'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result?['message'] ?? 'Failed to resend OTP.'),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
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
              ],
            ),
          ),
        ),

        // Verify & Update CTA Button
        GestureDetector(
          onTap: (_isOtpComplete && !_isVerifyingOtp) ? _verifyOtp : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: Responsive.h(52),
            margin: EdgeInsets.only(bottom: Responsive.h(20)),
            decoration: BoxDecoration(
              color: _isOtpComplete ? AppColors.primary : const Color(0xFFF4EDE8),
              borderRadius: BorderRadius.circular(Responsive.w(26)),
              boxShadow: _isOtpComplete
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: _isVerifyingOtp
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : CustomText.title(
                      'Verify & Update',
                      color: _isOtpComplete ? Colors.white : const Color(0xFFC0B3AC),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
