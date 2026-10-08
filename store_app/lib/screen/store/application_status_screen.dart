import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/store/store_bloc.dart';
import '../../bloc/store/store_event.dart';
import '../../bloc/store/store_state.dart';
import '../../constants/route_constants.dart';
import '../../model/store_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class ApplicationStatusScreen extends StatefulWidget {
  final StoreModel store;
  final bool justSubmitted;
  final bool isColdStart;

  const ApplicationStatusScreen({
    super.key,
    required this.store,
    this.justSubmitted = false,
    this.isColdStart = false,
  });

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  late StoreModel _store;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    // Auto-check live store approval status ONLY when app boots from cold start
    if (widget.isColdStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkStatus();
      });
    }
  }

  void _checkStatus() {
    context.read<StoreBloc>().add(RefreshStoreStatusEvent(_store.storeId.isNotEmpty ? _store.storeId : _store.phone));
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to log out? You can sign in with a different phone number afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(LogoutEvent());
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<StoreBloc, StoreState>(
          listener: (context, state) {
            if (state is StoreLoaded) {
              if (state.store.status == 'approved') {
                _store = state.store;
                Navigator.of(context).pushReplacementNamed(
                  RouteConstants.storeDashboard,
                  arguments: {'store': _store},
                );
              } else if (_store.status != state.store.status) {
                setState(() => _store = state.store);
              }
            }
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthInitial) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                RouteConstants.login,
                (r) => false,
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.screenColor,
        appBar: AppBar(
          title: CustomText.header('Application Tracking', fontSize: 18, color: AppColors.black),
          backgroundColor: AppColors.screenColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Refresh Status',
              onPressed: _checkStatus,
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
              tooltip: 'Logout',
              onPressed: _showLogoutDialog,
            ),
          ],
        ),
        body: CommonBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(16)),
              child: Column(
                children: [
                  _buildStatusHeroCard(),
                  SizedBox(height: Responsive.h(20)),
                  _buildStoreSummaryCard(),
                  SizedBox(height: Responsive.h(24)),
                  _buildActionButtons(),
                  SizedBox(height: Responsive.h(14)),
                  _buildLogoutButton(),
                  SizedBox(height: Responsive.h(24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeroCard() {
    final status = _store.status;
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    if (status == 'approved') {
      statusColor = const Color(0xFF16A34A);
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Application Approved!';
      statusSubtitle = 'Your commercial store outlet is verified and live for all nearby citizens on GoGovernment.';
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFDC2626);
      statusIcon = Icons.error_outline_rounded;
      statusTitle = 'Application Needs Changes';
      statusSubtitle = _store.rejectionReason.isNotEmpty
          ? _store.rejectionReason
          : 'Please review your store address or settlement bank details and re-submit.';
    } else {
      statusColor = const Color(0xFFD97706);
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Pending Municipal Review';
      statusSubtitle = 'Your store registration has been transmitted to the Municipal Commercial Division. Verification usually completes within 24-48 hours.';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(22)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(22)),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.w(16)),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 44),
          ),
          SizedBox(height: Responsive.h(16)),
          CustomText.header(statusTitle, fontSize: 18, color: statusColor, textAlign: TextAlign.center),
          SizedBox(height: Responsive.h(8)),
          CustomText.body(
            statusSubtitle,
            fontSize: 13,
            color: AppColors.grayFont,
            textAlign: TextAlign.center,
            height: 1.4,
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSummaryCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(18)),
        border: Border.all(color: AppColors.outliner.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.title('Application Summary', fontSize: 14, color: AppColors.black),
          const Divider(height: 20),
          _detailRow('Store Name', _store.name),
          _detailRow('Category', _store.category.toUpperCase()),
          _detailRow('Owner Name', _store.ownerName),
          _detailRow('Contact Phone', _store.phone),
          _detailRow('Bank Name', _store.bankDetails.bankName.isNotEmpty ? _store.bankDetails.bankName : 'N/A'),
          _detailRow('Account No', _store.bankDetails.accountNumber.isNotEmpty ? '•••• ${_store.bankDetails.accountNumber.length > 4 ? _store.bankDetails.accountNumber.substring(_store.bankDetails.accountNumber.length - 4) : _store.bankDetails.accountNumber}' : 'N/A'),
          _detailRow('IFSC Code', _store.bankDetails.ifscCode.isNotEmpty ? _store.bankDetails.ifscCode : 'N/A'),
          _detailRow('Address', _store.address),
          _detailRow('GPS Pin', '${_store.lat.toStringAsFixed(4)}, ${_store.lng.toStringAsFixed(4)}'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Responsive.w(110),
            child: CustomText.body(label, fontSize: 12, color: AppColors.grayFont),
          ),
          Expanded(
            child: CustomText.title(value, fontSize: 12, color: AppColors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = _store.status;

    if (status == 'approved') {
      return SizedBox(
        width: double.infinity,
        height: Responsive.h(50),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
          ),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(
              RouteConstants.storeDashboard,
              arguments: {'store': _store},
            );
          },
          child: CustomText.title('Open Store Dashboard', fontSize: 15, color: Colors.white),
        ),
      );
    }

    if (status == 'rejected') {
      return SizedBox(
        width: double.infinity,
        height: Responsive.h(50),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
          ),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(
              RouteConstants.registerStore,
              arguments: {'initialPhone': _store.phone},
            );
          },
          child: CustomText.title('Update & Re-Submit Application', fontSize: 15, color: Colors.white),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: Responsive.h(50),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
        label: CustomText.title('Check Verification Status', fontSize: 14, color: AppColors.primary),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
        ),
        onPressed: _checkStatus,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: Responsive.h(50),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
        label: CustomText.title('Logout & Switch Account', fontSize: 14, color: const Color(0xFFDC2626)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
          backgroundColor: const Color(0xFFFEF2F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
        ),
        onPressed: _showLogoutDialog,
      ),
    );
  }
}
