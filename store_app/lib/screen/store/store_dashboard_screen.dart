import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/product/product_bloc.dart';
import '../../bloc/product/product_event.dart';
import '../../bloc/product/product_state.dart';
import '../../bloc/store/store_bloc.dart';
import '../../bloc/store/store_event.dart';
import '../../bloc/store/store_state.dart';
import '../../constants/route_constants.dart';
import '../../model/store_model.dart';
import '../../network/store_order_api_service.dart';
import '../../network/auth_api_service.dart';
import '../../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/socket_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class StoreDashboardScreen extends StatefulWidget {
  final StoreModel store;

  const StoreDashboardScreen({
    super.key,
    required this.store,
  });

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  late StoreModel _store;
  StreamSubscription? _newOrderSub;
  Map<String, dynamic>? _subsidyMetrics;
  String? _lastNotifiedOrderId;
  int _lastNotifiedTime = 0;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    context.read<ProductBloc>().add(LoadStoreProductsEvent(_store.storeId));
    _fetchFinancialMetrics();
    _initFCM();

    // Connect to WebSocket for real-time order alerts
    StoreSocketService().subscribeToStore(_store.storeId);
    _newOrderSub = StoreSocketService().onNewOrder.listen((newOrder) {
      if (!mounted) return;
      final orderId = newOrder['orderId']?.toString() ?? '';
      _handleIncomingNewOrder(
        orderId,
        title: '🔔 New Order Received!',
        body: 'Order #$orderId received. Tap to fulfill items.',
      );
    });
  }

  @override
  void dispose() {
    _newOrderSub?.cancel();
    super.dispose();
  }

  void _handleIncomingNewOrder(String orderId, {String? title, String? body}) {
    if (orderId.isEmpty || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Deduplication check: ignore if already handled within 15 seconds
    if (_lastNotifiedOrderId == orderId && (now - _lastNotifiedTime < 15000)) {
      return;
    }
    _lastNotifiedOrderId = orderId;
    _lastNotifiedTime = now;

    _fetchFinancialMetrics();

    // 1. Trigger local notification with sound & heads-up banner
    NotificationService.showNewOrderNotification(
      orderId: orderId,
      title: title ?? '🔔 New Order Received!',
      body: body ?? 'A customer order has arrived. Tap to fulfill.',
    );

    // 2. Show in-app action snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔔 New order #$orderId received! Tap to fulfill.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Open Queue',
          textColor: Colors.white,
          onPressed: _openOrderQueue,
        ),
      ),
    );
  }

  Future<void> _fetchFinancialMetrics() async {
    final metrics = await StoreOrderApiService.fetchStoreFinancialMetrics(_store.storeId);
    if (mounted && metrics != null) {
      setState(() {
        _subsidyMetrics = metrics;
      });
    }
  }

  Future<void> _initFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 [FCM Store] Permission status: ${settings.authorizationStatus}');

      final token = await messaging.getToken();
      debugPrint('📱 [FCM Store] Device token: $token');
      if (token != null && token.isNotEmpty) {
        await AuthApiService.updateFcmToken(
          phone: _store.phone,
          storeId: _store.storeId,
          fcmToken: token,
        );
      }

      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 [FCM Store] Token refreshed: $newToken');
        await AuthApiService.updateFcmToken(
          phone: _store.phone,
          storeId: _store.storeId,
          fcmToken: newToken,
        );
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 [FCM Foreground Store]: ${message.data}');
        if (message.data['type'] == 'new_order' && mounted) {
          final orderId = message.data['orderId']?.toString() ?? '';
          _handleIncomingNewOrder(
            orderId,
            title: message.notification?.title ?? '🔔 New Order Received!',
            body: message.notification?.body ?? 'A customer order has arrived. Tap to fulfill.',
          );
        }
      });
    } catch (e) {
      debugPrint('❌ [FCM Store] Init error: $e');
    }
  }

  void _toggleOnline(bool val) {
    context.read<StoreBloc>().add(
      ToggleStoreOnlineEvent(storeId: _store.storeId, isOnline: val),
    );
  }

  void _openStoreDetails() {
    Navigator.pushNamed(
      context,
      RouteConstants.storeDetails,
      arguments: {'store': _store},
    );
  }

  void _openManageProducts() {
    Navigator.pushNamed(
      context,
      RouteConstants.manageProducts,
      arguments: {'store': _store},
    );
  }

  void _openAddProduct() {
    Navigator.pushNamed(
      context,
      RouteConstants.addProduct,
      arguments: {
        'storeId': _store.storeId,
        'storeCategory': _store.category,
      },
    );
  }

  void _openOrderQueue() {
    Navigator.pushNamed(
      context,
      RouteConstants.orderQueue,
      arguments: {'store': _store},
    );
  }

  void _showSubsidyBreakdownModal() {
    final totalDisbursed = _subsidyMetrics?['totalSubsidyDisbursed'] ?? 0;
    final pendingPayout = _subsidyMetrics?['pendingSubsidyPayout'] ?? 0;
    final totalOrders = _subsidyMetrics?['totalOrders'] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(Responsive.w(20)),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: Responsive.w(40),
                height: Responsive.h(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: Responsive.h(16)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF16A34A), size: 24),
                ),
                SizedBox(width: Responsive.w(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.header('Government Subsidy Statement', fontSize: 16, color: AppColors.black),
                      CustomText.body('Direct Benefit Transfer (DBT) Reimbursement', fontSize: 11, color: AppColors.grayFont),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(14)),
            Container(
              padding: EdgeInsets.all(Responsive.w(12)),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: Responsive.w(8)),
                  const Expanded(
                    child: Text(
                      'When citizens purchase subsidized welfare commodities, the government reimburses the price difference (Market MRP - Subsidized Rate) directly to your bank account.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.h(14)),
            _buildModalInfoRow('Total Subsidy Claimed', '₹$totalDisbursed.00'),
            _buildModalInfoRow('Current Cycle Pending Settlement', '₹$pendingPayout.00', valueColor: const Color(0xFF16A34A)),
            _buildModalInfoRow('Total Store Orders', '$totalOrders orders'),
            _buildModalInfoRow('Reimbursement Method', 'Direct Benefit Transfer (DBT)'),
            _buildModalInfoRow('Settlement Schedule', 'Weekly every Friday', valueColor: const Color(0xFF2563EB)),
            _buildModalInfoRow('Linked Bank', '${_store.bankDetails.bankName.isNotEmpty ? _store.bankDetails.bankName : 'State Bank of India'} (•••• ${_store.bankDetails.accountNumber.length > 4 ? _store.bankDetails.accountNumber.substring(_store.bankDetails.accountNumber.length - 4) : '4821'})'),
            SizedBox(height: Responsive.h(20)),
            SizedBox(
              width: double.infinity,
              height: Responsive.h(44),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                label: const Text('View All Order Receipts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openOrderQueue();
                },
              ),
            ),
            SizedBox(height: Responsive.h(8)),
          ],
        ),
      ),
    );
  }

  void _showSettlementInfoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(Responsive.w(20)),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: Responsive.w(40),
                height: Responsive.h(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: Responsive.h(16)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 24),
                ),
                SizedBox(width: Responsive.w(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.header('Settlement & Bank Details', fontSize: 16, color: AppColors.black),
                      CustomText.body('Automated municipal DBT reimbursement', fontSize: 11, color: AppColors.grayFont),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(18)),
            const Divider(height: 1),
            SizedBox(height: Responsive.h(14)),
            _buildModalInfoRow('Bank Name', _store.bankDetails.bankName.isNotEmpty ? _store.bankDetails.bankName : 'State Bank of India'),
            _buildModalInfoRow('Account Number', _store.bankDetails.accountNumber.isNotEmpty ? '•••• •••• ${_store.bankDetails.accountNumber.length > 4 ? _store.bankDetails.accountNumber.substring(_store.bankDetails.accountNumber.length - 4) : _store.bankDetails.accountNumber}' : '•••• 4821'),
            _buildModalInfoRow('IFSC Code', _store.bankDetails.ifscCode.isNotEmpty ? _store.bankDetails.ifscCode : 'SBIN0001234'),
            _buildModalInfoRow('Account Holder', _store.bankDetails.accountHolderName.isNotEmpty ? _store.bankDetails.accountHolderName : _store.ownerName),
            _buildModalInfoRow('Payout Schedule', 'Weekly every Friday (Automated DBT)', valueColor: const Color(0xFF16A34A)),
            SizedBox(height: Responsive.h(20)),
            SizedBox(
              width: double.infinity,
              height: Responsive.h(44),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openStoreDetails();
                },
                child: const Text('Edit Store & Bank Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            SizedBox(height: Responsive.h(8)),
          ],
        ),
      ),
    );
  }

  Widget _buildModalInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grayFont)),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.black)),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of your merchant portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthInitial) {
              Navigator.of(context).pushNamedAndRemoveUntil(RouteConstants.login, (r) => false);
            }
          },
        ),
        BlocListener<StoreBloc, StoreState>(
          listener: (context, state) {
            if (state is StoreLoaded) {
              setState(() => _store = state.store);
            }
          },
        ),
      ],
      child: BlocBuilder<StoreBloc, StoreState>(
        builder: (context, state) {
          if (state is StoreLoaded) {
            _store = state.store;
          }

          return Scaffold(
          backgroundColor: AppColors.screenColor,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            titleSpacing: Responsive.w(16),
            title: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: Responsive.w(40),
                      height: Responsive.w(40),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _store.isOnline ? const Color(0xFF16A34A) : Colors.grey,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: Responsive.w(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _store.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_store.status == 'approved') ...[
                            SizedBox(width: Responsive.w(4)),
                            const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF16A34A)),
                          ],
                        ],
                      ),
                      Text(
                        'ID: ${_store.storeId} • ${_store.category.toUpperCase()}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.grayFont),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Clean Online/Offline toggle pill
              InkWell(
                onTap: () => _toggleOnline(!_store.isOnline),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(4)),
                  decoration: BoxDecoration(
                    color: _store.isOnline ? const Color(0xFFE8F5E9) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _store.isOnline ? const Color(0xFF16A34A).withValues(alpha: 0.4) : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _store.isOnline ? const Color(0xFF16A34A) : Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(width: Responsive.w(5)),
                      Text(
                        _store.isOnline ? 'Open' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _store.isOnline ? const Color(0xFF16A34A) : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.black, size: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'profile') _openStoreDetails();
                  if (val == 'logout') _logout();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 18, color: AppColors.black),
                        SizedBox(width: 8),
                        Text('Store Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(width: Responsive.w(6)),
            ],
          ),
          body: CommonBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(18), vertical: Responsive.h(14)),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. PRIMARY ACTION: Incoming Citizen Orders Hero Card
                    GestureDetector(
                      onTap: _openOrderQueue,
                      child: Container(
                        padding: EdgeInsets.all(Responsive.w(16)),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(Responsive.w(18)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: Responsive.w(48),
                              height: Responsive.w(48),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(Responsive.w(14)),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 26),
                            ),
                            SizedBox(width: Responsive.w(14)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Order Processing Queue',
                                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      SizedBox(width: Responsive.w(6)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'LIVE',
                                          style: TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: Responsive.h(4)),
                                  Text(
                                    _store.isOnline ? 'Tap to view and pack citizen orders' : 'Store offline • Turn online to get orders',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _store.isOnline ? Colors.grey.shade300 : Colors.amber.shade200,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(16)),

                    // 2. Urgent Inventory Alert (Conditional)
                    BlocBuilder<ProductBloc, ProductState>(
                      builder: (context, pState) {
                        if (pState is ProductLoaded) {
                          final lowStock = pState.products.where((p) => p.stock <= 3 || !p.isAvailable).length;
                          if (lowStock > 0) {
                            return Container(
                              margin: EdgeInsets.only(bottom: Responsive.h(14)),
                              padding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(10)),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(Responsive.w(14)),
                                border: Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
                                  SizedBox(width: Responsive.w(10)),
                                  Expanded(
                                    child: Text(
                                      '$lowStock items running low on stock (< 3 units).',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A3412), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: _openManageProducts,
                                    child: const Text('Restock', style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 11.5)),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // 3. Four Distinct, User-Friendly Quick Actions (2x2 Grid)
                    CustomText.title('Merchant Operations', fontSize: 14, color: AppColors.black),
                    SizedBox(height: Responsive.h(10)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildOperationCard(
                            title: 'Stock Inventory',
                            subtitle: 'Manage prices & stock',
                            icon: Icons.inventory_2_rounded,
                            iconColor: const Color(0xFF2563EB),
                            badgeColor: const Color(0xFFEFF6FF),
                            onTap: _openManageProducts,
                          ),
                        ),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: _buildOperationCard(
                            title: 'Add New Product',
                            subtitle: 'List fresh commodity',
                            icon: Icons.add_business_rounded,
                            iconColor: const Color(0xFF16A34A),
                            badgeColor: const Color(0xFFF0FDF4),
                            onTap: _openAddProduct,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(12)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildOperationCard(
                            title: 'Store Profile',
                            subtitle: 'Hours, phone & address',
                            icon: Icons.edit_note_rounded,
                            iconColor: AppColors.primary,
                            badgeColor: AppColors.primary.withValues(alpha: 0.1),
                            onTap: _openStoreDetails,
                          ),
                        ),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: _buildOperationCard(
                            title: 'Bank & DBT Payout',
                            subtitle: 'Settlement account details',
                            icon: Icons.account_balance_rounded,
                            iconColor: const Color(0xFFD97706),
                            badgeColor: const Color(0xFFFFFBEB),
                            onTap: _showSettlementInfoModal,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.h(18)),

                    // 4. Live Inventory Health Snapshot
                    BlocBuilder<ProductBloc, ProductState>(
                      builder: (context, pState) {
                        int total = 0;
                        int low = 0;
                        int subsidized = 0;
                        if (pState is ProductLoaded) {
                          total = pState.products.length;
                          low = pState.products.where((p) => p.stock <= 3).length;
                          subsidized = pState.products.where((p) => p.isSubsidized).length;
                        }

                        return Container(
                          padding: EdgeInsets.all(Responsive.w(16)),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(16)),
                            border: Border.all(color: AppColors.outliner.withValues(alpha: 0.6)),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.analytics_outlined, size: 18, color: AppColors.primary),
                                      SizedBox(width: Responsive.w(6)),
                                      CustomText.title('Catalog & Stock Health', fontSize: 13, color: AppColors.black),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: _openManageProducts,
                                    child: const Text('View All >', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.h(12)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn('Total Items', '$total', const Color(0xFF2563EB)),
                                  Container(width: 1, height: 28, color: Colors.grey.shade200),
                                  _buildStatColumn('Govt Subsidized', '$subsidized', const Color(0xFF16A34A)),
                                  Container(width: 1, height: 28, color: Colors.grey.shade200),
                                  _buildStatColumn('Low Stock', '$low', low > 0 ? const Color(0xFFEA580C) : AppColors.grayFont),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    SizedBox(height: Responsive.h(16)),

                    // 5. Subsidy Financial Settlement Card (Live DBT Tracking)
                    GestureDetector(
                      onTap: _showSubsidyBreakdownModal,
                      child: Container(
                        padding: EdgeInsets.all(Responsive.w(16)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          border: Border.all(color: AppColors.outliner.withValues(alpha: 0.6)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.payments_outlined, size: 18, color: AppColors.primary),
                                    SizedBox(width: Responsive.w(6)),
                                    CustomText.title('Subsidy Financial Summary', fontSize: 13, color: AppColors.black),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Automated DBT',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.info_outline_rounded, size: 11, color: Color(0xFF16A34A)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(12)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText.body('Subsidies Disbursed', fontSize: 10.5, color: AppColors.grayFont),
                                    SizedBox(height: Responsive.h(2)),
                                    CustomText.header('₹${_subsidyMetrics?['totalSubsidyDisbursed'] ?? 0}.00', fontSize: 15, color: AppColors.black),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText.body('Pending Settlement', fontSize: 10.5, color: AppColors.grayFont),
                                    SizedBox(height: Responsive.h(2)),
                                    CustomText.header('₹${_subsidyMetrics?['pendingSubsidyPayout'] ?? 0}.00', fontSize: 15, color: const Color(0xFF16A34A)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    CustomText.body('Next Payout', fontSize: 10.5, color: AppColors.grayFont),
                                    SizedBox(height: Responsive.h(2)),
                                    CustomText.title('Friday', fontSize: 13, color: const Color(0xFF2563EB)),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(8)),
                            const Divider(height: 1),
                            SizedBox(height: Responsive.h(8)),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                SizedBox(width: Responsive.w(6)),
                                Expanded(
                                  child: Text(
                                    'Linked Bank: ${_store.bankDetails.bankName.isNotEmpty ? _store.bankDetails.bankName : 'State Bank of India'} (•••• ${_store.bankDetails.accountNumber.length > 4 ? _store.bankDetails.accountNumber.substring(_store.bankDetails.accountNumber.length - 4) : '4821'})',
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.grayFont),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Text('Statement >', style: TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.h(20)),
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

  Widget _buildOperationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Responsive.w(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(color: AppColors.outliner.withValues(alpha: 0.6)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            SizedBox(height: Responsive.h(10)),
            CustomText.title(title, fontSize: 12.5, color: AppColors.black),
            SizedBox(height: Responsive.h(2)),
            CustomText.body(subtitle, fontSize: 10.5, color: AppColors.grayFont, maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
        ),
        SizedBox(height: Responsive.h(2)),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.grayFont),
        ),
      ],
    );
  }
}
