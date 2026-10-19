import 'dart:async';
import 'package:flutter/material.dart';
import '../model/delivery_order_model.dart';
import '../utils/app_colors.dart';
import '../utils/navigation_launcher.dart';
import '../utils/responsive_helper.dart';
import 'custom_text.dart';

class AvailableOrderCard extends StatefulWidget {
  final DeliveryOrder order;
  final VoidCallback onAccept;
  final VoidCallback onExpired;
  final bool isAccepting;
  final int initialCountdownSecs;

  const AvailableOrderCard({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onExpired,
    this.isAccepting = false,
    this.initialCountdownSecs = 30,
  });

  @override
  State<AvailableOrderCard> createState() => _AvailableOrderCardState();
}

class _AvailableOrderCardState extends State<AvailableOrderCard>
    with SingleTickerProviderStateMixin {
  late int _remaining;
  Timer? _timer;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialCountdownSecs;

    _ringController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.initialCountdownSecs),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        _timer?.cancel();
        _ringController.stop();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final progress = _remaining / widget.initialCountdownSecs;
    final isWarning = _remaining <= 10;
    final ringColor = isWarning ? AppColors.error : AppColors.success;

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(14)),
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(
          color: isWarning ? AppColors.error.withValues(alpha: 0.5) : AppColors.border,
          width: isWarning ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isWarning
                ? AppColors.error.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Order ID + Payout Badge + 30s Countdown Ring
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Order ID & Icon
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(Responsive.w(6)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.primary),
                  ),
                  SizedBox(width: Responsive.w(8)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.title('#${widget.order.orderId}',
                          fontSize: Responsive.sp(14), fontWeight: FontWeight.bold),
                      CustomText.caption(
                        widget.order.isReversePickup ? '🔄 Return Pickup Request' : 'New Order Request',
                        color: widget.order.isReversePickup ? const Color(0xFFD97706) : AppColors.grayFont,
                        fontWeight: widget.order.isReversePickup ? FontWeight.bold : FontWeight.normal,
                      ),
                    ],
                  ),
                ],
              ),

              // Payout Badge & 30s Ring
              Row(
                children: [
                  // Payout Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(10), vertical: Responsive.h(5)),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Responsive.w(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.currency_rupee, size: 14, color: AppColors.success),
                        CustomText.title(
                          '${widget.order.estimatedPayout.toStringAsFixed(0)} Earn',
                          fontSize: Responsive.sp(13),
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: Responsive.w(10)),

                  // 30s Circular Countdown Ring Timer
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: Responsive.w(38),
                        height: Responsive.w(38),
                        child: AnimatedBuilder(
                          animation: _ringController,
                          builder: (_, __) => CircularProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            strokeWidth: 3.5,
                            backgroundColor: AppColors.lightGray,
                            valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                          ),
                        ),
                      ),
                      Text(
                        '${_remaining > 0 ? _remaining : 0}s',
                        style: TextStyle(
                          fontSize: Responsive.sp(11),
                          fontWeight: FontWeight.bold,
                          color: ringColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: Responsive.h(14)),

          // Step 1: Pickup Location (Store for normal, Citizen for reverse return)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.order.isReversePickup ? Icons.person_pin_circle_rounded : Icons.store,
                size: 16,
                color: widget.order.isReversePickup ? const Color(0xFFD97706) : AppColors.primary,
              ),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title(
                      widget.order.isReversePickup ? 'Pickup: ${widget.order.receiverName}' : widget.order.storeName,
                      fontSize: Responsive.sp(13),
                    ),
                    CustomText.caption(
                      widget.order.isReversePickup ? widget.order.dropAddress : widget.order.storeAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(8)),

          // Step 2: Destination Location (Citizen for normal, Store for reverse return)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.order.isReversePickup ? Icons.store : Icons.location_on,
                size: 16,
                color: widget.order.isReversePickup ? AppColors.primary : AppColors.success,
              ),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title(
                      widget.order.isReversePickup ? 'Return To: ${widget.order.storeName}' : 'Drop: ${widget.order.receiverName}',
                      fontSize: Responsive.sp(13),
                    ),
                    CustomText.caption(
                      widget.order.isReversePickup ? widget.order.storeAddress : widget.order.dropAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(14)),

          // Action Buttons: Google Maps Direction Preview & Accept Order
          Row(
            children: [
              // Google Maps Preview Button
              IconButton(
                onPressed: () {
                  final targetLat = widget.order.isReversePickup ? widget.order.dropLat : widget.order.storeLat;
                  final targetLng = widget.order.isReversePickup ? widget.order.dropLng : widget.order.storeLng;
                  NavigationLauncher.openGoogleMapsDirections(
                    targetLat,
                    targetLng,
                    label: widget.order.isReversePickup ? 'Citizen Pickup Location' : 'Store Location',
                  );
                },
                icon: const Icon(Icons.map_outlined, color: AppColors.primary),
                tooltip: 'Preview route in Google Maps',
              ),
              SizedBox(width: Responsive.w(8)),

              // Accept Button
              Expanded(
                child: SizedBox(
                  height: Responsive.h(44),
                  child: ElevatedButton(
                    onPressed: widget.isAccepting ? null : widget.onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.order.isReversePickup ? const Color(0xFFD97706) : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                      ),
                    ),
                    child: widget.isAccepting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check, size: 18, color: Colors.white),
                              SizedBox(width: Responsive.w(6)),
                              const Text(
                                'Accept Delivery',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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
}
