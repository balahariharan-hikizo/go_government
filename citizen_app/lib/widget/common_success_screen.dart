import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/responsive_helper.dart';
import 'custom_text.dart';
import 'common_background.dart';

class CommonSuccessScreen extends StatefulWidget {
  final double amount;
  final String title;
  final String subtitle;
  final String dateString;
  final String buttonText;
  final VoidCallback? onDone;
  final String? nextRoute;
  final dynamic nextRouteArgs;

  const CommonSuccessScreen({
    super.key,
    required this.amount,
    required this.title,
    required this.subtitle,
    required this.dateString,
    this.buttonText = 'Done',
    this.onDone,
    this.nextRoute,
    this.nextRouteArgs,
  });

  @override
  State<CommonSuccessScreen> createState() => _CommonSuccessScreenState();
}

class _CommonSuccessScreenState extends State<CommonSuccessScreen> {
  bool _allowPop = false;

  void _handleDone() {
    if (widget.nextRoute != null) {
      Navigator.pushReplacementNamed(
        context,
        widget.nextRoute!,
        arguments: widget.nextRouteArgs,
      );
      return;
    }
    if (widget.onDone != null) {
      widget.onDone!();
      return;
    }
    setState(() {
      _allowPop = true;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleDone();
      },
      child: Scaffold(
        backgroundColor: AppColors.screenColor,
        body: CommonBackground(
          child: SafeArea(
            child: Stack(
              children: [
                // Top-left custom back chevron icon capsule
                Positioned(
                  top: Responsive.h(10),
                  left: Responsive.w(20),
                  child: GestureDetector(
                    onTap: _handleDone,
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

                // Center success stamp and details
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Orange wavy checkmark badge
                      Image.asset(
                        'assets/images/success.png',
                        width: Responsive.w(76),
                        height: Responsive.w(76),
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: Responsive.h(24)),

                      // Currency label
                      CustomText.header(
                        '₹ ${widget.amount.toStringAsFixed(2)}',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                      SizedBox(height: Responsive.h(16)),

                      // Recipient details
                      CustomText.body(
                        widget.subtitle,
                        fontSize: 12,
                        color: AppColors.grayFont,
                      ),
                      SizedBox(height: Responsive.h(4)),
                      CustomText.title(
                        widget.title,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                      SizedBox(height: Responsive.h(6)),
                      CustomText.body(
                        widget.dateString,
                        fontSize: 11,
                        color: AppColors.grayFont,
                      ),
                    ],
                  ),
                ),

                // Bottom confirmation button
                Positioned(
                  bottom: Responsive.h(30),
                  left: Responsive.w(20),
                  right: Responsive.w(20),
                  child: GestureDetector(
                    onTap: _handleDone,
                    child: Container(
                      height: Responsive.h(48),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(24)),
                        border: Border.all(
                          color: AppColors.outliner,
                          width: Responsive.w(1.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.buttonText,
                          style: const TextStyle(
                            color: Color(0xFFF4511E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
