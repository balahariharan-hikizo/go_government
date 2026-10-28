import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_bottom_bar.dart';
import '../complaint/complaint_screen.dart';
import '../report/report_screen.dart';
import 'home_tab.dart';
import '../transaction/transaction_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2; // Default to 2 (Home, which is the center storefront icon)
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        // 1. If currently on any tab other than Home, navigate back to Home tab
        if (_currentIndex != 2) {
          setState(() {
            _currentIndex = 2;
          });
          return;
        }

        // 2. If already on Home tab, require double-tap back to exit cleanly
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Responsive.w(12)),
              ),
            ),
          );
          return;
        }

        // Double-tap confirmed -> Cleanly exit app, never go back to login
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.screenColor,
        body: CommonBackground(
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Independent scroll-state wrappers via IndexedStack
                IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildTabWrapper(const ComplaintScreen()),
                    _buildTabWrapper(const ReportScreen()),
                    _buildTabWrapper(const HomeTab()),
                    _buildTabWrapper(const TransactionScreen()),
                    _buildTabWrapper(const ProfileScreen(), isScrollable: false),
                  ],
                ),

                // 5. Floating Bottom Navigation Bar
                Positioned(
                  bottom: Responsive.h(24),
                  left: Responsive.w(16),
                  right: Responsive.w(16),
                  child: CustomBottomBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabWrapper(Widget child, {bool isScrollable = true}) {
    final Widget content = Padding(
      padding: EdgeInsets.only(
        left: Responsive.w(20.0),
        right: Responsive.w(20.0),
        top: Responsive.h(16.0),
        bottom: Responsive.h(120.0), // Space for floating bottom bar
      ),
      child: child,
    );

    if (!isScrollable) {
      return content;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: content,
    );
  }
}
