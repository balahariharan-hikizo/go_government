import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../network/order_api_service.dart';
import '../../../service/socket_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../widget/common_map.dart';
import '../../../utils/call_launcher.dart';
import '../../../constants/route_constants.dart';
import '../../../model/address_model.dart';
import '../../../bloc/order_tracking/order_tracking_bloc.dart';
import '../../../bloc/order_tracking/order_tracking_event.dart';
import '../../../bloc/order_tracking/order_tracking_state.dart';
import '../../../bloc/address/address_bloc.dart';
import '../../../bloc/address/address_event.dart';
import '../../../bloc/profile/profile_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../bloc/transaction/transaction_event.dart';

class OrderStatusScreen extends StatefulWidget {
  final String storeType;
  final Map<String, dynamic>? transaction;
  final String? orderId;

  const OrderStatusScreen({
    super.key,
    required this.storeType,
    this.transaction,
    this.orderId,
  });

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen>
    with SingleTickerProviderStateMixin {
  int get _currentStep => context.read<OrderTrackingBloc>().state.currentStep;

  String _receiverName = '';
  String _receiverPhone = '';
  String _deliveryAddress = '';
  late String _orderId;
  Map<String, dynamic>? _serverOrderData;
  StreamSubscription? _socketSub;
  StreamSubscription? _riderLocationSub;
  Timer? _pollTimer;
  double? _riderLat;
  double? _riderLng;

  late final AnimationController _routeAnimController;

  @override
  void initState() {
    super.initState();
    _routeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    final rawTx = widget.transaction;
    _orderId = (widget.orderId != null && widget.orderId!.isNotEmpty)
        ? widget.orderId!
        : (rawTx?['orderId']?.toString().isNotEmpty == true)
        ? rawTx!['orderId'].toString()
        : (rawTx?['id']?.toString().isNotEmpty == true)
        ? rawTx!['id'].toString()
        : '';

    debugPrint('🔍 [OrderStatusScreen] Tracking Order ID: "$_orderId"');

    final profile = context.read<ProfileBloc>().state;
    if (profile.name.trim().isNotEmpty) {
      _receiverName = profile.name.trim();
    }
    if (profile.phone.trim().isNotEmpty) {
      _receiverPhone = profile.phone.trim();
    }

    if (widget.transaction?['address'] != null &&
        widget.transaction!['address'].toString().isNotEmpty) {
      _deliveryAddress = widget.transaction!['address'].toString();
    } else {
      final initialAddr = context.read<AddressBloc>().state.selectedAddress;
      if (initialAddr != null) {
        _deliveryAddress = initialAddr.description;
      }
    }

    if (widget.transaction != null) {
      context.read<OrderTrackingBloc>().add(
        SetTrackingOrderEvent(widget.transaction!),
      );
    }

    // Fetch initial order details once
    _fetchInitialOrder();

    // Ensure WebSocket is connected and subscribed to this order
    SocketService().init();
    if (_orderId.isNotEmpty) {
      SocketService().subscribeToOrder(_orderId);
    }

    _socketSub = SocketService().onOrderStatusUpdate.listen((orderData) {
      if (!mounted) return;
      final incomingId =
          orderData['orderId']?.toString() ?? orderData['id']?.toString();
      debugPrint(
        '⚡ [OrderStatusScreen] onOrderStatusUpdate incomingId: $incomingId, trackedId: $_orderId',
      );
      if (incomingId == _orderId || _orderId.isEmpty) {
        _applyOrderUpdate(orderData);
      }
    });

    _riderLocationSub = SocketService().onRiderLocation.listen((locData) {
      if (!mounted) return;
      final incomingId = locData['orderId']?.toString();
      if (incomingId == _orderId || _orderId.isEmpty) {
        setState(() {
          _riderLat = (locData['latitude'] as num?)?.toDouble();
          _riderLng = (locData['longitude'] as num?)?.toDouble();
        });
      }
    });

    // 4-second lightweight polling fallback while order is active
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final current = context.read<OrderTrackingBloc>().state.currentStep;
      if (current < 4) {
        _fetchInitialOrder();
      }
    });
  }

  @override
  void dispose() {
    _routeAnimController.dispose();
    _pollTimer?.cancel();
    _socketSub?.cancel();
    _riderLocationSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialOrder() async {
    if (_orderId.isEmpty) return;
    try {
      final order = await OrderApiService.fetchOrderDetails(_orderId);
      if (order != null && mounted) {
        _applyOrderUpdate(order);
      }
    } catch (_) {}
  }

  void _applyOrderUpdate(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().toLowerCase().trim();
    if (status == 'cancelled') {
      context.read<OrderTrackingBloc>().add(
        CancelActiveOrderEvent(
          orderId: _orderId,
          reason: 'Cancelled by store or user',
        ),
      );
      context.read<TransactionBloc>().add(
        UpdateOrderStatusEvent(orderId: _orderId, status: 'Cancelled'),
      );
      setState(() {
        _serverOrderData = order;
      });
      return;
    }

    int step = 0;
    if (status == 'placed') {
      step = 0;
    } else if (status == 'preparing') {
      step = 1;
    } else if (status == 'ready_for_pickup') {
      step = 2;
    } else if (status == 'accepted') {
      // Rider accepted — on the way to store for pickup
      step = 2;
    } else if (status == 'out_for_delivery') {
      step = 3;
    } else if (status == 'delivered') {
      step = 4;
    }

    final current = context.read<OrderTrackingBloc>().state.currentStep;
    if (step != current) {
      context.read<OrderTrackingBloc>().add(UpdateTrackingStepEvent(step));
      if (step == 4) {
        context.read<TransactionBloc>().add(
          UpdateOrderStatusEvent(orderId: _orderId, status: 'Delivered'),
        );
      }
    }

    setState(() {
      _serverOrderData = order;

      final addr = order['deliveryAddress'];
      if (addr is Map) {
        if (addr['address'] != null && addr['address'].toString().isNotEmpty) {
          _deliveryAddress = addr['address'].toString();
        }
        if (addr['receiverName'] != null &&
            addr['receiverName'].toString().isNotEmpty) {
          _receiverName = addr['receiverName'].toString();
        }
        if (addr['receiverPhone'] != null &&
            addr['receiverPhone'].toString().isNotEmpty) {
          _receiverPhone = addr['receiverPhone'].toString();
        }
      }
    });
  }

  Future<void> _cancelOrderByCitizen() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order?'),
        content: const Text(
          'Are you sure you want to cancel this order? If paid via wallet, your money will be immediately refunded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await OrderApiService.updateOrderStatus(
        orderId: _orderId,
        status: 'cancelled',
      );
      if (success && mounted) {
        context.read<OrderTrackingBloc>().add(
          CancelActiveOrderEvent(
            orderId: _orderId,
            reason: 'Cancelled by customer',
          ),
        );
        context.read<TransactionBloc>().add(
          UpdateOrderStatusEvent(orderId: _orderId, status: 'Cancelled'),
        );
        setState(() {
          if (_serverOrderData != null) {
            _serverOrderData!['status'] = 'cancelled';
          }
        });
        final payMethod =
            (_serverOrderData?['paymentMethod'] ??
                    widget.transaction?['paymentMethod'] ??
                    '')
                .toString()
                .toLowerCase();
        final bool isWallet = payMethod.contains('wallet');
        final grandTotal =
            _serverOrderData?['grandTotal'] ??
            widget.transaction?['grandTotal'] ??
            '';

        // Reload wallet transactions so the refund and balance update immediately
        context.read<TransactionBloc>().add(LoadTransactionsEvent());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isWallet
                  ? 'Order cancelled. ₹$grandTotal refunded to your wallet.'
                  : 'Order cancelled successfully.',
            ),
            backgroundColor: isWallet
                ? const Color(0xFF2E7D32)
                : AppColors.grayFont,
          ),
        );
      }
    }
  }

  final List<String> _statusTitles = [
    'Arriving on time!',
    'Preparing your order',
    'Ready! Rider coming to pick up',
    'Rider on the way 🚦',
    'Order Delivered 🎉',
  ];

  /// Returns a more descriptive subtitle based on the raw server status.
  String _getStatusSubtitle(String? rawStatus) {
    switch (rawStatus) {
      case 'placed':
        return 'Order received by the store';
      case 'preparing':
        return 'Store is packing your items';
      case 'ready_for_pickup':
        return 'Packed & waiting for a delivery rider';
      case 'accepted':
        return 'A rider has accepted — heading to store';
      case 'out_for_delivery':
        return 'Rider is on the way to you';
      case 'delivered':
        return 'Successfully delivered!';
      default:
        return 'Processing your order';
    }
  }

  String _getEstimatedTimeDisplay() {
    final createdAt = _serverOrderData?['createdAt']?.toString();
    if (createdAt != null && createdAt.isNotEmpty) {
      final dt = DateTime.tryParse(createdAt)?.toLocal();
      if (dt != null) {
        final est = dt.add(const Duration(minutes: 30));
        final h = est.hour > 12
            ? est.hour - 12
            : (est.hour == 0 ? 12 : est.hour);
        final m = est.minute.toString().padLeft(2, '0');
        final ampm = est.hour >= 12 ? 'pm' : 'am';
        return 'Est: $h:$m $ampm';
      }
    }
    return 'Est: ~25 mins';
  }

  /// Generates a smooth quadratic Bezier curve between two coordinates.
  List<LatLng> _generateCurvedPath(
    LatLng start,
    LatLng end, {
    int pointCount = 60,
    double curvature = 0.22,
  }) {
    final points = <LatLng>[];
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;

    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;

    // Control point offset perpendicularly — negative sign bows the arc downward (south)
    final ctrlLat = midLat + dLng * curvature;
    final ctrlLng = midLng - dLat * curvature;

    for (int i = 0; i <= pointCount; i++) {
      final t = i / pointCount;
      final oneMinusT = 1.0 - t;
      final lat =
          oneMinusT * oneMinusT * start.latitude +
          2 * oneMinusT * t * ctrlLat +
          t * t * end.latitude;
      final lng =
          oneMinusT * oneMinusT * start.longitude +
          2 * oneMinusT * t * ctrlLng +
          t * t * end.longitude;
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  /// Evaluates coordinate on the Bezier curve at parameter t [0.0, 1.0].
  LatLng _getPointOnCurve(
    LatLng start,
    LatLng end,
    double t, {
    double curvature = 0.22,
  }) {
    final clampedT = t.clamp(0.0, 1.0);
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    final ctrlLat = midLat + dLng * curvature;
    final ctrlLng = midLng - dLat * curvature;

    final oneMinusT = 1.0 - clampedT;
    final lat =
        oneMinusT * oneMinusT * start.latitude +
        2 * oneMinusT * clampedT * ctrlLat +
        clampedT * clampedT * end.latitude;
    final lng =
        oneMinusT * oneMinusT * start.longitude +
        2 * oneMinusT * clampedT * ctrlLng +
        clampedT * clampedT * end.longitude;
    return LatLng(lat, lng);
  }

  Widget _buildTrackingMap(int currentStep) {
    final storeDetails =
        _serverOrderData?['storeDetails'] as Map<String, dynamic>?;
    final deliveryAddr =
        _serverOrderData?['deliveryAddress'] as Map<String, dynamic>?;
    final deliveryAgent =
        _serverOrderData?['deliveryAgent'] as Map<String, dynamic>?;

    final storeLat = (storeDetails?['latitude'] as num?)?.toDouble() ?? 12.9716;
    final storeLng =
        (storeDetails?['longitude'] as num?)?.toDouble() ?? 77.5946;
    final storePoint = LatLng(storeLat, storeLng);

    final dropLat = (deliveryAddr?['latitude'] as num?)?.toDouble() ?? 12.9780;
    final dropLng = (deliveryAddr?['longitude'] as num?)?.toDouble() ?? 77.6000;
    final dropPoint = LatLng(dropLat, dropLng);

    // Pre-calculate the curved path points between store and drop destination
    final curvePoints = _generateCurvedPath(
      storePoint,
      dropPoint,
      pointCount: 60,
    );

    final agentLoc = deliveryAgent?['currentLocation'] as Map<String, dynamic>?;
    final defaultRiderPos = _getPointOnCurve(
      storePoint,
      dropPoint,
      currentStep >= 3 ? 0.65 : 0.20,
    );
    final dynamicRiderLat =
        _riderLat ??
        (agentLoc?['latitude'] as num?)?.toDouble() ??
        defaultRiderPos.latitude;
    final dynamicRiderLng =
        _riderLng ??
        (agentLoc?['longitude'] as num?)?.toDouble() ??
        defaultRiderPos.longitude;
    final riderPoint = LatLng(dynamicRiderLat, dynamicRiderLng);

    return AnimatedBuilder(
      animation: _routeAnimController,
      builder: (context, _) {
        final progress = _routeAnimController.value;

        // Calculate animated travelling pulse segment along the curved route
        final totalCount = curvePoints.length;
        final headIdx = (progress * (totalCount - 1)).round().clamp(
          1,
          totalCount - 1,
        );
        final tailIdx = ((progress - 0.28) * (totalCount - 1)).round().clamp(
          0,
          totalCount - 1,
        );
        final animatedActivePoints = curvePoints.sublist(tailIdx, headIdx + 1);

        final pulseHeadPoint = _getPointOnCurve(
          storePoint,
          dropPoint,
          progress,
        );

        final markers = <Marker>[
          // Store marker
          Marker(
            point: storePoint,
            width: 38,
            height: 38,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
          // Drop-off destination marker
          Marker(
            point: dropPoint,
            width: 38,
            height: 38,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.person_pin_circle_rounded,
                color: Colors.blueAccent,
                size: 22,
              ),
            ),
          ),
          // Animated traveling pulse beacon from store to destination
          Marker(
            point: pulseHeadPoint,
            width: 26,
            height: 26,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: Colors.white, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.7),
                      blurRadius: 10,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];

        // Rider marker when active
        if (currentStep >= 2 && currentStep <= 3) {
          markers.add(
            Marker(
              point: riderPoint,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(7),
                child: const Icon(
                  Icons.motorcycle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          );
        }

        final polylines = <Polyline>[
          // Outer subtle glow along the curve
          Polyline(
            points: curvePoints,
            strokeWidth: 6.0,
            color: AppColors.primary.withValues(alpha: 0.12),
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
          // Base curved route path
          Polyline(
            points: curvePoints,
            strokeWidth: 3.5,
            color: AppColors.primary.withValues(alpha: 0.35),
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
          // High-visibility animated pulse segment traveling from store to destination
          if (animatedActivePoints.length >= 2)
            Polyline(
              points: animatedActivePoints,
              strokeWidth: 4.8,
              color: AppColors.primary,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
        ];

        final centerPoint = currentStep >= 3 ? riderPoint : storePoint;

        return CommonMap(
          key: ValueKey('map_${currentStep}_$_orderId'),
          center: centerPoint,
          zoom: 14.5,
          markers: markers,
          polylines: polylines,
          showUserLocation: false,
          mapState: currentStep == 4
              ? MapState.navigation
              : MapState.directions,
          isWalkMode: false,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderTrackingBloc, OrderTrackingState>(
      builder: (context, state) {
        final bool isCancelled =
            state.isCancelled || _serverOrderData?['status'] == 'cancelled';
        final int currentStep = state.currentStep;
        final bool isMapVisible = !isCancelled && currentStep > 0;
        final bool isDriverCardVisible = !isCancelled && currentStep >= 2;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: AppColors.screenColor,
            body: CommonBackground(
              child: Column(
                children: [
                  // ── ORANGE GRADIENT HEADER ──────────────────────────────
                  _buildStatusHeaderBar(),

                  // ── SCROLLABLE CONTENT ───────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        Responsive.w(20),
                        Responsive.h(16),
                        Responsive.w(20),
                        Responsive.h(40),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cancellation alert banner if cancelled
                          if (isCancelled) ...[
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(Responsive.w(16)),
                              margin: EdgeInsets.only(bottom: Responsive.h(16)),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  Responsive.w(16),
                                ),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.cancel_rounded,
                                    color: AppColors.error,
                                    size: 28,
                                  ),
                                  SizedBox(width: Responsive.w(12)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CustomText.title(
                                          'Order Cancelled',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(height: 2),
                                        CustomText.subtitle(
                                          'This order was cancelled. Any amount paid has been refunded to your wallet.',
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 1. Cancelled Illustration, Shopping bag (step 0), or Map (steps 1–4)
                          if (isCancelled) ...[
                            Center(
                              child: Container(
                                height: Responsive.h(180),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(
                                          alpha: 0.08,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.remove_shopping_cart_rounded,
                                        size: 48,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    SizedBox(height: Responsive.h(10)),
                                    CustomText.subtitle(
                                      'Order processing stopped',
                                      fontSize: 13,
                                      color: AppColors.grayFont,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else if (!isMapVisible) ...[
                            Center(
                              child: SizedBox(
                                height: Responsive.h(220),
                                width: double.infinity,
                                child: Image.asset(
                                  'assets/images/bag.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ] else ...[
                            Container(
                              height: Responsive.h(220),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  Responsive.w(20),
                                ),
                                border: Border.all(
                                  color: AppColors.outliner,
                                  width: 1.2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  Responsive.w(18),
                                ),
                                child: _buildTrackingMap(currentStep),
                              ),
                            ),
                          ],
                          SizedBox(height: Responsive.h(20)),

                          // 2. Status summary card with progress dots
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(Responsive.w(16)),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                Responsive.w(24),
                              ),
                              border: Border.all(
                                color: isCancelled
                                    ? AppColors.error.withValues(alpha: 0.3)
                                    : AppColors.outliner,
                                width: Responsive.w(1.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: CustomText.title(
                                        isCancelled
                                            ? 'Cancelled'
                                            : _statusTitles[currentStep],
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isCancelled
                                            ? AppColors.error
                                            : Colors.black87,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: Responsive.w(8)),
                                    if (!isCancelled)
                                      CustomText.title(
                                        _getEstimatedTimeDisplay(),
                                        fontSize: 13,
                                        color: AppColors.grayFont,
                                      ),
                                  ],
                                ),
                                SizedBox(height: Responsive.h(4)),
                                CustomText.subtitle(
                                  isCancelled
                                      ? 'Order was marked as cancelled'
                                      : _getStatusSubtitle(
                                          _serverOrderData?['status']
                                              ?.toString(),
                                        ),
                                  fontSize: 12,
                                  color: AppColors.grayFont,
                                ),
                                if (!isCancelled) ...[
                                  SizedBox(height: Responsive.h(16)),
                                  // Progress dots
                                  Row(
                                    children: List.generate(4, (index) {
                                      final bool isDone = currentStep > index;
                                      final bool isCurrent =
                                          currentStep == index;
                                      return Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              width: Responsive.w(12),
                                              height: Responsive.w(12),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: (isDone || isCurrent)
                                                    ? AppColors.primary
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            if (index < 3)
                                              Expanded(
                                                child: Container(
                                                  height: Responsive.h(2),
                                                  color: isDone
                                                      ? AppColors.primary
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Citizen cancel button if order is in 'placed' state
                          if (!isCancelled &&
                              (_serverOrderData?['status'] == 'placed' ||
                                  currentStep == 0)) ...[
                            SizedBox(height: Responsive.h(12)),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: BorderSide(
                                    color: AppColors.error.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: Responsive.h(12),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.w(12),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text(
                                  'Cancel Order',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                onPressed: _cancelOrderByCitizen,
                              ),
                            ),
                          ],
                          SizedBox(height: Responsive.h(20)),

                          // 3. Driver card (step 2+)
                          if (isDriverCardVisible) ...[
                            _buildDriverDetailCard(),
                            SizedBox(height: Responsive.h(20)),
                          ],

                          // Store contact & details card
                          _buildStoreDetailCard(),
                          SizedBox(height: Responsive.h(20)),

                          // 4. Delivery details
                          _buildDeliveryDetailsCard(),
                          SizedBox(height: Responsive.h(20)),

                          // 5. Order number
                          _buildOrderNumberCard(),
                          SizedBox(height: Responsive.h(20)),

                          // 6. Help card
                          _buildHelpCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeaderBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.outliner, AppColors.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + Responsive.h(16),
        bottom: Responsive.h(16),
        left: Responsive.w(20),
        right: Responsive.w(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      RouteConstants.main,
                      (route) => false,
                    );
                  }
                },
                child: Container(
                  width: Responsive.w(36),
                  height: Responsive.w(36),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white),
                ),
              ),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: Center(
                  child: CustomText.title(
                    _statusTitles[_currentStep],
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(20)),
              // Container(
              //   width: Responsive.w(36),
              //   height: Responsive.w(36),
              //   decoration: const BoxDecoration(
              //     color: Colors.white24,
              //     shape: BoxShape.circle,
              //   ),
              //   child: const Icon(
              //     Icons.reply,
              //     color: Colors.white,
              //     size: 16,
              //   ),
              // ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),

          // White dynamic Arrived/Time status capsule
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(16),
              vertical: Responsive.h(6),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Responsive.w(16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentStep == 4
                      ? 'Arrived '
                      : 'Arriving in 21 mins · On time ',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.refresh, size: 10, color: Colors.black54),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDetailCard() {
    final storeDetails =
        _serverOrderData?['storeDetails'] as Map<String, dynamic>? ??
        widget.transaction?['storeDetails'] as Map<String, dynamic>?;
    final rawName =
        (storeDetails != null &&
            storeDetails['name'] != null &&
            storeDetails['name'].toString().trim().isNotEmpty)
        ? storeDetails['name'].toString().trim()
        : (widget.transaction?['title']?.toString().trim() ?? '');
    final storeName =
        (rawName.isNotEmpty &&
            rawName != 'Bangalore Horticulture' &&
            rawName != 'Apothecary Pharmacy')
        ? rawName
        : (widget.storeType == 'medical' ? 'Medical Store' : 'Vegetable Store');
    final storePhone =
        storeDetails?['phone']?.toString() ??
        widget.transaction?['storePhone']?.toString() ??
        '';
    final storeAddress =
        storeDetails?['address']?.toString() ??
        widget.transaction?['storeAddress']?.toString() ??
        '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(color: AppColors.outliner, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(Responsive.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: Responsive.w(38),
                height: Responsive.w(38),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2EC),
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                ),
                child: Icon(
                  Icons.storefront,
                  color: AppColors.primary,
                  size: Responsive.w(20),
                ),
              ),
              SizedBox(width: Responsive.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title(
                      storeName,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    CustomText.subtitle(
                      storeAddress.isNotEmpty
                          ? storeAddress
                          : 'Partner Merchant Store',
                      fontSize: 10,
                      color: AppColors.grayFont,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (storePhone.isNotEmpty) ...[
            SizedBox(height: Responsive.h(12)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(12),
                vertical: Responsive.h(8),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(Responsive.w(12)),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        size: 14,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: Responsive.w(6)),
                      Text(
                        storePhone,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      CallLauncher.launchCall(
                        context,
                        phone: storePhone,
                        name: storeName,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(12),
                        vertical: Responsive.h(6),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(Responsive.w(16)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.call, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Call Store',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverDetailCard() {
    final agent = _serverOrderData?['deliveryAgent'] as Map<String, dynamic>?;
    final driverName =
        (agent != null &&
            agent['name'] != null &&
            agent['name'].toString().trim().isNotEmpty)
        ? agent['name'].toString()
        : 'Assigned Express Rider';
    final driverPhone = agent?['phone']?.toString() ?? '';
    final vehicleNumber = agent?['vehicleNumber']?.toString() ?? '';
    final rating = agent?['rating']?.toString() ?? '4.9';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(color: Colors.green.shade200, width: 1.0),
      ),
      padding: EdgeInsets.all(Responsive.w(16)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: Responsive.w(38),
                height: Responsive.w(38),
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              SizedBox(width: Responsive.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title(
                      driverName,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText.subtitle(
                      vehicleNumber.isNotEmpty
                          ? '$vehicleNumber · ★ $rating Rating'
                          : '★ $rating Rating · Express Delivery',
                      fontSize: 10,
                      color: Colors.green.shade800,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),

          // Message/Call buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      RouteConstants.riderChat,
                      arguments: driverName,
                    );
                  },
                  child: Container(
                    height: Responsive.h(38),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Responsive.w(19)),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: AppColors.primary,
                          size: Responsive.w(14),
                        ),
                        SizedBox(width: Responsive.w(6)),
                        CustomText.title(
                          'Message',
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(12)),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (driverPhone.isNotEmpty) {
                      final cleaned = driverPhone.replaceAll(
                        RegExp(r'[^\d+]'),
                        '',
                      );
                      final uri = Uri.parse('tel:$cleaned');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                        return;
                      }
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            driverPhone.isNotEmpty
                                ? 'Contacting $driverName at $driverPhone...'
                                : 'Connecting to $driverName...',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: Responsive.h(38),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Responsive.w(19)),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: AppColors.primary,
                          size: Responsive.w(14),
                        ),
                        SizedBox(width: Responsive.w(6)),
                        CustomText.title(
                          'Call',
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(color: AppColors.outliner, width: Responsive.w(1.2)),
      ),
      padding: EdgeInsets.all(Responsive.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.header(
            'All your delivery details in one place',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
          SizedBox(height: Responsive.h(16)),

          // Receiver row info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.phone_android,
                color: Colors.grey,
                size: Responsive.w(14),
              ),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: CustomText.title(
                  '$_receiverName, $_receiverPhone',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final res = await Navigator.of(
                    context,
                  ).pushNamed(RouteConstants.addressBook, arguments: true);
                  if (res != null && res is AddressModel) {
                    if (mounted) {
                      context.read<AddressBloc>().add(
                        SelectActiveAddressEvent(res),
                      );
                    }
                    setState(() {
                      _receiverPhone = res.phone;
                    });
                  }
                },
                child: CustomText.title(
                  'Edit',
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),
          const Divider(height: 1),
          SizedBox(height: Responsive.h(12)),

          // Address row info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Colors.grey,
                size: Responsive.w(14),
              ),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Delivery at ',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          'Work',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(2)),
                    CustomText.title(
                      _deliveryAddress,
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final res = await Navigator.of(
                    context,
                  ).pushNamed(RouteConstants.addressBook, arguments: true);
                  if (res != null && res is AddressModel) {
                    if (mounted) {
                      context.read<AddressBloc>().add(
                        SelectActiveAddressEvent(res),
                      );
                    }
                    setState(() {
                      _deliveryAddress = res.description;
                    });
                  }
                },
                child: CustomText.title(
                  'Edit',
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getResolvedTransaction() {
    if (_serverOrderData != null) {
      final items = _serverOrderData!['items'] as List? ?? [];
      final grandTotal = _serverOrderData!['grandTotal']?.toString() ?? '0';
      final rawServerName = _serverOrderData!['storeDetails']?['name']
          ?.toString()
          .trim();
      final rawTxTitle = widget.transaction?['title']?.toString().trim();
      final storeName =
          (rawServerName != null &&
              rawServerName.isNotEmpty &&
              rawServerName != 'Bangalore Horticulture' &&
              rawServerName != 'Apothecary Pharmacy')
          ? rawServerName
          : ((rawTxTitle != null &&
                    rawTxTitle.isNotEmpty &&
                    rawTxTitle != 'Bangalore Horticulture' &&
                    rawTxTitle != 'Apothecary Pharmacy')
                ? rawTxTitle
                : (widget.storeType == 'medical'
                      ? 'Medical Store'
                      : 'Vegetable Store'));
      return {
        'id': _orderId,
        'title': storeName,
        'subtitle': 'Order placed · Processing',
        'amount': '-₹$grandTotal',
        'isPositive': false,
        'status':
            _statusTitles[_currentStep.clamp(0, _statusTitles.length - 1)],
        'date': 'Today',
        'items': items
            .map(
              (i) => {
                'title': i['name'] ?? i['title'] ?? 'Item',
                'price': '₹${i['price'] ?? 0}',
                'qty': i['quantity'] ?? i['qty'] ?? 1,
                'image':
                    i['imageUrl'] ?? i['image'] ?? 'assets/images/product1.png',
              },
            )
            .toList(),
        'address': _deliveryAddress,
        'listingPrice': '₹$grandTotal',
        'sellingPrice': '₹$grandTotal',
        'grandTotal': '₹$grandTotal',
        'paid': '₹$grandTotal',
      };
    }
    if (widget.transaction != null) {
      return Map<String, dynamic>.from(widget.transaction!);
    }
    final String defaultStore = widget.storeType == 'food'
        ? 'Burger King & Cafe'
        : (widget.storeType == 'grocery'
              ? 'Fresh Mart Grocery'
              : 'Apollo Pharmacy');
    return {
      'id': _orderId,
      'title': defaultStore,
      'subtitle': 'Order placed · Processing',
      'amount': '-₹199.00',
      'isPositive': false,
      'status': _statusTitles[_currentStep.clamp(0, _statusTitles.length - 1)],
      'date': 'Today',
      'items': [
        {
          'title': widget.storeType == 'food'
              ? 'Classic Burger Combo'
              : 'Health Essentials',
          'price': '₹ 199.00',
          'qty': 1,
          'image': 'assets/images/product1.png',
        },
      ],
      'address': _deliveryAddress,
      'listingPrice': '₹250.00',
      'sellingPrice': '₹199.00',
      'grandTotal': '₹199.00',
      'paid': '₹199.00',
    };
  }

  Widget _buildOrderNumberCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteConstants.transactionDetails,
          arguments: {
            'title': 'Order Details',
            'transaction': _getResolvedTransaction(),
          },
        );
      },
      child: Container(
        height: Responsive.h(52),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(14)),
          border: Border.all(
            color: AppColors.outliner,
            width: Responsive.w(1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                    size: Responsive.w(18),
                  ),
                  SizedBox(width: Responsive.w(8)),
                  Expanded(
                    child: CustomText.title(
                      'Order #$_orderId',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.w(8)),
            Row(
              children: [
                CustomText.subtitle(
                  'View Details',
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(width: Responsive.w(4)),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    return GestureDetector(
      onTap: () => _showNeedHelpBottomSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: Responsive.w(1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(Responsive.w(16)),
        child: Row(
          children: [
            Container(
              width: Responsive.w(40),
              height: Responsive.w(40),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF2EC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.support_agent,
                color: AppColors.primary,
                size: Responsive.w(22),
              ),
            ),
            SizedBox(width: Responsive.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText.title(
                    'Need help with your order?',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(height: Responsive.h(2)),
                  CustomText.subtitle(
                    'Support, issue resolution & cancellations',
                    fontSize: 10,
                    color: AppColors.grayFont,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(12),
                vertical: Responsive.h(6),
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(Responsive.w(16)),
              ),
              child: CustomText.title(
                'Get Help',
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNeedHelpBottomSheet(BuildContext context) {
    final tx = _getResolvedTransaction();
    final String storeName = tx['title']?.toString() ?? 'Store Order';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Responsive.w(28)),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            Responsive.w(20),
            Responsive.h(12),
            Responsive.w(20),
            MediaQuery.of(sheetCtx).viewInsets.bottom + Responsive.h(28),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag pill
                Center(
                  child: Container(
                    width: Responsive.w(44),
                    height: Responsive.h(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(Responsive.w(2)),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.h(16)),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.header(
                            'Order Help & Support',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: Responsive.h(2)),
                          CustomText.subtitle(
                            '$storeName · #$_orderId',
                            fontSize: 12,
                            color: AppColors.grayFont,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: Responsive.w(8)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(16)),

                // 3 Quick Action Cards
                Row(
                  children: [
                    // Chat with support
                    Expanded(
                      child: _buildQuickHelpAction(
                        icon: Icons.chat_outlined,
                        label: 'Chat Support',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.of(context).pushNamed(
                            RouteConstants.riderChat,
                            arguments: 'Support Agent',
                          );
                        },
                      ),
                    ),
                    SizedBox(width: Responsive.w(10)),

                    // Call helpline
                    Expanded(
                      child: _buildQuickHelpAction(
                        icon: Icons.phone_in_talk_outlined,
                        label: 'Call Helpline',
                        color: const Color(0xFF2E7D32),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _showCallHelplineDialog(context);
                        },
                      ),
                    ),
                    SizedBox(width: Responsive.w(10)),

                    // Cancel order
                    Expanded(
                      child: _buildQuickHelpAction(
                        icon: Icons.cancel_outlined,
                        label: 'Cancel Order',
                        color: const Color(0xFFD32F2F),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _showCancelOrderDialog(context);
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(20)),

                // Report an Issue Header
                CustomText.title(
                  'Report an Issue',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: Responsive.h(4)),
                CustomText.subtitle(
                  'Select any problem with your order for instant assistance',
                  fontSize: 11,
                  color: AppColors.grayFont,
                ),
                SizedBox(height: Responsive.h(12)),

                // Issue options list
                ...[
                  {
                    'icon': Icons.inventory_2_outlined,
                    'title': 'Missing or incorrect items',
                  },
                  {
                    'icon': Icons.access_time_outlined,
                    'title': 'Delivery delayed significantly',
                  },
                  {
                    'icon': Icons.broken_image_outlined,
                    'title': 'Items damaged or poor quality',
                  },
                  {
                    'icon': Icons.two_wheeler_outlined,
                    'title': 'Rider unreachable / delivery concern',
                  },
                  {
                    'icon': Icons.credit_card_outlined,
                    'title': 'Incorrect bill or payment issue',
                  },
                ].map((issue) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: Responsive.h(8)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Responsive.w(12)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _showReportIssueForm(context, issue['title'] as String);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(14),
                          vertical: Responsive.h(12),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                          border: Border.all(
                            color: AppColors.outliner,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              issue['icon'] as IconData,
                              color: AppColors.primary,
                              size: Responsive.w(20),
                            ),
                            SizedBox(width: Responsive.w(12)),
                            Expanded(
                              child: CustomText.title(
                                issue['title'] as String,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                SizedBox(height: Responsive.h(16)),

                // Helpful FAQs
                CustomText.title(
                  'Frequently Asked Questions',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: Responsive.h(10)),
                _buildFaqTile(
                  question: 'Can I change my delivery address?',
                  answer:
                      'If the rider hasn\'t picked up your items yet, please tap "Chat Support" to inform the dispatch team with your new address.',
                ),
                _buildFaqTile(
                  question: 'How do order cancellations work?',
                  answer:
                      'You can cancel free of charge before the merchant packs your order. The full payment is refunded immediately to your wallet.',
                ),
                _buildFaqTile(
                  question: 'Where is my delivery partner?',
                  answer:
                      'Track your rider in real time on the live map above as soon as your items are picked up from the merchant.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickHelpAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Responsive.w(14)),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.0),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: Responsive.w(22)),
            SizedBox(height: Responsive.h(6)),
            CustomText.title(
              label,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(8)),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Responsive.w(12)),
          side: const BorderSide(color: AppColors.outliner, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          tilePadding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
          childrenPadding: EdgeInsets.fromLTRB(
            Responsive.w(12),
            0,
            Responsive.w(12),
            Responsive.h(10),
          ),
          title: CustomText.title(
            question,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          children: [
            CustomText.subtitle(
              answer,
              fontSize: 11,
              color: AppColors.grayFont,
              height: 1.4,
            ),
          ],
        ),
      ),
    );
  }

  void _showCallHelplineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(20)),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(8)),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_in_talk,
                  color: Color(0xFF2E7D32),
                ),
              ),
              SizedBox(width: Responsive.w(10)),
              CustomText.header(
                'Call Support',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.body(
                'Connect directly with our 24/7 Citizen & Order Helpline:',
                fontSize: 13,
              ),
              SizedBox(height: Responsive.h(12)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(Responsive.w(12)),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(Responsive.w(10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title(
                      'Toll-Free Helpline',
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(height: Responsive.h(2)),
                    CustomText.header(
                      '1800-GOV-HELP (1800-468-4357)',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: CustomText.title(
                'Close',
                color: AppColors.grayFont,
                fontSize: 13,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dialing Citizen Helpline 1800-GOV-HELP...'),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
              },
              child: CustomText.title(
                'Dial Now',
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCancelOrderDialog(BuildContext context) {
    String selectedReason = 'Placed by mistake';
    final List<String> reasons = [
      'Placed by mistake',
      'Delivery time is too long',
      'Need to modify items or address',
      'Other reason',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Responsive.w(20)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(Responsive.w(8)),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                  SizedBox(width: Responsive.w(10)),
                  CustomText.header(
                    'Cancel Order?',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.body(
                      'Are you sure you want to cancel order #$_orderId? 100% of the amount will be refunded directly to your wallet balance.',
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    SizedBox(height: Responsive.h(14)),
                    CustomText.title(
                      'Reason for cancellation:',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: Responsive.h(6)),
                    ...reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedReason = r;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: Responsive.h(6)),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(10),
                            vertical: Responsive.h(8),
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFFF2EC)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              Responsive.w(8),
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey,
                                size: Responsive.w(16),
                              ),
                              SizedBox(width: Responsive.w(8)),
                              Expanded(child: CustomText.body(r, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: CustomText.title(
                    'Keep Order',
                    color: AppColors.grayFont,
                    fontSize: 13,
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Responsive.w(12)),
                    ),
                  ),
                  onPressed: () {
                    context.read<OrderTrackingBloc>().add(
                      CancelActiveOrderEvent(
                        orderId: _orderId,
                        reason: selectedReason,
                      ),
                    );
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Order #$_orderId cancelled. Refund credited to your wallet!',
                        ),
                        backgroundColor: const Color(0xFFD32F2F),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                        ),
                      ),
                    );
                  },
                  child: CustomText.title(
                    'Confirm Cancel',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReportIssueForm(BuildContext context, String issueTitle) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(20)),
          ),
          title: CustomText.header(
            'Report Issue',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(10),
                    vertical: Responsive.h(6),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2EC),
                    borderRadius: BorderRadius.circular(Responsive.w(8)),
                  ),
                  child: CustomText.title(
                    issueTitle,
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Responsive.h(12)),
                CustomText.body(
                  'Please provide any details about what went wrong:',
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                SizedBox(height: Responsive.h(8)),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe the issue...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Responsive.w(10)),
                      borderSide: const BorderSide(color: AppColors.outliner),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: CustomText.title(
                'Cancel',
                color: AppColors.grayFont,
                fontSize: 13,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                final ticketNumber = DateTime.now().millisecondsSinceEpoch
                    .toString()
                    .substring(7);
                showDialog(
                  context: context,
                  builder: (confirmCtx) {
                    return AlertDialog(
                      backgroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Responsive.w(20)),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(Responsive.w(12)),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2E7D32),
                              size: 36,
                            ),
                          ),
                          SizedBox(height: Responsive.h(12)),
                          CustomText.header(
                            'Ticket #TKT-$ticketNumber Created',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          SizedBox(height: Responsive.h(6)),
                          CustomText.body(
                            'Thank you for reporting. Our support desk has received your issue and will resolve it promptly.',
                            fontSize: 12,
                            textAlign: TextAlign.center,
                            color: Colors.grey.shade700,
                          ),
                        ],
                      ),
                      actions: [
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.w(12),
                                ),
                              ),
                            ),
                            onPressed: () => Navigator.pop(confirmCtx),
                            child: CustomText.title(
                              'Done',
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              child: CustomText.title(
                'Submit Ticket',
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
}
