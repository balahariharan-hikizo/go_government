import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/store_model.dart';
import '../../network/api_client.dart';
import '../../network/store_order_api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class StoreOrdersQueueScreen extends StatefulWidget {
  final StoreModel store;
  final int initialTabIndex;

  const StoreOrdersQueueScreen({
    super.key,
    required this.store,
    this.initialTabIndex = 0,
  });

  @override
  State<StoreOrdersQueueScreen> createState() => _StoreOrdersQueueScreenState();
}

class _StoreOrdersQueueScreenState extends State<StoreOrdersQueueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderUpdateSub;
  StreamSubscription? _returnReqSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 9,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 8),
    );
    _fetchOrders();

    // Subscribe to real-time Socket.io events for this store
    StoreSocketService().subscribeToStore(widget.store.storeId);
    _newOrderSub = StoreSocketService().onNewOrder.listen((newOrder) {
      if (!mounted) return;
      final orderId = newOrder['orderId']?.toString();
      setState(() {
        _orders.removeWhere((o) => o['orderId']?.toString() == orderId);
        _orders.insert(0, newOrder);
      });
      _fetchOrders(showLoading: false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔔 New Order #$orderId received!'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    });

    _orderUpdateSub = StoreSocketService().onOrderUpdate.listen((updatedOrder) {
      if (!mounted) return;
      final orderId = updatedOrder['orderId']?.toString();
      setState(() {
        _orders.removeWhere((o) => o['orderId']?.toString() == orderId);
        _orders.insert(0, updatedOrder);
      });
      _fetchOrders(showLoading: false);
    });

    _returnReqSub = StoreSocketService().onReturnRequested.listen((returnOrder) {
      if (!mounted) return;
      final orderId = returnOrder['orderId']?.toString();
      setState(() {
        _orders.removeWhere((o) => o['orderId']?.toString() == orderId);
        _orders.insert(0, returnOrder);
      });
      _fetchOrders(showLoading: false);
    });
  }

  @override
  void dispose() {
    _newOrderSub?.cancel();
    _orderUpdateSub?.cancel();
    _returnReqSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final list = await StoreOrderApiService.fetchStoreOrders(widget.store.storeId);
    if (mounted) {
      setState(() {
        _orders = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus, String message) async {
    final success = await StoreOrderApiService.updateOrderStatus(
      orderId: orderId,
      status: newStatus,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.success),
      );
      _fetchOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update order status'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // Actionable return requests and new orders always come FIRST
  int _orderPriority(Map<String, dynamic> o) {
    final s = o['status']?.toString().toLowerCase().trim() ?? '';
    // Priority 0: Active citizen return request waiting for store review (Approve / Reject)
    if (s == 'return_requested') return 0;
    // Priority 1: Package returning to store (rider bringing back, store must inspect & restock)
    if (s == 'returning_to_store') return 1;
    // Priority 2: New unfulfilled orders that need to be accepted & packed
    if (s == 'placed') return 2;
    // Priority 3: Packing in progress
    if (s == 'preparing') return 3;
    // Priority 4: Ready for pickup & rider assignment
    if (s == 'ready_for_pickup') return 4;
    if (s == 'accepted') return 5;
    if (s == 'out_for_delivery') return 6;
    if (s == 'return_pickup_pending') return 7;
    if (s == 'return_pickup_assigned') return 8;
    // Lower priority: completed or closed orders
    if (s == 'delivered') return 9;
    if (s == 'returned_to_store' || s == 'returned') return 10;
    if (s == 'return_rejected') return 11;
    if (s == 'cancelled') return 12;
    return 13;
  }

  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> list) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final pA = _orderPriority(a);
      final pB = _orderPriority(b);
      if (pA != pB) return pA.compareTo(pB);

      // When same priority, sort by most recent update / return request / creation
      final tA = a['updatedAt'] ?? a['returnDetails']?['requestedAt'] ?? a['createdAt'] ?? '';
      final tB = b['updatedAt'] ?? b['returnDetails']?['requestedAt'] ?? b['createdAt'] ?? '';
      return tB.toString().compareTo(tA.toString());
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    final allSorted = _sortOrders(_orders);
    final placedOrders = _sortOrders(_orders.where((o) => o['status'] == 'placed').toList());
    final preparingOrders = _sortOrders(_orders.where((o) => o['status'] == 'preparing').toList());
    final readyOrders = _sortOrders(_orders.where((o) => o['status'] == 'ready_for_pickup').toList());
    final acceptedOrders = _sortOrders(_orders.where((o) => o['status'] == 'accepted').toList());
    final dispatchedOrders = _sortOrders(_orders.where((o) => o['status'] == 'out_for_delivery').toList());
    final completedOrders = _sortOrders(_orders.where((o) => o['status'] == 'delivered').toList());
    final returnOrders = _sortOrders(_orders.where((o) => [
      'returning_to_store',
      'returned_to_store',
      'return_requested',
      'returned',
      'return_rejected',
    ].contains(o['status'])).toList());
    final cancelledOrders = _sortOrders(_orders.where((o) => o['status'] == 'cancelled').toList());

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      appBar: AppBar(
        title: CustomText.title('Order Fulfillment Queue', fontWeight: FontWeight.bold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _fetchOrders,
            tooltip: 'Refresh Orders',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grayFont,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'All (${_orders.length})'),
            Tab(text: 'New (${placedOrders.length})'),
            Tab(text: 'Packing (${preparingOrders.length})'),
            Tab(text: 'Ready (${readyOrders.length})'),
            Tab(text: 'Rider Coming (${acceptedOrders.length})'),
            Tab(text: 'Dispatched (${dispatchedOrders.length})'),
            Tab(text: 'Delivered (${completedOrders.length})'),
            Tab(text: 'Returns (${returnOrders.length})'),
            Tab(text: 'Cancelled (${cancelledOrders.length})'),
          ],
        ),
      ),
      body: CommonBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrdersList(allSorted),
                    _buildOrdersList(placedOrders),
                    _buildOrdersList(preparingOrders),
                    _buildOrdersList(readyOrders),
                    _buildOrdersList(acceptedOrders),
                    _buildOrdersList(dispatchedOrders),
                    _buildOrdersList(completedOrders),
                    _buildOrdersList(returnOrders),
                    _buildOrdersList(cancelledOrders),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchOrders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.outliner),
                SizedBox(height: Responsive.h(12)),
                CustomText.title('No Orders in this Category', fontSize: Responsive.sp(15)),
                SizedBox(height: Responsive.h(4)),
                CustomText.body('When citizens place orders, they appear here instantly.', color: AppColors.grayFont),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: EdgeInsets.all(Responsive.w(16)),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final order = list[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String orderId = order['orderId']?.toString() ?? '';
    final String status = order['status']?.toString() ?? 'placed';
    final items = (order['items'] as List? ?? []);
    final deliveryAddr = order['deliveryAddress'] as Map? ?? {};
    final agent = order['deliveryAgent'] as Map? ?? {};
    final grandTotal = order['grandTotal']?.toString() ?? '0';
    final paymentMethod = order['paymentMethod']?.toString() ?? 'Wallet Account';

    final hasRider = agent['name'] != null && agent['name'].toString().isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(16)),
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: _statusBorderColor(status), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header (ID, Status Badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: CustomText.title(
                  'Order #$orderId',
                  fontSize: Responsive.sp(15),
                  fontWeight: FontWeight.bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: Responsive.w(8)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(3)),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: Responsive.sp(11),
                    fontWeight: FontWeight.bold,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Citizen & Drop Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title(deliveryAddr['receiverName']?.toString() ?? 'Citizen', fontSize: Responsive.sp(13)),
                    CustomText.caption(deliveryAddr['address']?.toString() ?? 'Home Address', maxLines: 2),
                  ],
                ),
              ),
              if (deliveryAddr['receiverPhone'] != null && deliveryAddr['receiverPhone'].toString().isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone, size: 18, color: AppColors.primary),
                  onPressed: () => _callPhone(deliveryAddr['receiverPhone'].toString()),
                  tooltip: 'Call Customer',
                ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),

          // Commodities List in Order
          Container(
            padding: EdgeInsets.all(Responsive.w(12)),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(Responsive.w(14)),
              border: Border.all(color: Colors.blueGrey.shade100, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Item Count & Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary),
                        SizedBox(width: Responsive.w(6)),
                        Text(
                          'COMMODITIES (${items.length} ITEMS)',
                          style: TextStyle(
                            fontSize: Responsive.sp(11.5),
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Text(
                        'Total: ₹$grandTotal ($paymentMethod)',
                        style: TextStyle(
                          fontSize: Responsive.sp(11.5),
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(10)),

                // Items List
                ...items.map((item) {
                  final qty = item['quantity'] ?? item['qty'] ?? 1;
                  final title = item['title']?.toString() ?? 'Item';
                  final unit = item['unit']?.toString() ?? '';
                  final price = item['price'] ?? 0;
                  final productId = item['productId']?.toString() ?? '';
                  final rawImage = item['image']?.toString() ?? '';

                  final isSubsidized = item['isSubsidized'] == true ||
                      (item['subsidyLimit'] != null && item['subsidyLimit'].toString().trim().isNotEmpty) ||
                      title.toLowerCase().contains('govt ration');

                  String? fullImageUrl;
                  if (rawImage.isNotEmpty) {
                    fullImageUrl = rawImage.startsWith('http')
                        ? rawImage
                        : '${ApiClient.baseUrl.replaceAll('/api', '')}$rawImage';
                  }

                  return Container(
                    margin: EdgeInsets.only(bottom: Responsive.h(8)),
                    padding: EdgeInsets.all(Responsive.w(8)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Responsive.w(10)),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Product Thumbnail Image
                        Container(
                          width: Responsive.w(44),
                          height: Responsive.w(44),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(Responsive.w(8)),
                            border: Border.all(color: Colors.grey.shade300, width: 0.8),
                          ),
                          child: fullImageUrl != null && fullImageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(Responsive.w(8)),
                                  child: Image.network(
                                    fullImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                        ),
                        SizedBox(width: Responsive.w(10)),

                        // 2. Product Info & Metadata
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: Responsive.sp(12.5),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: Responsive.h(3)),
                              Wrap(
                                spacing: Responsive.w(5),
                                runSpacing: Responsive.h(3),
                                children: [
                                  if (unit.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.w(5),
                                        vertical: Responsive.h(1.5),
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                      ),
                                      child: Text(
                                        unit,
                                        style: TextStyle(
                                          fontSize: Responsive.sp(10),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  if (isSubsidized)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.w(5),
                                        vertical: Responsive.h(1.5),
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFA5D6A7), width: 0.8),
                                      ),
                                      child: Text(
                                        'Govt Quota',
                                        style: TextStyle(
                                          fontSize: Responsive.sp(9.5),
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                  if (productId.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.w(5),
                                        vertical: Responsive.h(1.5),
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blueGrey.shade200, width: 0.6),
                                      ),
                                      child: Text(
                                        'ID: $productId',
                                        style: TextStyle(
                                          fontSize: Responsive.sp(9.5),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueGrey.shade800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),

                        // 3. Quantity Badge & Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.w(7),
                                vertical: Responsive.h(2.5),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${qty}x',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: Responsive.sp(11.5),
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.h(4)),
                            Text(
                              '₹${price * qty}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: Responsive.sp(12),
                                color: AppColors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(12)),

          // Assigned Delivery Partner Card (if accepted)
          if (hasRider)
            Container(
              margin: EdgeInsets.only(bottom: Responsive.h(12)),
              padding: EdgeInsets.all(Responsive.w(10)),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(Responsive.w(10)),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.success,
                    child: Icon(Icons.two_wheeler_rounded, size: 18, color: Colors.white),
                  ),
                  SizedBox(width: Responsive.w(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText.title('Rider: ${agent['name']}', fontSize: Responsive.sp(12.5), fontWeight: FontWeight.bold),
                        CustomText.caption('Vehicle: ${agent['vehicleNumber'] ?? 'Two Wheeler'}', fontSize: Responsive.sp(11)),
                      ],
                    ),
                  ),
                  if (agent['phone'] != null && agent['phone'].toString().isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone, size: 18, color: AppColors.success),
                      onPressed: () => _callPhone(agent['phone'].toString()),
                      tooltip: 'Call Rider',
                    ),
                ],
              ),
            ),

          // Return Details Banner (Only if order is actively in return lifecycle)
          Builder(
            builder: (context) {
              final returnDetails = order['returnDetails'] as Map<String, dynamic>?;
              final returnType = returnDetails?['returnType']?.toString() ?? 'none';
              final custReason = returnDetails?['reason']?.toString().trim() ?? '';
              final custNotes = returnDetails?['notes']?.toString().trim() ?? '';
              final declineReason = returnDetails?['rejectionReason']?.toString().trim() ?? '';

              final isReturnLifecycle = [
                'return_requested',
                'return_pickup_pending',
                'return_pickup_assigned',
                'returning_to_store',
                'returned_to_store',
                'returned',
                'return_rejected',
              ].contains(status) && (returnType != 'none' || custReason.isNotEmpty || declineReason.isNotEmpty);

              if (!isReturnLifecycle) return const SizedBox.shrink();

              Color bgColor;
              Color borderColor;
              Color iconColor;
              String title;

              if (status == 'return_rejected') {
                bgColor = const Color(0xFFFFEBEE);
                borderColor = const Color(0xFFEF9A9A);
                iconColor = const Color(0xFFC62828);
                title = 'Return Request Declined';
              } else if (status == 'returned_to_store' || status == 'returned') {
                bgColor = const Color(0xFFE8F5E9);
                borderColor = const Color(0xFF81C784);
                iconColor = const Color(0xFF2E7D32);
                title = 'Package Returned & Restocked';
              } else if (status == 'return_pickup_assigned') {
                bgColor = const Color(0xFFE3F2FD);
                borderColor = const Color(0xFF90CAF9);
                iconColor = const Color(0xFF1565C0);
                title = 'Rider Assigned for Doorstep Pickup';
              } else if (status == 'return_pickup_pending') {
                bgColor = const Color(0xFFFFF3E0);
                borderColor = const Color(0xFFFFB74D);
                iconColor = const Color(0xFFE65100);
                title = 'Return Approved · Rider Pickup Pending';
              } else if (status == 'returning_to_store') {
                bgColor = const Color(0xFFFFF3E0);
                borderColor = const Color(0xFFFFB74D);
                iconColor = const Color(0xFFE65100);
                title = 'Rider Returning Package to Store';
              } else {
                bgColor = const Color(0xFFFFF3E0);
                borderColor = const Color(0xFFFFB74D);
                iconColor = const Color(0xFFE65100);
                title = 'Citizen Requested Return';
              }

              return Container(
                margin: EdgeInsets.only(bottom: Responsive.h(12)),
                padding: EdgeInsets.all(Responsive.w(10)),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(Responsive.w(10)),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      status == 'return_rejected'
                          ? Icons.error_outline_rounded
                          : Icons.assignment_return_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                    SizedBox(width: Responsive.w(8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.title(
                            title,
                            fontSize: Responsive.sp(12.5),
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                          if (custReason.isNotEmpty) ...[
                            SizedBox(height: Responsive.h(2)),
                            CustomText.caption(
                              'Customer Reason: $custReason',
                              fontSize: Responsive.sp(11),
                              color: Colors.black87,
                            ),
                          ],
                          if (custNotes.isNotEmpty) ...[
                            SizedBox(height: Responsive.h(2)),
                            CustomText.caption(
                              'Customer Notes: $custNotes',
                              fontSize: Responsive.sp(10.5),
                              color: Colors.grey.shade700,
                            ),
                          ],
                          if (status == 'return_rejected' && declineReason.isNotEmpty) ...[
                            SizedBox(height: Responsive.h(3)),
                            CustomText.caption(
                              'Store Decline Reason: $declineReason',
                              fontSize: Responsive.sp(11),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFC62828),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Action Buttons for Store Owner
          _buildStoreActions(orderId, status, hasRider: hasRider, agent: agent),
        ],
      ),
    );
  }

  void _showDeclineOrderDialog(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Order?'),
        content: const Text(
          'Are you sure you want to decline this order? The items will be returned to inventory and the citizen will be refunded automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(orderId, 'cancelled', 'Order declined. Customer refunded.');
            },
            child: const Text('Decline & Refund', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreActions(
    String orderId,
    String status, {
    bool hasRider = false,
    Map agent = const {},
  }) {
    if (status == 'placed') {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: Responsive.h(44),
              child: OutlinedButton.icon(
                onPressed: () => _showDeclineOrderDialog(orderId),
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                label: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          SizedBox(width: Responsive.w(10)),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: Responsive.h(44),
              child: ElevatedButton.icon(
                onPressed: () {
                  _updateStatus(orderId, 'preparing', 'Order accepted! Now packing items.');
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.white),
                label: const Text('Accept & Pack', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (status == 'preparing') {
      return SizedBox(
        width: double.infinity,
        height: Responsive.h(44),
        child: ElevatedButton.icon(
          onPressed: () {
            _updateStatus(orderId, 'ready_for_pickup', 'Order marked ready! Delivery partner will collect parcel.');
          },
          icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
          label: const Text('Mark Packed & Ready for Pickup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    } else if (status == 'ready_for_pickup') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning)),
            SizedBox(width: Responsive.w(8)),
            CustomText.caption('Parcel Packed · Waiting for Rider Pickup', fontWeight: FontWeight.bold, color: AppColors.warning),
          ],
        ),
      );
    } else if (status == 'accepted') {
      // Rider has accepted and is heading to the store
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(Responsive.w(10)),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.two_wheeler_rounded, color: AppColors.success, size: 20),
            SizedBox(width: Responsive.w(8)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomText.caption(
                    'Rider Accepted — On the Way to Store',
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                  if (hasRider)
                    CustomText.caption(
                      'Rider: ${agent['name']} · ${agent['vehicleNumber'] ?? ''}',
                      color: AppColors.grayFont,
                      fontSize: Responsive.sp(11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (status == 'out_for_delivery') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining_rounded, color: AppColors.info, size: 18),
            SizedBox(width: Responsive.w(8)),
            CustomText.caption('Out for Delivery to Citizen', fontWeight: FontWeight.bold, color: AppColors.info),
          ],
        ),
      );
    } else if (status == 'cancelled') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
            SizedBox(width: Responsive.w(8)),
            CustomText.caption('Order Cancelled / Declined', fontWeight: FontWeight.bold, color: AppColors.error),
          ],
        ),
      );
    } else if (status == 'returning_to_store') {
      return SizedBox(
        width: double.infinity,
        height: Responsive.h(46),
        child: ElevatedButton.icon(
          onPressed: () => _showConfirmReturnDialog(orderId),
          icon: const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Colors.white),
          label: const Text(
            'Confirm Return Received & Restock',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    } else if (status == 'return_requested') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: Responsive.h(44),
              child: OutlinedButton.icon(
                onPressed: () => _showRejectReturnDialog(orderId),
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                label: const Text('Reject Return', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          SizedBox(width: Responsive.w(10)),
          Expanded(
            child: SizedBox(
              height: Responsive.h(44),
              child: ElevatedButton.icon(
                onPressed: () => _showApproveReturnDialog(orderId),
                icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                label: const Text('Approve Return', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (status == 'return_pickup_pending') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule_rounded, color: Color(0xFFE65100), size: 18),
            SizedBox(width: Responsive.w(8)),
            Flexible(
              child: CustomText.caption(
                'Return Approved · Dispatching Rider for Doorstep Pickup',
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE65100),
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'return_pickup_assigned') {
      final riderName = (hasRider && agent['name'] != null && agent['name'].toString().isNotEmpty)
          ? agent['name'].toString()
          : 'Delivery Partner';
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining_rounded, color: AppColors.info, size: 18),
            SizedBox(width: Responsive.w(8)),
            Flexible(
              child: CustomText.caption(
                'Rider Assigned ($riderName) · Heading to Customer Doorstep',
                fontWeight: FontWeight.bold,
                color: AppColors.info,
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'returned_to_store' || status == 'returned') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_rounded, color: AppColors.success, size: 18),
            SizedBox(width: Responsive.w(8)),
            Flexible(
              child: CustomText.caption(
                'Return Completed · Restocked & Refunded',
                fontWeight: FontWeight.bold,
                color: AppColors.success,
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'return_rejected') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late_outlined, color: AppColors.error, size: 18),
            SizedBox(width: Responsive.w(8)),
            CustomText.caption('Return Request Declined', fontWeight: FontWeight.bold, color: AppColors.error),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, color: AppColors.success, size: 18),
            SizedBox(width: Responsive.w(8)),
            CustomText.caption('Delivered Successfully', fontWeight: FontWeight.bold, color: AppColors.success),
          ],
        ),
      );
    }
  }

  void _showConfirmReturnDialog(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Return Received?'),
        content: const Text(
          'Have you received the physical package back from the delivery rider? This will automatically restock the items into your store catalog, credit the delivery rider payout (₹35), and refund the customer wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await StoreOrderApiService.confirmReturn(
                orderId: orderId,
                storeId: widget.store.storeId,
              );
              if (res['success'] == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Return confirmed! Items restocked & customer refunded.'),
                    backgroundColor: AppColors.success,
                  ),
                );
                _fetchOrders();
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? 'Failed to confirm return'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Confirm & Restock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showApproveReturnDialog(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Return Request?'),
        content: const Text(
          'Approving this return will dispatch a delivery partner to collect the items from the citizen\'s doorstep (₹35 reverse logistics fee).\n\nCustomer refund and catalog restock will take place ONLY AFTER the rider delivers the package back to your store and you inspect it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await StoreOrderApiService.reviewCitizenReturn(
                orderId: orderId,
                storeId: widget.store.storeId,
                action: 'approve',
              );
              if (res['success'] == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Return approved! Delivery partner dispatched for customer doorstep pickup.'),
                    backgroundColor: AppColors.success,
                  ),
                );
                _fetchOrders();
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? 'Failed to approve return'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Approve & Dispatch Rider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRejectReturnDialog(String orderId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Return Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for declining the return request:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Item opened / seal broken / criteria not met',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason'), backgroundColor: AppColors.warning),
                );
                return;
              }
              Navigator.pop(ctx);
              final res = await StoreOrderApiService.reviewCitizenReturn(
                orderId: orderId,
                storeId: widget.store.storeId,
                action: 'reject',
                rejectionReason: reason,
              );
              if (res['success'] == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Return request declined.'), backgroundColor: AppColors.warning),
                );
                _fetchOrders();
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? 'Failed to reject return'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Decline Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'placed':           return AppColors.primary;
      case 'preparing':        return Colors.orange;
      case 'ready_for_pickup': return AppColors.warning;
      case 'accepted':         return AppColors.success;
      case 'out_for_delivery': return AppColors.info;
      case 'delivered':        return AppColors.success;
      case 'cancelled':        return AppColors.error;
      case 'returning_to_store': return const Color(0xFFE65100);
      case 'returned_to_store': return const Color(0xFF2E7D32);
      case 'return_requested': return const Color(0xFF7B1FA2);
      case 'returned':         return const Color(0xFF2E7D32);
      case 'return_rejected':  return const Color(0xFFC62828);
      default:                 return AppColors.grayFont;
    }
  }

  Color _statusBorderColor(String status) {
    switch (status) {
      case 'placed':           return AppColors.primary.withValues(alpha: 0.5);
      case 'preparing':        return Colors.orange.withValues(alpha: 0.5);
      case 'ready_for_pickup': return AppColors.warning.withValues(alpha: 0.5);
      case 'accepted':         return AppColors.success.withValues(alpha: 0.6);
      case 'out_for_delivery': return AppColors.info.withValues(alpha: 0.5);
      case 'delivered':        return AppColors.border;
      case 'cancelled':        return AppColors.error.withValues(alpha: 0.5);
      case 'returning_to_store': return const Color(0xFFFFB74D);
      case 'returned_to_store': return const Color(0xFF81C784);
      case 'return_requested': return const Color(0xFFBA68C8);
      case 'returned':         return const Color(0xFF81C784);
      case 'return_rejected':  return const Color(0xFFEF9A9A);
      default:                 return AppColors.border;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'placed':           return 'NEW ORDER';
      case 'preparing':        return 'PACKING';
      case 'ready_for_pickup': return 'READY FOR PICKUP';
      case 'accepted':         return 'RIDER COMING ✔';
      case 'out_for_delivery': return 'OUT FOR DELIVERY';
      case 'delivered':        return 'DELIVERED';
      case 'cancelled':        return 'CANCELLED';
      case 'returning_to_store': return 'RETURNING TO STORE';
      case 'returned_to_store': return 'RETURN RECEIVED & RESTOCKED';
      case 'return_requested': return 'RETURN REQUESTED';
      case 'returned':         return 'RETURN APPROVED & REFUNDED';
      case 'return_rejected':  return 'RETURN REJECTED';
      default:                 return status.toUpperCase();
    }
  }
}
