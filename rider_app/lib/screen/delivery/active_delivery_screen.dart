import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../network/rider_api_service.dart';
import '../../bloc/delivery/delivery_bloc.dart';
import '../../bloc/delivery/delivery_event.dart';
import '../../bloc/delivery/delivery_state.dart';
import '../../model/delivery_order_model.dart';
import '../../service/socket_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/navigation_launcher.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../hive/hive_service.dart';
import 'customer_chat_screen.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final DeliveryOrder order;

  const ActiveDeliveryScreen({super.key, required this.order});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  late DeliveryOrder _order;
  StreamSubscription? _socketSub;
  StreamSubscription? _chatSub;
  int _unreadCustomerChatCount = 0;
  int _totalCitizenMsgs = 0;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;

    _socketSub = RiderSocketService().onOrderStatusUpdate.listen((data) {
      if (!mounted) return;
      final incomingId = data['orderId']?.toString();
      if (incomingId == _order.orderId) {
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
      }
    });

    // Ensure socket is subscribed to live chat for this order
    if (_order.orderId.isNotEmpty) {
      RiderSocketService().subscribeToChat(_order.orderId);
    }

    // Fetch initial chat history to compute persistent unread count
    _fetchInitialChatHistory();

    // Listen for real-time messages from customer to show unread indicator badge
    _chatSub = RiderSocketService().onChatMessage.listen((data) {
      if (!mounted) return;
      final incomingId = data['orderId']?.toString();
      final senderRole = data['senderRole']?.toString();
      debugPrint('⚡ [ActiveDeliveryScreen] onChatMessage received: $incomingId, senderRole: $senderRole');
      if (incomingId == _order.orderId && senderRole == 'citizen') {
        setState(() {
          _totalCitizenMsgs++;
          _unreadCustomerChatCount++;
        });
      }
    });
  }

  Future<void> _fetchInitialChatHistory() async {
    if (_order.orderId.isEmpty) return;
    try {
      final history = await RiderApiService.fetchOrderChat(_order.orderId);
      if (mounted && history.isNotEmpty) {
        final citizenMsgs = history.where((m) => m['senderRole'] == 'citizen').length;
        _totalCitizenMsgs = citizenMsgs;
        final readCount = HiveService.getLastReadChatCount(_order.orderId);
        final unread = (citizenMsgs > readCount) ? (citizenMsgs - readCount) : 0;
        setState(() {
          _unreadCustomerChatCount = unread;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return BlocListener<DeliveryBloc, DeliveryState>(
      listener: (context, state) {
        if (state is DeliveryLoaded) {
          // If order is completed, safely pop back to dashboard with celebration
          final found = state.activeOrders.where((o) => o.orderId == _order.orderId).toList();
          if (found.isEmpty && !_isPopping) {
            _isPopping = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              final isReturned = state.completedOrders.any((o) =>
                  o.orderId == _order.orderId &&
                  (o.status == 'returned_to_store' || o.status == 'returned'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isReturned
                      ? '📦 Order #${_order.orderId} return verified & received by Store!'
                      : '🎉 Order #${_order.orderId} Delivered Successfully! '),
                  backgroundColor: isReturned ? const Color(0xFFE65100) : AppColors.success,
                  duration: const Duration(seconds: 4),
                ),
              );
            });
          } else if (found.isNotEmpty) {
            setState(() {
              _order = found.first;
            });
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: CustomText.title('Order #${_order.orderId}', fontWeight: FontWeight.bold),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: Responsive.w(16)),
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(4)),
              decoration: BoxDecoration(
                color: _order.status == 'returning_to_store'
                    ? const Color(0xFFFF9800).withValues(alpha: 0.18)
                    : (_order.status == 'return_pickup_assigned'
                        ? const Color(0xFF9C27B0).withValues(alpha: 0.18)
                        : (_order.status == 'out_for_delivery'
                            ? AppColors.info.withValues(alpha: 0.15)
                            : AppColors.warning.withValues(alpha: 0.15))),
                borderRadius: BorderRadius.circular(Responsive.w(12)),
              ),
              child: Center(
                child: CustomText.caption(
                  _order.status == 'returning_to_store'
                      ? 'RETURNING TO STORE'
                      : (_order.status == 'return_pickup_assigned'
                          ? 'REVERSE PICKUP'
                          : (_order.status == 'out_for_delivery'
                              ? 'ON THE WAY'
                              : (_order.status == 'accepted'
                                  ? 'ACCEPTED ✔'
                                  : (_order.status == 'ready_for_pickup'
                                      ? 'READY FOR PICKUP'
                                      : (_order.status == 'preparing' ? 'STORE PACKING' : 'PENDING PACKING'))))),
                  color: _order.status == 'returning_to_store'
                      ? const Color(0xFFE65100)
                      : (_order.status == 'return_pickup_assigned'
                          ? const Color(0xFF7B1FA2)
                          : (_order.status == 'out_for_delivery'
                              ? AppColors.info
                              : (_order.status == 'accepted'
                                  ? AppColors.success
                                  : (_order.status == 'ready_for_pickup' ? AppColors.warning : AppColors.warning)))),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: CommonBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.w(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // REVERSE PICKUP ASSIGNED BANNER
                  if (_order.status == 'return_pickup_assigned') ...[
                    Container(
                      margin: EdgeInsets.only(bottom: Responsive.h(16)),
                      padding: EdgeInsets.all(Responsive.w(14)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(Responsive.w(14)),
                        border: Border.all(color: const Color(0xFFCE93D8), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz_rounded, color: Color(0xFF7B1FA2), size: 28),
                          SizedBox(width: Responsive.w(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText.title('Reverse Pickup · Doorstep Collection', fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF7B1FA2)),
                                SizedBox(height: Responsive.h(3)),
                                CustomText.caption(
                                  'Reason: ${_order.returnDetails?['reason'] ?? 'Citizen Return'}',
                                  color: Colors.purple.shade900,
                                ),
                                SizedBox(height: Responsive.h(2)),
                                CustomText.caption(
                                  'Go to customer doorstep to collect returned items, then deliver back to store.',
                                  color: Colors.purple.shade700,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // RETURNING TO STORE ALERT BANNER
                  if (_order.status == 'returning_to_store') ...[
                    Container(
                      margin: EdgeInsets.only(bottom: Responsive.h(16)),
                      padding: EdgeInsets.all(Responsive.w(14)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(Responsive.w(14)),
                        border: Border.all(color: const Color(0xFFFFB74D), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_return_rounded, color: Color(0xFFE65100), size: 28),
                          SizedBox(width: Responsive.w(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText.title('Returning Package to Store', fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFFE65100)),
                                SizedBox(height: Responsive.h(3)),
                                CustomText.caption(
                                  'Reason: ${_order.returnDetails?['reason'] ?? 'Citizen Return / Doorstep Failure'}',
                                  color: Colors.brown.shade800,
                                ),
                                SizedBox(height: Responsive.h(2)),
                                CustomText.caption(
                                  'Deliver package back to ${_order.storeName}. Store merchant will inspect & confirm return.',
                                  color: Colors.brown.shade600,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Step Progress Indicator
                  _buildProgressTracker(),
                  SizedBox(height: Responsive.h(20)),

                  // DYNAMIC CARD ORDER (Reverse Pickup goes to Customer FIRST, then Store SECOND)
                  if (_order.isReversePickup) ...[
                    // STEP 1: CUSTOMER DOORSTEP PICKUP CARD
                    _buildCustomerDropCard(),
                    SizedBox(height: Responsive.h(16)),

                    // STEP 2: STORE RETURN CARD
                    _buildStorePickupCard(),
                    SizedBox(height: Responsive.h(16)),
                  ] else ...[
                    // STEP 1: STORE PICKUP CARD
                    _buildStorePickupCard(),
                    SizedBox(height: Responsive.h(16)),

                    // STEP 2: CUSTOMER DROP CARD
                    _buildCustomerDropCard(),
                    SizedBox(height: Responsive.h(16)),
                  ],

                  // ORDER ITEMS CHECKLIST
                  _buildItemsCard(),
                  SizedBox(height: Responsive.h(16)),

                  // PAYMENT SUMMARY
                  _buildPaymentSummaryCard(),
                  SizedBox(height: Responsive.h(30)),

                  // ACTION BUTTON (Pick up or Mark Delivered)
                  _buildActionControls(context),
                  SizedBox(height: Responsive.h(20)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Progress tracker
  // --------------------------------------------------------------------------
  Widget _buildProgressTracker() {
    if (_order.isReversePickup) {
      final isAssigned = _order.status == 'return_pickup_assigned';
      final isReturning = _order.status == 'returning_to_store';
      return Container(
        padding: EdgeInsets.all(Responsive.w(16)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(14)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _stepNode(1, 'Assigned', true, false),
            Expanded(
              child: Container(
                height: 3,
                color: isReturning ? const Color(0xFFE65100) : const Color(0xFF7B1FA2),
              ),
            ),
            _stepNode(2, 'Customer Pickup', true, isAssigned),
            Expanded(
              child: Container(
                height: 3,
                color: isReturning ? const Color(0xFFE65100) : AppColors.lightGray,
              ),
            ),
            _stepNode(3, 'Store Return', isReturning, isReturning),
          ],
        ),
      );
    }

    final isAccepted = _order.status == 'accepted';
    final isOut = _order.status == 'out_for_delivery';

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _stepNode(1, 'Accepted', true, (!isAccepted && !isOut) ? true : isAccepted),
          Expanded(
            child: Container(
              height: 3,
              color: (isAccepted || isOut) ? AppColors.success : AppColors.lightGray,
            ),
          ),
          _stepNode(2, 'Store Pickup', isOut ? true : false, isOut ? false : false),
          Expanded(
            child: Container(
              height: 3,
              color: isOut ? AppColors.success : AppColors.lightGray,
            ),
          ),
          _stepNode(3, 'Customer Drop', isOut ? true : false, isOut ? true : false),
        ],
      ),
    );
  }

  Widget _stepNode(int step, String label, bool reached, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: Responsive.w(14),
          backgroundColor: reached ? (active ? AppColors.primary : AppColors.success) : AppColors.lightGray,
          child: Text(
            '$step',
            style: TextStyle(
              fontSize: Responsive.sp(12),
              fontWeight: FontWeight.bold,
              color: reached ? Colors.white : AppColors.grayFont,
            ),
          ),
        ),
        SizedBox(height: Responsive.h(4)),
        CustomText.caption(
          label,
          fontSize: Responsive.sp(11),
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? AppColors.primary : AppColors.grayFont,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Store Pickup / Return Card
  // --------------------------------------------------------------------------
  Widget _buildStorePickupCard() {
    final isRev = _order.isReversePickup;
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: isRev ? const Color(0xFFFFB74D) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(8)),
                decoration: BoxDecoration(
                  color: isRev
                      ? const Color(0xFFE65100).withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRev ? Icons.assignment_return_rounded : Icons.storefront_rounded,
                  color: isRev ? const Color(0xFFE65100) : AppColors.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: Responsive.w(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.caption(
                      isRev ? 'STEP 2: RETURN TO STORE' : 'STEP 1: PICKUP FROM STORE',
                      color: isRev ? const Color(0xFFE65100) : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText.title(_order.storeName, fontSize: Responsive.sp(15), fontWeight: FontWeight.bold),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(10)),
          CustomText.body(_order.storeAddress, fontSize: Responsive.sp(13)),
          SizedBox(height: Responsive.h(14)),

          // Navigation & Call Store buttons
          Row(
            children: [
              // Google Maps button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    NavigationLauncher.openGoogleMapsDirections(
                      _order.storeLat,
                      _order.storeLng,
                      label: _order.storeName,
                    );
                  },
                  icon: const Icon(Icons.directions_outlined, size: 18, color: Colors.white),
                  label: Text(
                    isRev ? 'Navigate Back to Store' : 'Navigate to Store',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRev ? const Color(0xFFE65100) : AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(10))),
                  ),
                ),
              ),
              if (_order.storePhone.isNotEmpty) ...[
                SizedBox(width: Responsive.w(8)),
                IconButton.filledTonal(
                  onPressed: () {
                    NavigationLauncher.callPhoneNumber(_order.storePhone);
                  },
                  icon: Icon(Icons.phone, color: isRev ? const Color(0xFFE65100) : AppColors.primary),
                  tooltip: 'Call Store',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Customer Drop / Pickup Card
  // --------------------------------------------------------------------------
  Widget _buildCustomerDropCard() {
    final isRev = _order.isReversePickup;
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: isRev ? const Color(0xFFCE93D8) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(8)),
                decoration: BoxDecoration(
                  color: isRev
                      ? const Color(0xFF7B1FA2).withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRev ? Icons.person_pin_circle_rounded : Icons.location_on_rounded,
                  color: isRev ? const Color(0xFF7B1FA2) : AppColors.success,
                  size: 20,
                ),
              ),
              SizedBox(width: Responsive.w(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.caption(
                      isRev ? 'STEP 1: COLLECT FROM CITIZEN' : 'STEP 2: DELIVER TO CITIZEN',
                      color: isRev ? const Color(0xFF7B1FA2) : AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText.title(_order.receiverName, fontSize: Responsive.sp(15), fontWeight: FontWeight.bold),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(10)),
          CustomText.body(_order.dropAddress, fontSize: Responsive.sp(13)),
          SizedBox(height: Responsive.h(14)),

          // Navigation & Call Customer buttons
          Row(
            children: [
              // Google Maps button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    RiderSocketService().sendLocation(
                      orderId: _order.orderId,
                      latitude: (_order.storeLat + _order.dropLat) / 2,
                      longitude: (_order.storeLng + _order.dropLng) / 2,
                      riderId: _order.riderId,
                    );
                    NavigationLauncher.openGoogleMapsDirections(
                      _order.dropLat,
                      _order.dropLng,
                      label: isRev ? 'Citizen Doorstep Pickup' : 'Citizen Delivery Location',
                    );
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                  label: Text(
                    isRev ? 'Navigate to Customer Doorstep' : 'Navigate to Customer',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRev ? const Color(0xFF7B1FA2) : AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(10))),
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(8)),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _unreadCustomerChatCount = 0;
                      });
                      if (_order.orderId.isNotEmpty) {
                        HiveService.setLastReadChatCount(_order.orderId, _totalCitizenMsgs);
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => CustomerChatScreen(
                            orderId: _order.orderId,
                            customerName: _order.receiverName,
                            customerPhone: _order.receiverPhone,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) {
                          setState(() => _unreadCustomerChatCount = 0);
                          if (_order.orderId.isNotEmpty) {
                            HiveService.setLastReadChatCount(_order.orderId, _totalCitizenMsgs);
                          }
                        }
                      });
                    },
                    icon: Icon(Icons.chat_bubble_outline_rounded, color: isRev ? const Color(0xFF7B1FA2) : AppColors.success),
                    tooltip: 'Chat with Customer',
                  ),
                  if (_unreadCustomerChatCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '$_unreadCustomerChatCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: Responsive.w(8)),
              IconButton.filledTonal(
                onPressed: () {
                  if (_order.receiverPhone.isNotEmpty) {
                    NavigationLauncher.callPhoneNumber(_order.receiverPhone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Customer phone number not available for this order.'),
                        backgroundColor: Color(0xFFE65100),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.phone, color: isRev ? const Color(0xFF7B1FA2) : AppColors.success),
                tooltip: 'Call Customer',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Items Checklist Card
  // --------------------------------------------------------------------------
  Widget _buildItemsCard() {
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText.title('Items to Verify (${_order.items.length})', fontSize: Responsive.sp(14)),
              const Icon(Icons.checklist_rounded, color: AppColors.grayFont, size: 20),
            ],
          ),
          const Divider(height: 20),
          ..._order.items.map((item) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: Responsive.h(6)),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}x',
                        style: TextStyle(
                          fontSize: Responsive.sp(11),
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.w(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText.title(item.title, fontSize: Responsive.sp(13)),
                        CustomText.caption(item.unit, fontSize: Responsive.sp(11)),
                      ],
                    ),
                  ),
                  CustomText.title('₹${(item.price * item.quantity).toStringAsFixed(0)}', fontSize: Responsive.sp(13)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Payment Summary Card
  // --------------------------------------------------------------------------
  Widget _buildPaymentSummaryCard() {
    final isPrepaid = _order.paymentStatus == 'paid';

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.title('Payment & Collection', fontSize: Responsive.sp(14)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText.body('Payment Mode'),
              CustomText.title(_order.paymentMethod, fontSize: Responsive.sp(13)),
            ],
          ),
          SizedBox(height: Responsive.h(6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText.body('Payment Status'),
              SizedBox(width: Responsive.w(8)),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(2)),
                  decoration: BoxDecoration(
                    color: isPrepaid ? AppColors.success.withValues(alpha: 0.12) : AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPrepaid ? 'PREPAID ONLINE' : 'COLLECT CASH ON DELIVERY',
                    style: TextStyle(
                      fontSize: Responsive.sp(11),
                      fontWeight: FontWeight.bold,
                      color: isPrepaid ? AppColors.success : AppColors.error,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText.body('Total Bill Amount'),
              CustomText.title('₹${_order.grandTotal.toStringAsFixed(0)}', fontSize: Responsive.sp(15), fontWeight: FontWeight.bold),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText.title('Your Payout for this trip', color: AppColors.success),
              CustomText.title('₹${_order.estimatedPayout.toStringAsFixed(0)}', color: AppColors.success, fontWeight: FontWeight.bold),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Action Controls (Confirm Pickup or Mark Delivered)
  // --------------------------------------------------------------------------
  Widget _buildActionControls(BuildContext context) {
    final isOut = _order.status == 'out_for_delivery';
    // Both 'accepted' and legacy 'ready_for_pickup' show the store-pickup button
    final isPrePickup = _order.status == 'accepted' || _order.status == 'ready_for_pickup';

    if (isPrePickup) {
      return SizedBox(
        width: double.infinity,
        height: Responsive.h(54),
        child: ElevatedButton.icon(
          onPressed: () {
            RiderSocketService().sendLocation(
              orderId: _order.orderId,
              latitude: _order.storeLat,
              longitude: _order.storeLng,
              riderId: _order.riderId,
            );
            context.read<DeliveryBloc>().add(ConfirmStorePickupEvent(_order.orderId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order picked up from store! Now navigate to customer drop address.'),
                backgroundColor: AppColors.info,
              ),
            );
          },
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: const Text(
            'Confirm Store Pickup',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
          ),
        ),
      );
    } else if (isOut) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: Responsive.h(54),
            child: ElevatedButton.icon(
              onPressed: () {
                _showDeliveryConfirmationDialog(context);
              },
              icon: const Icon(Icons.task_alt_rounded, color: Colors.white),
              label: const Text(
                'Confirm Delivered to Customer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(12)),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(50),
            child: OutlinedButton.icon(
              onPressed: () {
                _showDoorstepReturnBottomSheet(context);
              },
              icon: const Icon(Icons.assignment_return_rounded, color: Color(0xFFD32F2F)),
              label: const Text(
                'Unable to Deliver / Return to Store',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
                backgroundColor: const Color(0xFFFFEBEE),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
              ),
            ),
          ),
        ],
      );
    } else if (_order.status == 'return_pickup_assigned') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: Responsive.h(54),
            child: ElevatedButton.icon(
              onPressed: () {
                NavigationLauncher.openGoogleMapsDirections(
                  _order.dropLat,
                  _order.dropLng,
                  label: _order.receiverName.isNotEmpty ? _order.receiverName : 'Customer Location',
                );
              },
              icon: const Icon(Icons.navigation_rounded, color: Colors.white),
              label: const Text(
                'Navigate to Customer Doorstep',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(12)),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(52),
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Item Collected'),
                    content: const Text('Have you collected the returned package/items from the customer?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B1FA2)),
                        child: const Text('Yes, Collected', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  final ok = await RiderApiService.updateOrderStatus(
                    orderId: _order.orderId,
                    status: 'returning_to_store',
                  );
                  if (ok && context.mounted) {
                    context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Items collected! Now navigate back to store to return to merchant.'),
                        backgroundColor: Color(0xFFE65100),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                'Confirm Return Collected from Customer',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
              ),
            ),
          ),
        ],
      );
    } else if (_order.status == 'returning_to_store') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: Responsive.h(54),
            child: ElevatedButton.icon(
              onPressed: () {
                NavigationLauncher.openGoogleMapsDirections(
                  _order.storeLat,
                  _order.storeLng,
                  label: _order.storeName,
                );
              },
              icon: const Icon(Icons.navigation_rounded, color: Colors.white),
              label: const Text(
                'Navigate Back to Store',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(10)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(10)),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(Responsive.w(12)),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: Colors.grey, size: 20),
                SizedBox(width: Responsive.w(8)),
                Expanded(
                  child: CustomText.caption(
                    'Hand over package to merchant. Store will confirm return & restock items.',
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // Fallback: order in an intermediate state (e.g. still appearing in a stale list)
    return const SizedBox.shrink();
  }

  void _showDeliveryConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Delivery?'),
        content: Text(
          'Have you handed over the order items to ${_order.receiverName} at ${_order.dropAddress}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              RiderSocketService().sendLocation(
                orderId: _order.orderId,
                latitude: _order.dropLat,
                longitude: _order.dropLng,
                riderId: _order.riderId,
              );
              context.read<DeliveryBloc>().add(ConfirmDeliveredEvent(_order.orderId));
              try {
                const MethodChannel('com.hikizo.goGovernment_riderapp/app_launcher')
                    .invokeMethod('dismissOrderOverlay');
              } catch (_) {}
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🎉 Order #${_order.orderId} delivered successfully!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Yes, Delivered', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDoorstepReturnBottomSheet(BuildContext context) {
    String selectedReason = 'Customer Phone Not Reachable';
    final notesController = TextEditingController();
    final reasons = [
      'Customer Phone Not Reachable',
      'Door Locked / Customer Unavailable',
      'Address Not Found / Incorrect Location',
      'Customer Rejected Package at Doorstep',
      'Damaged in Transit / Leaked',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: Responsive.w(20),
            right: Responsive.w(20),
            top: Responsive.h(20),
            bottom: MediaQuery.of(ctx).viewInsets.bottom + Responsive.h(20),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(24))),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: Responsive.w(40),
                    height: 4,
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
                      padding: EdgeInsets.all(Responsive.w(8)),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFD32F2F), size: 24),
                    ),
                    SizedBox(width: Responsive.w(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.title('Unable to Deliver?', fontSize: 18, fontWeight: FontWeight.bold),
                          CustomText.caption('Initiate return of package back to store', color: AppColors.grayFont),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(18)),
                CustomText.caption('SELECT REASON', fontWeight: FontWeight.bold, color: AppColors.grayFont),
                SizedBox(height: Responsive.h(8)),
                ...reasons.map((r) {
                  final isSelected = selectedReason == r;
                  return InkWell(
                    onTap: () => setModalState(() => selectedReason = r),
                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                    child: Container(
                      margin: EdgeInsets.only(bottom: Responsive.h(8)),
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(10)),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFF3E0) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF9800) : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? const Color(0xFFE65100) : Colors.grey.shade400,
                            size: 20,
                          ),
                          SizedBox(width: Responsive.w(10)),
                          Expanded(
                            child: Text(
                              r,
                              style: TextStyle(
                                fontSize: Responsive.sp(13.5),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? const Color(0xFFE65100) : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(height: Responsive.h(10)),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Additional details or notes (optional)',
                    hintStyle: TextStyle(fontSize: Responsive.sp(13), color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: EdgeInsets.all(Responsive.w(12)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Responsive.w(12)),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Responsive.w(12)),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.h(18)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: Responsive.h(14)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: Responsive.w(12)),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final effectiveRiderId = _order.riderId.isNotEmpty ? _order.riderId : HiveService.userId;
                          Navigator.pop(ctx);
                          context.read<DeliveryBloc>().add(
                                InitiateReturnEvent(
                                  orderId: _order.orderId,
                                  riderId: effectiveRiderId,
                                  reason: selectedReason,
                                  notes: notesController.text.trim(),
                                ),
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('📦 Return initiated for Order #${_order.orderId}. Return package to store.'),
                              backgroundColor: const Color(0xFFE65100),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          padding: EdgeInsets.symmetric(vertical: Responsive.h(14)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                        ),
                        child: const Text(
                          'Confirm Return to Store',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
