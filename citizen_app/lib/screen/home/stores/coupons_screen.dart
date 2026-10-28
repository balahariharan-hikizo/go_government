import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';

class CouponsScreen extends StatefulWidget {
  final String? currentCouponCode;

  const CouponsScreen({
    super.key,
    this.currentCouponCode,
  });

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final TextEditingController _couponController = TextEditingController();
  String _inputText = '';
  String? _selectedCouponCode;

  final List<Map<String, dynamic>> _coupons = [
    {
      'code': 'GETOFF120ON649',
      'discount': 120,
      'title': 'Flat ₹120 OFF',
      'desc': 'Save ₹120.00 with this code',
    },
    {
      'code': 'GETOFF000N199',
      'discount': 160,
      'title': 'Flat ₹160 OFF',
      'desc': 'Save ₹160.00 with this code',
    },
    {
      'code': 'FREE_DELIVERY',
      'discount': 25,
      'title': 'Free Delivery Coupon',
      'desc': 'Get free delivery on your order',
    },
    {
      'code': 'GOVERNMENT10',
      'discount': 50,
      'title': 'GOV Special 10% OFF',
      'desc': 'Save ₹50.00 instantly',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedCouponCode = widget.currentCouponCode;
    if (_selectedCouponCode != null) {
      _couponController.text = _selectedCouponCode!;
      _inputText = _selectedCouponCode!;
    }
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInputNotEmpty = _inputText.trim().isNotEmpty;
    final bool isAnySelected = _selectedCouponCode != null || isInputNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Scrollable Coupon content
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(20),
                    vertical: Responsive.h(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: Responsive.h(60)),

                      // Have a coupon code TextField
                      Container(
                        height: Responsive.h(50),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(14)),
                          border: Border.all(
                            color: AppColors.outliner,
                            width: Responsive.w(1.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                                child: TextField(
                                  controller: _couponController,
                                  onChanged: (val) {
                                    setState(() {
                                      _inputText = val;
                                      // If user typed custom code, deselect radio button
                                      if (val != _selectedCouponCode) {
                                        _selectedCouponCode = null;
                                      }
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'Have a coupon code? Type here',
                                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: isInputNotEmpty
                                  ? () {
                                      // Apply typed code
                                      final matched = _coupons.firstWhere(
                                        (c) => c['code'].toLowerCase() == _inputText.trim().toLowerCase(),
                                        orElse: () => {
                                          'code': _inputText.trim().toUpperCase(),
                                          'discount': 30,
                                          'title': 'Custom Coupon Applied',
                                          'desc': 'Save ₹30.00 with this code',
                                        },
                                      );
                                      Navigator.pop(context, matched);
                                    }
                                  : null,
                              child: Container(
                                width: Responsive.w(80),
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: isInputNotEmpty ? AppColors.primary : Colors.grey.shade100,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(Responsive.w(12)),
                                    bottomRight: Radius.circular(Responsive.w(12)),
                                  ),
                                ),
                                child: Center(
                                  child: CustomText.title(
                                    'Apply',
                                    color: isInputNotEmpty ? Colors.white : Colors.grey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.h(24)),

                      // App coupons heading
                      CustomText.header(
                        'App coupons',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: Responsive.h(12)),

                      // App coupons list container card
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Responsive.w(20)),
                          border: Border.all(
                            color: AppColors.outliner,
                            width: Responsive.w(1.2),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Responsive.w(20)),
                          child: Material(
                            color: AppColors.white,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _coupons.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final coupon = _coupons[index];
                                final bool isThisSelected = _selectedCouponCode == coupon['code'];

                                return ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(16),
                                    vertical: Responsive.h(8),
                                  ),
                                  leading: Container(
                                    width: Responsive.w(36),
                                    height: Responsive.w(36),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE8F5E9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.percent,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                  ),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CustomText.title(
                                        coupon['title'],
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: Responsive.h(2)),
                                      CustomText.subtitle(
                                        coupon['desc'],
                                        fontSize: 11,
                                        color: Colors.green,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: Responsive.h(6)),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Responsive.w(8),
                                          vertical: Responsive.h(4),
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                          borderRadius: BorderRadius.circular(Responsive.w(6)),
                                          color: Colors.grey.shade50,
                                        ),
                                        child: CustomText.title(
                                          coupon['code'],
                                          fontSize: 9,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    width: Responsive.w(20),
                                    height: Responsive.w(20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isThisSelected ? AppColors.primary : Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isThisSelected
                                        ? Center(
                                            child: Container(
                                              width: Responsive.w(10),
                                              height: Responsive.w(10),
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedCouponCode = coupon['code'];
                                      _couponController.text = coupon['code'];
                                      _inputText = coupon['code'];
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(100)),
                    ],
                  ),
                ),
              ),

              // 2. Custom App Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: Responsive.h(60),
                  color: AppColors.screenColor.withValues(alpha: 0.95),
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                  child: Row(
                    children: [
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
                      SizedBox(width: Responsive.w(12)),
                      CustomText.header(
                        'Coupons',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Update Coupons Solid Button (Sticky Bottom)
              Positioned(
                bottom: Responsive.h(20),
                left: Responsive.w(20),
                right: Responsive.w(20),
                child: GestureDetector(
                  onTap: isAnySelected
                      ? () {
                          final selected = _coupons.firstWhere(
                            (c) => c['code'] == _selectedCouponCode,
                            orElse: () => {
                              'code': _inputText.trim().toUpperCase(),
                              'discount': 120,
                              'title': 'Flat ₹120 OFF',
                              'desc': 'Save ₹120.00 with this code',
                            },
                          );
                          Navigator.pop(context, selected);
                        }
                      : null,
                  child: Container(
                    height: Responsive.h(48),
                    decoration: BoxDecoration(
                      color: isAnySelected ? AppColors.primary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(Responsive.w(24)),
                      border: Border.all(
                        color: isAnySelected ? AppColors.primary : Colors.grey.shade300,
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: CustomText.title(
                        'Update coupons',
                        color: isAnySelected ? Colors.white : Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
