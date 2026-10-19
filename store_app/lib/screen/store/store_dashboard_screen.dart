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
        // If Socket.io is active and handling live orders in foreground, skip duplicate FCM notification
        if (StoreSocketService().isConnected) {
          debugPrint('⚡ [FCM Foreground Store] Socket.io is actively connected. Skipping redundant FCM alert.');
          return;
        }
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

  void _openManageCategories() {
    Navigator.pushNamed(
      context,
      RouteConstants.manageCategories,
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

  void _openStoreWallet() {
    Navigator.pushNamed(
      context,
      RouteConstants.storeWallet,
      arguments: {'store': _store},
    ).then((_) {
      if (!mounted) return;
      _fetchFinancialMetrics();
      context.read<StoreBloc>().add(FetchMyStoreEvent(_store.storeId));
    });
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
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.black, size: 22),
                tooltip: 'Store Revenue & Wallet',
                onPressed: _openStoreWallet,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.black, size: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'wallet') _openStoreWallet();
                  if (val == 'profile') _openStoreDetails();
                  if (val == 'logout') _logout();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'wallet',
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Revenue & Wallet'),
                      ],
                    ),
                  ),
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
                          final lowStock = pState.products.where((p) => p.stock <= 3).length;
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
                            title: 'Categories',
                            subtitle: 'Organize store catalog',
                            icon: Icons.category_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            badgeColor: const Color(0xFFF5F3FF),
                            onTap: _openManageCategories,
                          ),
                        ),
                        SizedBox(width: Responsive.w(12)),
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
                      ],
                    ),
                    // SizedBox(height: Responsive.h(12)),
                    // _buildOperationCard(
                    //   title: 'Store Revenue & Wallet',
                    //   subtitle: 'Live balance, sales ledger & express DBT payouts',
                    //   icon: Icons.account_balance_wallet_rounded,
                    //   iconColor: const Color(0xFFD97706),
                    //   badgeColor: const Color(0xFFFFFBEB),
                    //   onTap: _openStoreWallet,
                    // ),

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

                    // 5. Store Revenue & Live Wallet Settlement Card
                    GestureDetector(
                      onTap: _openStoreWallet,
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
                                    const Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppColors.primary),
                                    SizedBox(width: Responsive.w(8)),
                                    CustomText.title('Store Revenue & Wallet', fontSize: 13.5, color: AppColors.black),
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
                                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF16A34A)),
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
                                    CustomText.body('Live Wallet Balance', fontSize: 10.5, color: AppColors.grayFont),
                                    SizedBox(height: Responsive.h(2)),
                                    CustomText.header('₹${_store.walletBalance}.00', fontSize: 16, color: const Color(0xFF16A34A)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText.body('Gross Sales Total', fontSize: 10.5, color: AppColors.grayFont),
                                    SizedBox(height: Responsive.h(2)),
                                    CustomText.header('₹${_subsidyMetrics?['totalGrossSales'] ?? 0}.00', fontSize: 15, color: AppColors.black),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    CustomText.body('Settlement Day', fontSize: 10.5, color: AppColors.grayFont),
                                    SizedBox(height: Responsive.h(2)),
                                    CustomText.title('Friday (DBT)', fontSize: 12.5, color: const Color(0xFF2563EB)),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(10)),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(6)),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                                  SizedBox(width: Responsive.w(6)),
                                  Expanded(
                                    child: Text(
                                      'Gross Sales includes delivery charges paid to riders. Your wallet balance represents 100% net product sales revenue.',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: Responsive.h(10)),
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
                                const Text('View Ledger >', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
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
