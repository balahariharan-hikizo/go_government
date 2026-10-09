import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/store_model.dart';
import '../../network/store_order_api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class StoreOrdersQueueScreen extends StatefulWidget {
  final StoreModel store;

  const StoreOrdersQueueScreen({super.key, required this.store});

  @override
  State<StoreOrdersQueueScreen> createState() => _StoreOrdersQueueScreenState();
}

class _StoreOrdersQueueScreenState extends State<StoreOrdersQueueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderUpdateSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
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
        final idx = _orders.indexWhere((o) => o['orderId']?.toString() == orderId);
        if (idx != -1) {
          _orders[idx] = updatedOrder;
        } else {
          _orders.insert(0, updatedOrder);
        }
      });
      _fetchOrders(showLoading: false);
    });
  }

  @override
  void dispose() {
    _newOrderSub?.cancel();
    _orderUpdateSub?.cancel();
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

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    final placedOrders = _orders.where((o) => o['status'] == 'placed').toList();
    final preparingOrders = _orders.where((o) => o['status'] == 'preparing').toList();
    final readyOrders = _orders.where((o) => o['status'] == 'ready_for_pickup').toList();
    final acceptedOrders = _orders.where((o) => o['status'] == 'accepted').toList();
    final dispatchedOrders = _orders.where((o) => o['status'] == 'out_for_delivery').toList();
    final completedOrders = _orders.where((o) => o['status'] == 'delivered').toList();
    final cancelledOrders = _orders.where((o) => o['status'] == 'cancelled').toList();

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
                    _buildOrdersList(_orders),
                    _buildOrdersList(placedOrders),
                    _buildOrdersList(preparingOrders),
                    _buildOrdersList(readyOrders),
                    _buildOrdersList(acceptedOrders),
                    _buildOrdersList(dispatchedOrders),
                    _buildOrdersList(completedOrders),
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

          // Items to Pack Checklist
          Container(
            padding: EdgeInsets.all(Responsive.w(12)),
            decoration: BoxDecoration(
              color: AppColors.lightGray.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Responsive.w(10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: CustomText.caption(
                        'COMMODITIES (${items.length} ITEMS)',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: Responsive.w(8)),
                    Flexible(
                      child: Text(
                        'Total: ₹$grandTotal ($paymentMethod)',
                        style: TextStyle(
                          fontSize: Responsive.sp(11),
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
                SizedBox(height: Responsive.h(8)),
                ...items.map((item) {
                  final qty = item['quantity'] ?? 1;
                  final title = item['title'] ?? 'Item';
                  final unit = item['unit'] ?? '';
                  final price = item['price'] ?? 0;

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: Responsive.h(3)),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(6), vertical: Responsive.h(2)),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${qty}x',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11),
                          ),
                        ),
                        SizedBox(width: Responsive.w(10)),
                        Expanded(
                          child: Text(
                            '$title ($unit)',
                            style: TextStyle(fontSize: Responsive.sp(12.5), fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text('₹${price * qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                border: Border.all(color: AppColors.success.withOpacity(0.4)),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  ),
              ],
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

  Color _statusColor(String status) {
    switch (status) {
      case 'placed':           return AppColors.primary;
      case 'preparing':        return Colors.orange;
      case 'ready_for_pickup': return AppColors.warning;
      case 'accepted':         return AppColors.success;
      case 'out_for_delivery': return AppColors.info;
      case 'delivered':        return AppColors.success;
      case 'cancelled':        return AppColors.error;
      default:                 return AppColors.grayFont;
    }
  }

  Color _statusBorderColor(String status) {
    switch (status) {
      case 'placed':           return AppColors.primary.withOpacity(0.5);
      case 'preparing':        return Colors.orange.withOpacity(0.5);
      case 'ready_for_pickup': return AppColors.warning.withOpacity(0.5);
      case 'accepted':         return AppColors.success.withOpacity(0.6);
      case 'out_for_delivery': return AppColors.info.withOpacity(0.5);
      case 'delivered':        return AppColors.border;
      case 'cancelled':        return AppColors.error.withOpacity(0.5);
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
      default:                 return status.toUpperCase();
    }
  }
}
