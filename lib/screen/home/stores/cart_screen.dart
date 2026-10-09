import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_government/bloc/coupon/coupon_bloc.dart';
import 'package:go_government/bloc/coupon/coupon_event.dart';
import 'package:go_government/utils/app_colors.dart';
import '../../../bloc/address/address_bloc.dart';
import '../../../bloc/address/address_event.dart';
import 'package:go_government/bloc/coupon/coupon_state.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../constants/route_constants.dart';
import '../../../model/address_model.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../bloc/transaction/transaction_event.dart';
import '../../../service/cart_manager.dart';
import '../../../widget/common_wishlist_button.dart';
import '../../../network/api_client.dart';
import '../../../network/order_api_service.dart';
import '../../../network/product_api_service.dart';
import '../../../hive/hive_service.dart';

class CartScreen extends StatefulWidget {
  final String storeType; // 'medical' or 'vegstore'

  const CartScreen({
    super.key,
    required this.storeType,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Removed local coupon state; using CouponBloc
  String _deliveryAddress = '';
  String? _receiverName;
  String? _receiverPhone;
  bool _useComplaintCoins = false;
  bool _isCheckingOut = false;

  // Cross-sell items list (Real-time from store)
  List<Map<String, dynamic>> _crossSellProducts = [];
  late final VoidCallback _cartListener;
  late final VoidCallback _favListener;

  @override
  void initState() {
    super.initState();
    final addrState = context.read<AddressBloc>().state;
    if (addrState.selectedAddress != null) {
      _deliveryAddress = addrState.selectedAddress!.description;
    } else if (addrState.addresses.isNotEmpty) {
      context.read<AddressBloc>().add(SelectActiveAddressEvent(addrState.addresses.first));
      _deliveryAddress = addrState.addresses.first.description;
    }

    _cartListener = () {
      if (mounted) setState(() {});
    };
    _favListener = () {
      if (mounted) setState(() {});
    };
    CartManager.instance.cartItems.addListener(_cartListener);
    WishlistManager.instance.favoriteIds.addListener(_favListener);

    _loadCrossSellProducts();
  }

  Future<void> _loadCrossSellProducts() async {
    final storeId = CartManager.instance.currentStoreId;
    if (storeId == null || storeId.trim().isEmpty) return;

    try {
      final realProducts = await ProductApiService.fetchProductsByStore(
        storeId,
        limit: 10,
        storeType: widget.storeType,
      );

      final filtered = realProducts.where((p) {
        final id = (p['id'] ?? p['productId'] ?? '')?.toString();
        return id != null && id.isNotEmpty && CartManager.instance.getQuantity(id) == 0;
      }).toList();

      if (mounted) {
        setState(() {
          _crossSellProducts = filtered;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    CartManager.instance.cartItems.removeListener(_cartListener);
    WishlistManager.instance.favoriteIds.removeListener(_favListener);
    super.dispose();
  }

  Future<void> _selectAddress() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final selected = await Navigator.of(context).pushNamed(
      RouteConstants.addressBook,
      arguments: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (selected != null && selected is AddressModel) {
      context.read<AddressBloc>().add(SelectActiveAddressEvent(selected));
      setState(() {
        _deliveryAddress = selected.description;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delivering to ${selected.type} (${selected.description})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
        ),
      );
    } else {
      final current = context.read<AddressBloc>().state.selectedAddress;
      setState(() {
        _deliveryAddress = current?.description ?? '';
      });
      if (current == null || current.description.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select or add a delivery address to proceed.'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Select',
              textColor: Colors.white,
              onPressed: () {
                _selectAddress();
              },
            ),
          ),
        );
      }
    }
  }

  // ── Core order placement logic ──────────────────────────────────────────────
  Future<void> _placeOrder({
    required Map<String, int> cartItemsMap,
    required int grandTotal,
    required int itemOriginalTotal,
    required int itemDiscountedTotal,
    required int deliveryCharge,
    required int handlingCharge,
    required int effectiveCouponDiscount,
    required int coinsDiscount,
    required int coinsDeducted,
    required String paymentMethod,
  }) async {
    int parsePrice(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is num) return val.toInt();
      if (val is String) {
        final clean = val.replaceAll('₹', '').replaceAll(',', '').trim();
        final parsed = double.tryParse(clean);
        if (parsed != null) return parsed.toInt();
      }
      return fallback;
    }

    String resolvedStoreId = CartManager.instance.currentStoreId ?? '';
    String dynamicStoreName = CartManager.instance.currentStoreName ?? '';
    final backendItems = <Map<String, dynamic>>[];
    final orderItems = cartItemsMap.entries.map((e) {
      final prod = CartManager.instance.productDetails[e.key] ?? {};
      if (prod['storeId'] != null && prod['storeId'].toString().trim().isNotEmpty) {
        resolvedStoreId = prod['storeId'].toString().trim();
      }
      if (dynamicStoreName.isEmpty) {
        final sName = prod['storeName']?.toString() ?? prod['storeTitle']?.toString();
        if (sName != null && sName.trim().isNotEmpty) {
          dynamicStoreName = sName.trim();
        }
      }
      final p = parsePrice(prod['price'], 83);
      final orig = parsePrice(prod['originalPrice'], 106);
      final basePid = e.key.contains(':') ? e.key.split(':').first : (prod['productId'] ?? e.key).toString();
      final vid = (prod['variantId'] ?? (e.key.contains(':') ? e.key.split(':').last : '')).toString();
      backendItems.add({
        'productId': basePid,
        'variantId': vid,
        'title': prod['title'] ?? 'Product',
        'price': p.toDouble(),
        'originalPrice': orig.toDouble(),
        'quantity': e.value,
        'image': prod['image'] ?? '',
        'unit': prod['unit'] ?? '1 Units',
      });
      return {
        'id': e.key,
        'title': prod['title'] ?? 'Product',
        'price': '₹$p',
        'qty': e.value,
        'image': prod['image'] ?? 'assets/images/product1.png',
      };
    }).toList();

    String orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    String storeTitle = dynamicStoreName.trim().isNotEmpty
        ? dynamicStoreName.trim()
        : (widget.storeType == 'medical' ? 'Medical Store' : 'Vegetable Store');
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final String dateFormatted =
        '${now.day} ${months[now.month - 1]} ${now.year}, ${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'pm' : 'am'}';
    final String shortDate =
        '${months[now.month - 1]} ${now.day} - ${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'pm' : 'am'}';

    final selectedAddr = context.read<AddressBloc>().state.selectedAddress;
    final String deliveryAddr =
        selectedAddr?.description ?? (_deliveryAddress.isNotEmpty ? _deliveryAddress : 'Location not specified');

    if (resolvedStoreId.isEmpty) {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Store information missing. Please re-select items from the store.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Create order in MongoDB backend
    final serverOrder = await OrderApiService.createOrder(
      storeId: resolvedStoreId,
      items: backendItems,
      itemTotal: itemDiscountedTotal.toDouble(),
      deliveryCharge: deliveryCharge.toDouble(),
      handlingCharge: handlingCharge.toDouble(),
      couponDiscount: effectiveCouponDiscount.toDouble(),
      coinsDiscount: coinsDiscount.toDouble(),
      grandTotal: grandTotal.toDouble(),
      paymentMethod: paymentMethod,
      deliveryAddress: {
        'address': deliveryAddr,
        'latitude': selectedAddr?.latitude ?? 12.9784,
        'longitude': selectedAddr?.longitude ?? 77.6408,
        'receiverName': _receiverName ?? HiveService.userName,
        'receiverPhone': _receiverPhone ?? HiveService.userPhone,
      },
      storeDetails: {'storeId': resolvedStoreId, 'name': storeTitle},
    );

    if (serverOrder == null || serverOrder['orderId'] == null) {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to place order. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    orderId = serverOrder['orderId'].toString();
    final backendStoreName = serverOrder['storeDetails']?['name']?.toString().trim();
    if (backendStoreName != null && backendStoreName.isNotEmpty) {
      storeTitle = backendStoreName;
    }

    final newTx = {
      'id': orderId,
      'title': storeTitle,
      'subtitle': 'Sent by you · $shortDate',
      'amount': '-$grandTotal',
      'isPositive': false,
      'status': 'Processing',
      'date': dateFormatted,
      'items': orderItems,
      'address': deliveryAddr,
      'listingPrice': '₹$itemOriginalTotal',
      'sellingPrice': '₹$itemDiscountedTotal',
      'grandTotal': '₹$grandTotal',
      'paid': '₹$grandTotal',
      'paymentMethod': paymentMethod,
    };

    if (!mounted) return;

    // Deduct coins if used
    if (coinsDeducted > 0) {
      // ignore: use_build_context_synchronously
      context.read<TransactionBloc>().add(SpendCoinsEvent(coinsDeducted));
    }

    // Deduct wallet if payment is Wallet
    if (paymentMethod == 'Wallet') {
      // ignore: use_build_context_synchronously
      context.read<TransactionBloc>().add(DeductWalletMoneyEvent(grandTotal.toDouble()));
    }

    // Record transaction in Hive
    // ignore: use_build_context_synchronously
    context.read<TransactionBloc>().add(AddTransactionEvent(newTx));

    _isCheckingOut = true;
    CartManager.instance.clear();

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.pushReplacementNamed(
      context,
      RouteConstants.orderSuccess,
      arguments: {
        'amount': grandTotal.toDouble(),
        'subtitle': 'Paid to',
        'title': storeTitle,
        'dateString': dateFormatted,
        'buttonText': 'Track Order',
        'nextRoute': RouteConstants.orderStatus,
        'nextRouteArgs': <String, dynamic>{
          'storeType': widget.storeType,
          'orderId': orderId,
          'transaction': <String, dynamic>{
            ...newTx,
            'orderId': orderId,
          },
        },
      },
    );
  }

  // ── Payment Method Bottom Sheet ─────────────────────────────────────────────
  void _showPaymentSheet({
    required BuildContext context,
    required Map<String, int> cartItemsMap,
    required int grandTotal,
    required int itemOriginalTotal,
    required int itemDiscountedTotal,
    required int deliveryCharge,
    required int handlingCharge,
    required int effectiveCouponDiscount,
    required int coinsDiscount,
    required int coinsDeducted,
    required double walletBalance,
  }) {
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                Responsive.w(20),
                Responsive.h(16),
                Responsive.w(20),
                Responsive.h(32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: Responsive.w(40),
                      height: Responsive.h(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // Title
                  CustomText.header(
                    'Choose Payment Method',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(height: Responsive.h(6)),
                  CustomText.title(
                    'Total payable: ₹$grandTotal',
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  SizedBox(height: Responsive.h(20)),

                  // ── Wallet option ──
                  _PaymentTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Wallet',
                    subtitle: 'Balance: ₹${walletBalance.toStringAsFixed(2)}',
                    enabled: walletBalance >= grandTotal,
                    disabledHint: 'Insufficient balance',
                    isProcessing: isProcessing,
                    onTap: () async {
                      if (isProcessing) return;
                      setSheetState(() => isProcessing = true);
                      Navigator.pop(sheetCtx);
                      await _placeOrder(
                        cartItemsMap: cartItemsMap,
                        grandTotal: grandTotal,
                        itemOriginalTotal: itemOriginalTotal,
                        itemDiscountedTotal: itemDiscountedTotal,
                        deliveryCharge: deliveryCharge,
                        handlingCharge: handlingCharge,
                        effectiveCouponDiscount: effectiveCouponDiscount,
                        coinsDiscount: coinsDiscount,
                        coinsDeducted: coinsDeducted,
                        paymentMethod: 'Wallet',
                      );
                    },
                  ),
                  SizedBox(height: Responsive.h(12)),

                  // ── UPI / Online option ──
                  _PaymentTile(
                    icon: Icons.payment_rounded,
                    title: 'UPI / Online',
                    subtitle: 'Pay via UPI, Net Banking or Cards',
                    enabled: true,
                    isProcessing: isProcessing,
                    onTap: () async {
                      if (isProcessing) return;
                      setSheetState(() => isProcessing = true);
                      Navigator.pop(sheetCtx);
                      await _placeOrder(
                        cartItemsMap: cartItemsMap,
                        grandTotal: grandTotal,
                        itemOriginalTotal: itemOriginalTotal,
                        itemDiscountedTotal: itemDiscountedTotal,
                        deliveryCharge: deliveryCharge,
                        handlingCharge: handlingCharge,
                        effectiveCouponDiscount: effectiveCouponDiscount,
                        coinsDiscount: coinsDiscount,
                        coinsDeducted: coinsDeducted,
                        paymentMethod: 'UPI',
                      );
                    },
                  ),
                  SizedBox(height: Responsive.h(12)),

                  // ── Cash on Delivery option ──
                  _PaymentTile(
                    icon: Icons.money_rounded,
                    title: 'Cash on Delivery',
                    subtitle: 'Pay when your order arrives',
                    enabled: true,
                    isProcessing: isProcessing,
                    onTap: () async {
                      if (isProcessing) return;
                      setSheetState(() => isProcessing = true);
                      Navigator.pop(sheetCtx);
                      await _placeOrder(
                        cartItemsMap: cartItemsMap,
                        grandTotal: grandTotal,
                        itemOriginalTotal: itemOriginalTotal,
                        itemDiscountedTotal: itemDiscountedTotal,
                        deliveryCharge: deliveryCharge,
                        handlingCharge: handlingCharge,
                        effectiveCouponDiscount: effectiveCouponDiscount,
                        coinsDiscount: coinsDiscount,
                        coinsDeducted: coinsDeducted,
                        paymentMethod: 'Cash on Delivery',
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = CartManager.instance.totalCartCount;
    if (totalCount == 0 && !_isCheckingOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isCheckingOut && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    final cartItemsMap = CartManager.instance.cartItems.value;
    int itemOriginalTotal = 0;
    int itemDiscountedTotal = 0;
    int parsePrice(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is num) return val.toInt();
      if (val is String) {
        final clean = val.replaceAll('₹', '').replaceAll(',', '').trim();
        final parsed = double.tryParse(clean);
        if (parsed != null) return parsed.toInt();
      }
      return fallback;
    }

    for (var entry in cartItemsMap.entries) {
      final String id = entry.key;
      final int qty = entry.value;
      final product = CartManager.instance.productDetails[id] ?? {};
      final int originalPrice = parsePrice(product['originalPrice'], 106);
      final int price = parsePrice(product['price'], 83);
      itemOriginalTotal += originalPrice * qty;
      itemDiscountedTotal += price * qty;
    }

    final couponState = context.watch<CouponBloc>().state;
    final int couponDiscount = couponState is CouponValid ? couponState.discount : 0;
    final bool isCouponApplied = couponState is CouponValid;
    final bool isFreeDelivery = itemDiscountedTotal >= 99 || (couponState is CouponValid && couponState.code == 'FREE_DELIVERY');
    final int deliveryCharge = isFreeDelivery ? 0 : 24;
    final int handlingCharge = 2;

    final txState = context.watch<TransactionBloc>().state;
    final int availableCoins = txState.coinsBalance;
    final double walletBalance = txState.walletBalance;
    final int effectiveCouponDiscount = couponDiscount.clamp(0, itemDiscountedTotal);
    final int remainingPayable = (itemDiscountedTotal - effectiveCouponDiscount).clamp(0, itemDiscountedTotal);
    final int maxCoinsPossible = (availableCoins / 100).floor();
    final int coinsDiscount = (_useComplaintCoins && availableCoins >= 100)
        ? maxCoinsPossible.clamp(0, remainingPayable)
        : 0;
    final int coinsDeducted = coinsDiscount * 100;

    final int grandTotal = (remainingPayable - coinsDiscount).clamp(0, 999999) + deliveryCharge + handlingCharge;
    final int itemSavings = (itemOriginalTotal - itemDiscountedTotal).clamp(0, 999999);
    final int totalSavings = itemSavings + effectiveCouponDiscount + coinsDiscount;

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // 1. Scrollable Cart Content
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
                      // Space for Custom dropdown Address App Bar
                      SizedBox(height: Responsive.h(60)),

                      // Main Shipment details card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(20)),
                          border: Border.all(
                            color: AppColors.outliner,
                            width: Responsive.w(1.2),
                          ),
                        ),
                        padding: EdgeInsets.all(Responsive.w(16)),
                        child: Column(
                          children: [
                            // Header Delivery Estimate banner
                            Row(
                              children: [
                                Icon(
                                  Icons.bolt,
                                  color: const Color(0xFF4CAF50),
                                  size: Responsive.w(18),
                                ),
                                SizedBox(width: Responsive.w(8)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CustomText.title(
                                        'Free delivery in 25-30 mins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      SizedBox(height: Responsive.h(2)),
                                      CustomText.subtitle(
                                        'Shipment of 4',
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(16)),
                            const Divider(height: 1),
                            SizedBox(height: Responsive.h(16)),

                            // Dynamic Cart Items
                            ...cartItemsMap.entries.map((entry) {
                              final String id = entry.key;
                              final int qty = entry.value;
                              final product = CartManager.instance.productDetails[id] ?? {};
                              final int stock = CartManager.instance.getStockById(id);
                              final isLast = id == cartItemsMap.keys.last;
                              return Column(
                                children: [
                                  _buildCartItem(
                                    title: product['title'] ?? 'Product',
                                    subtitle: (product['unit'] != null && product['unit'].toString().trim().isNotEmpty)
                                        ? product['unit'].toString().trim()
                                        : '1 Unit',
                                    image: product['image'] ?? 'assets/images/product1.png',
                                    qty: qty,
                                    stock: stock,
                                    originalPrice: '₹${parsePrice(product['originalPrice'], 106)}',
                                    price: '₹${parsePrice(product['price'], 83)}',
                                    onTap: () {
                                      final prodData = Map<String, dynamic>.from(product);
                                      final basePid = id.contains(':')
                                          ? id.split(':').first
                                          : (prodData['productId'] ?? prodData['id'] ?? id).toString();
                                      final vid = prodData['variantId']?.toString() ??
                                          (id.contains(':') ? id.split(':').last : '');
                                      prodData['id'] = basePid;
                                      prodData['productId'] = basePid;
                                      if (vid.isNotEmpty) {
                                        prodData['variantId'] = vid;
                                      }
                                      if (product['unit'] != null && product['unit'].toString().trim().isNotEmpty) {
                                        prodData['unit'] = product['unit'].toString().trim();
                                      }
                                      Navigator.of(context).pushNamed(
                                        RouteConstants.productDetails,
                                        arguments: {
                                          'product': prodData,
                                          'storeType': widget.storeType,
                                        },
                                      );
                                    },
                                    onDecrement: () {
                                      CartManager.instance.updateQuantityById(id, qty - 1);
                                    },
                                    onIncrement: () {
                                      CartManager.instance.updateQuantityById(id, qty + 1, context: context);
                                    },
                                  ),
                                  if (!isLast) ...[
                                    SizedBox(height: Responsive.h(16)),
                                    const Divider(height: 1),
                                    SizedBox(height: Responsive.h(16)),
                                  ],
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.h(20)),

                      // "You May Also Like.." horizontal cross-sell (Real-time from store)
                      if (_crossSellProducts.isNotEmpty) ...[
                        _buildCrossSellSection(),
                        SizedBox(height: Responsive.h(20)),
                      ],

                      // Coupons Apply Banner Card
                      _buildCouponsBannerCard(isCouponApplied),
                      SizedBox(height: Responsive.h(16)),

                      // Complaint Coins Discount Banner Card
                      if (availableCoins >= 100) ...[
                        Container(
                          margin: EdgeInsets.only(bottom: Responsive.h(16)),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(16),
                            vertical: Responsive.h(12),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(20)),
                            border: Border.all(
                              color: _useComplaintCoins ? const Color(0xFFE65100) : AppColors.outliner,
                              width: _useComplaintCoins ? 1.5 : 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.currency_rupee_rounded,
                                      color: const Color(0xFFFFB300),
                                      size: Responsive.w(22),
                                    ),
                                    SizedBox(width: Responsive.w(10)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CustomText.title(
                                            _useComplaintCoins
                                                ? 'Using $coinsDeducted Complaint Coins'
                                                : 'Use Complaint Coins ($availableCoins)',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          CustomText.subtitle(
                                            _useComplaintCoins
                                                ? 'Saving ₹$coinsDiscount on this order'
                                                : 'Save ₹${maxCoinsPossible.clamp(0, remainingPayable)} (100 coins = ₹1)',
                                            fontSize: 11,
                                            color: _useComplaintCoins ? Colors.green : AppColors.grayFont,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: Responsive.w(8)),
                              Switch(
                                value: _useComplaintCoins,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    _useComplaintCoins = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Bill Details breakdown card
                      _buildBillDetailsCard(
                        itemOriginalTotal: itemOriginalTotal,
                        itemDiscountedTotal: itemDiscountedTotal,
                        couponDiscount: effectiveCouponDiscount,
                        couponCode: couponState is CouponValid ? couponState.code : null,
                        coinsDiscount: coinsDiscount,
                        coinsDeducted: coinsDeducted,
                        deliveryCharge: deliveryCharge,
                        handlingCharge: handlingCharge,
                        grandTotal: grandTotal,
                        totalSavings: totalSavings,
                        isFreeDelivery: isFreeDelivery,
                      ),
                      SizedBox(height: Responsive.h(16)),

                      // Ordering for someone else link row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CustomText.title(
                              _receiverName != null
                                  ? 'Ordering for $_receiverName ($_receiverPhone)'
                                  : 'Ordering for someone else?',
                              fontSize: 13,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          GestureDetector(
                            onTap: () {
                              _showOrderForSomeoneElseSheet(context);
                            },
                            child: CustomText.title(
                              _receiverName != null ? 'Change' : 'Add details',
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(20)),

                      // Cancellation Policy description
                      CustomText.title('CANCELLATION POLICY', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      SizedBox(height: Responsive.h(6)),
                      CustomText.subtitle(
                        'Once order placed, any cancellation may result in a fee. In case of unexpected delays leading to order cancellation, a complete refund will be provided.',
                        fontSize: 10,
                        color: Colors.grey,
                        height: 1.4,
                      ),

                      // Safe space offset
                      SizedBox(height: Responsive.h(100)),
                    ],
                  ),
                ),
              ),

              // 2. Custom dropdown Address App Bar
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
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectAddress,
                          child: Builder(
                            builder: (context) {
                              final addrState = context.watch<AddressBloc>().state;
                              final activeAddr = addrState.selectedAddress;
                              final String displayAddr = activeAddr?.description ?? '';
                              final bool hasNoAddr = displayAddr.trim().isEmpty;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: hasNoAddr ? AppColors.primary : AppColors.black,
                                    size: Responsive.w(18),
                                  ),
                                  SizedBox(width: Responsive.w(6)),
                                  Expanded(
                                    child: CustomText.title(
                                      hasNoAddr ? 'Select Delivery Address' : displayAddr,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: hasNoAddr ? AppColors.primary : AppColors.black,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppColors.primary,
                                    size: Responsive.w(16),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Payment Placement Action Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppColors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(20),
                    vertical: Responsive.h(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Pay using source
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: const Color(0xFFF4511E),
                                  size: Responsive.w(14),
                                ),
                                SizedBox(width: Responsive.w(4)),
                                Flexible(
                                  child: CustomText.subtitle(
                                    'Pay using',
                                    fontSize: 10,
                                    color: Colors.grey,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(4)),
                            CustomText.title(
                              'Wallet (₹${walletBalance.toStringAsFixed(0)})',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: Responsive.w(12)),

                      // Solid Checkout CTA button
                      GestureDetector(
                        onTap: () async {
                          final selectedAddr = context.read<AddressBloc>().state.selectedAddress;
                          final String currentAddr = (selectedAddr?.description.trim().isNotEmpty == true)
                              ? selectedAddr!.description
                              : '';
                          if (currentAddr.trim().isEmpty) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            await _selectAddress();
                            return;
                          }

                          // ── Payment Method Bottom Sheet ──
                          _showPaymentSheet(
                            context: context,
                            cartItemsMap: cartItemsMap,
                            grandTotal: grandTotal,
                            itemOriginalTotal: itemOriginalTotal,
                            itemDiscountedTotal: itemDiscountedTotal,
                            deliveryCharge: deliveryCharge,
                            handlingCharge: handlingCharge,
                            effectiveCouponDiscount: effectiveCouponDiscount,
                            coinsDiscount: coinsDiscount,
                            coinsDeducted: coinsDeducted,
                            walletBalance: walletBalance,
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(18),
                            vertical: Responsive.h(12),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(Responsive.w(24)),
                          ),
                          child: Row(
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText.title(
                                    '₹$grandTotal',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  const Text(
                                    'Total',
                                    style: TextStyle(color: Colors.white70, fontSize: 8),
                                  ),
                                ],
                              ),
                              SizedBox(width: Responsive.w(12)),
                              CustomText.title(
                                'Place order',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              SizedBox(width: Responsive.w(4)),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: Responsive.w(16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemImage(String? imagePath, {double? width, double? height}) {
    Widget buildPlaceholder() {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(Responsive.w(8)),
        ),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: (width != null && width > 40) ? Responsive.w(22) : Responsive.w(16),
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    if (imagePath == null || imagePath.trim().isEmpty) {
      return buildPlaceholder();
    }

    final normalized = ApiClient.normalizeImageUrl(imagePath);
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Image.network(
        normalized,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => buildPlaceholder(),
      );
    }

    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => buildPlaceholder(),
    );
  }

  Widget _buildCartItem({
    required String title,
    required String subtitle,
    required String image,
    required int qty,
    required String originalPrice,
    required String price,
    required int stock,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    VoidCallback? onTap,
  }) {
    final bool isMaxStock = qty >= stock;

    return Row(
      children: [
        // Product Thumbnail & Details (Tappable to view product)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              children: [
                // Product Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(Responsive.w(8)),
                  child: _buildCartItemImage(
                    image,
                    width: Responsive.w(52),
                    height: Responsive.w(52),
                  ),
                ),
                SizedBox(width: Responsive.w(12)),

                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.title(title, fontSize: 13, fontWeight: FontWeight.bold),
                      SizedBox(height: Responsive.h(4)),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(Responsive.w(6)),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(3)),
                            child: CustomText.subtitle(
                              subtitle,
                              fontSize: 10,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (stock <= 3) ...[
                            SizedBox(width: Responsive.w(6)),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(Responsive.w(6)),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: Responsive.w(6), vertical: Responsive.h(2)),
                              child: Text(
                                'Only $stock left',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Cart Actions & Prices
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Incrementer/Decrementer dials
            Container(
              height: Responsive.h(36),
              width: Responsive.w(96),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(Responsive.w(18)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onDecrement,
                      behavior: HitTestBehavior.opaque,
                      child: const Center(
                        child: Icon(Icons.remove, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  Text(
                    qty.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.sp(13),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: onIncrement,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: isMaxStock ? Colors.white.withValues(alpha: 0.4) : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.h(6)),

            // Price tags
            Row(
              children: [
                Text(
                  '$originalPrice ',
                  style: TextStyle(
                    fontSize: 9,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey.shade400,
                  ),
                ),
                CustomText.title(
                  price,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCrossSellSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: CustomText.header(
                'You May Also Like..',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: Responsive.w(8)),
            GestureDetector(
              onTap: () {
                final String heading = widget.storeType == 'medical'
                    ? 'Recommended Products'
                    : 'You May Also Like';
                Navigator.of(context).pushNamed(
                  RouteConstants.allProducts,
                  arguments: {
                    'title': heading,
                    'products': _crossSellProducts,
                    'storeType': widget.storeType,
                  },
                );
              },
              child: CustomText.title(
                'View All',
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(12)),
        SizedBox(
          height: Responsive.h(190),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _crossSellProducts.length,
            itemBuilder: (context, index) {
              final prod = _crossSellProducts[index];
              return Padding(
                padding: EdgeInsets.only(right: Responsive.w(12)),
                child: _buildCrossSellCard(prod, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCrossSellCard(Map<String, dynamic> prod, int index) {
    final String id = (prod['id'] ?? prod['productId'] ?? '')?.toString() ?? '';
    final int qty = CartManager.instance.getQuantity(id);
    final double price = (prod['price'] as num?)?.toDouble() ?? 0.0;
    final double origPrice = (prod['originalPrice'] as num?)?.toDouble() ?? price;
    final int discount = origPrice > price && origPrice > 0 ? (((origPrice - price) / origPrice) * 100).round() : 0;
    final String title = (prod['title'] ?? prod['name'] ?? 'Product').toString();
    final String? img = prod['image']?.toString();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteConstants.productDetails,
          arguments: {
            'product': prod,
            'storeType': widget.storeType,
          },
        );
      },
      child: Container(
        width: Responsive.w(130),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(color: AppColors.outliner, width: 1.2),
        ),
        padding: EdgeInsets.all(Responsive.w(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (index == 1)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(4), vertical: Responsive.h(2)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(Responsive.w(4)),
                    ),
                    child: const Text('Top Pick', style: TextStyle(color: Colors.green, fontSize: 7, fontWeight: FontWeight.bold)),
                  )
                else
                  const Spacer(),
                CommonWishlistButton(
                  product: prod,
                  size: 14,
                ),
              ],
            ),
            SizedBox(height: Responsive.h(4)),
            Center(
              child: _buildCartItemImage(img, height: Responsive.h(56)),
            ),
            const Spacer(),
            CustomText.title(title, fontSize: 10, maxLines: 1),
            SizedBox(height: Responsive.h(2)),
            Row(
              children: [
                if (discount > 0) ...[
                  const Icon(Icons.arrow_downward, color: Colors.green, size: 8),
                  Text('$discount% ', style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('₹${origPrice.toStringAsFixed(0)} ', style: TextStyle(color: Colors.grey.shade400, fontSize: 8, decoration: TextDecoration.lineThrough)),
                ],
                Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: Responsive.h(6)),

            if (qty > 0)
              Container(
                height: Responsive.h(26),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(Responsive.w(13)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.remove, color: Colors.white, size: 10),
                      onPressed: () {
                        CartManager.instance.updateQuantity(prod, qty - 1);
                      },
                    ),
                    Text(qty.toString(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.add, color: Colors.white, size: 10),
                      onPressed: () {
                        CartManager.instance.updateQuantity(prod, qty + 1);
                      },
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    CartManager.instance.updateQuantity(prod, 1);
                  },
                  child: Container(
                    width: Responsive.w(24),
                    height: Responsive.w(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.2),
                    ),
                    child: const Icon(Icons.add, color: AppColors.primary, size: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponsBannerCard(bool isCouponApplied) {
    final couponState = context.watch<CouponBloc>().state;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(
          color: AppColors.outliner,
          width: Responsive.w(1.2),
        ),
      ),
      child: Column(
        children: [
          // Header band (gradient)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(16),
              vertical: Responsive.h(10),
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3F51B5), Color(0xFF673AB7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(Responsive.w(18)),
                topRight: Radius.circular(Responsive.w(18)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomText.title(
                    'Save extra by applying coupons on every order',
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
                Icon(
                  Icons.percent,
                  color: Colors.white,
                  size: Responsive.w(16),
                ),
              ],
            ),
          ),

          // Body coupons triggers
          Padding(
            padding: EdgeInsets.all(Responsive.w(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            color: Colors.blue.shade800,
                            size: Responsive.w(16),
                          ),
                          SizedBox(width: Responsive.w(6)),
                          Expanded(
                            child: CustomText.title(
                              couponState is CouponValid
                                  ? 'Save ₹${couponState.discount} with "${couponState.code}"'
                                  : 'Save ₹120 with "GETOFF120ON649"',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(4)),
                      GestureDetector(
                        onTap: () async {
                          final res = await Navigator.of(context).pushNamed(
                            RouteConstants.coupons,
                            arguments: 'GETOFF120ON649',
                          );
                          if (res != null && res is Map<String, dynamic> && mounted) {
                            final code = res['code'] as String?;
                            if (code != null) {
                              context.read<CouponBloc>().add(ApplyCoupon(code));
                            }
                          }
                        },
                        child: CustomText.title(
                          'View all coupons >',
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.w(12)),

                // Apply/Remove CTA button
                GestureDetector(
                  onTap: () async {
                    if (isCouponApplied) {
                      context.read<CouponBloc>().add(RemoveCoupon());
                    } else {
                      final res = await Navigator.of(context).pushNamed(
                        RouteConstants.coupons,
                        arguments: 'GETOFF120ON649',
                      );
                      if (res != null && res is Map<String, dynamic> && mounted) {
                        final code = res['code'] as String?;
                        if (code != null) {
                          context.read<CouponBloc>().add(ApplyCoupon(code));
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(20),
                      vertical: Responsive.h(8),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.primary, width: 1.2),
                      borderRadius: BorderRadius.circular(Responsive.w(16)),
                    ),
                    child: CustomText.title(
                      isCouponApplied ? 'Remove' : 'Apply',
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetailsCard({
    required int itemOriginalTotal,
    required int itemDiscountedTotal,
    required int couponDiscount,
    String? couponCode,
    int coinsDiscount = 0,
    int coinsDeducted = 0,
    required int deliveryCharge,
    required int handlingCharge,
    required int grandTotal,
    required int totalSavings,
    required bool isFreeDelivery,
  }) {
    final int itemSavings = (itemOriginalTotal - itemDiscountedTotal).clamp(0, 999999);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(
          color: AppColors.outliner,
          width: Responsive.w(1.2),
        ),
      ),
      padding: EdgeInsets.all(Responsive.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.header('Bill details', fontSize: 14, fontWeight: FontWeight.bold),
          SizedBox(height: Responsive.h(16)),

          // Item Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.assignment_outlined, color: Colors.grey, size: Responsive.w(14)),
                    SizedBox(width: Responsive.w(6)),
                    Flexible(
                      child: CustomText.title(
                        'Item total',
                        fontSize: 12,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (itemSavings > 0) ...[
                      SizedBox(width: Responsive.w(6)),
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(6), vertical: Responsive.h(2)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAF6),
                            borderRadius: BorderRadius.circular(Responsive.w(6)),
                          ),
                          child: CustomText.title(
                            'you saved ₹$itemSavings',
                            color: Colors.blue.shade800,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(8)),
              Row(
                children: [
                  Text(
                    '₹$itemOriginalTotal ',
                    style: TextStyle(
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  CustomText.title(
                    '₹$itemDiscountedTotal',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),

          // Delivery Charge Row
          GestureDetector(
            onTap: () {
              _showDeliveryChargeDialog();
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.motorcycle_outlined, color: Colors.grey, size: Responsive.w(14)),
                      SizedBox(width: Responsive.w(6)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText.title(
                              'Delivery Charge',
                              fontSize: 12,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isFreeDelivery)
                              Text(
                                'Shop for ₹${99 - itemDiscountedTotal} more to get FREE delivery',
                                style: const TextStyle(color: Colors.red, fontSize: 8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.w(8)),
                CustomText.title(
                  deliveryCharge == 0 ? 'Free' : '₹$deliveryCharge',
                  color: deliveryCharge == 0 ? Colors.blue.shade700 : AppColors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(12)),

          // Handling Charge Row
          GestureDetector(
            onTap: () {
              _showHandlingChargeDialog();
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.work_outline, color: Colors.grey, size: Responsive.w(14)),
                      SizedBox(width: Responsive.w(6)),
                      Expanded(
                        child: CustomText.title(
                          'Handling Charge',
                          fontSize: 12,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.w(8)),
                CustomText.title(
                  '₹$handlingCharge',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),

          // Coupon Discount Row
          if (couponDiscount > 0) ...[
            SizedBox(height: Responsive.h(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_num_outlined, color: Colors.green, size: 14),
                      SizedBox(width: Responsive.w(6)),
                      Expanded(
                        child: CustomText.title(
                          couponCode != null ? 'Coupon Discount ($couponCode)' : 'Coupon Discount',
                          fontSize: 12,
                          color: Colors.green,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.w(8)),
                CustomText.title(
                  '-₹$couponDiscount',
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ],
          if (coinsDiscount > 0) ...[
            SizedBox(height: Responsive.h(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.currency_rupee_rounded, color: Color(0xFFFFB300), size: 14),
                      SizedBox(width: Responsive.w(6)),
                      Expanded(
                        child: CustomText.title(
                          'Complaint Coins ($coinsDeducted coins)',
                          fontSize: 12,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.w(8)),
                CustomText.title(
                  '-₹$coinsDiscount',
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ],
          SizedBox(height: Responsive.h(12)),
          const Divider(height: 1),
          SizedBox(height: Responsive.h(12)),

          // Grand Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText.header('Grand Total', fontSize: 13, fontWeight: FontWeight.bold),
              CustomText.header(
                '₹$grandTotal',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),

          // Savings Row (Green Band)
          Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(10)),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(Responsive.w(10)),
            ),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your total savings',
                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹$totalSavings',
                  style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHandlingChargeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(20)),
          ),
          contentPadding: EdgeInsets.all(Responsive.w(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.header('Handling charge', fontSize: 15, fontWeight: FontWeight.bold),
              SizedBox(height: Responsive.h(8)),
              CustomText.subtitle(
                'For proper handling and ensuring high quality quick-deliveries',
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              SizedBox(height: Responsive.h(16)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: Responsive.h(40),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(Responsive.w(20)),
                  ),
                  child: const Center(
                    child: Text(
                      'Okay',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeliveryChargeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(20)),
          ),
          contentPadding: EdgeInsets.all(Responsive.w(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.header('Delivery charge', fontSize: 15, fontWeight: FontWeight.bold),
              SizedBox(height: Responsive.h(12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText.title('For orders below ₹99', fontSize: 12, color: Colors.grey.shade700),
                  CustomText.title('₹24', fontSize: 12, fontWeight: FontWeight.bold),
                ],
              ),
              SizedBox(height: Responsive.h(6)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText.title('For orders Above ₹99', fontSize: 12, color: Colors.grey.shade700),
                  CustomText.title('₹0', fontSize: 12, fontWeight: FontWeight.bold),
                ],
              ),
              SizedBox(height: Responsive.h(16)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: Responsive.h(40),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(Responsive.w(20)),
                  ),
                  child: const Center(
                    child: Text(
                      'Okay',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOrderForSomeoneElseSheet(BuildContext context) {
    final TextEditingController nameCont = TextEditingController(text: _receiverName);
    final TextEditingController phoneCont = TextEditingController(text: _receiverPhone);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool isModalValid = nameCont.text.trim().isNotEmpty &&
                phoneCont.text.trim().isNotEmpty;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(Responsive.w(20)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Responsive.w(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomText.header('Order for someone else', fontSize: 16, fontWeight: FontWeight.bold),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(4)),
                    CustomText.subtitle(
                      'We\'ll directly coordinate with the receiver to deliver your order',
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    SizedBox(height: Responsive.h(20)),

                    CustomText.title('Delivery address', fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    SizedBox(height: Responsive.h(4)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              SizedBox(height: Responsive.h(2)),
                              CustomText.title(
                                _deliveryAddress,
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final selected = await Navigator.of(context).pushNamed(
                              RouteConstants.addressBook,
                              arguments: true,
                            );
                            if (selected != null && selected is AddressModel) {
                              if (context.mounted) {
                                context.read<AddressBloc>().add(SelectActiveAddressEvent(selected));
                              }
                              setModalState(() {
                                _deliveryAddress = selected.description;
                              });
                              setState(() {});
                            }
                          },
                          child: CustomText.title('Change', color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(20)),

                    CustomText.title('Add receiver details', fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    SizedBox(height: Responsive.h(8)),

                    Container(
                      height: Responsive.h(48),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                        border: Border.all(color: AppColors.outliner, width: 1.2),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameCont,
                              onChanged: (val) => setModalState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Name',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Icon(Icons.person_outline, color: AppColors.primary, size: Responsive.w(18)),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.h(12)),

                    Container(
                      height: Responsive.h(48),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                        border: Border.all(color: AppColors.outliner, width: 1.2),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneCont,
                              onChanged: (val) => setModalState(() {}),
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: 'Phone number',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Icon(Icons.phone_android_outlined, color: AppColors.primary, size: Responsive.w(18)),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.h(20)),

                    GestureDetector(
                      onTap: isModalValid
                          ? () {
                              setState(() {
                                _receiverName = nameCont.text.trim();
                                _receiverPhone = phoneCont.text.trim();
                              });
                              Navigator.pop(context);
                            }
                          : null,
                      child: Container(
                        height: Responsive.h(48),
                        decoration: BoxDecoration(
                          color: isModalValid ? AppColors.primary : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(Responsive.w(24)),
                          border: Border.all(
                            color: isModalValid ? AppColors.primary : Colors.grey.shade300,
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: CustomText.title(
                            'Save & Continue',
                            color: isModalValid ? Colors.white : Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Payment Tile Widget ───────────────────────────────────────────────────────
class _PaymentTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final String? disabledHint;
  final bool isProcessing;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.isProcessing,
    required this.onTap,
    this.disabledHint,
  });

  @override
  Widget build(BuildContext context) {
    final bool canTap = enabled && !isProcessing;
    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(16),
          vertical: Responsive.h(14),
        ),
        decoration: BoxDecoration(
          color: canTap ? Colors.white : Colors.grey.shade50,
          border: Border.all(
            color: canTap ? AppColors.primary.withValues(alpha: 0.35) : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(Responsive.w(14)),
          boxShadow: canTap
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: Responsive.w(44),
              height: Responsive.w(44),
              decoration: BoxDecoration(
                color: canTap
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(Responsive.w(12)),
              ),
              child: Icon(
                icon,
                color: canTap ? AppColors.primary : Colors.grey.shade400,
                size: Responsive.w(22),
              ),
            ),
            SizedBox(width: Responsive.w(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText.title(
                    title,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: canTap ? Colors.black87 : Colors.grey.shade500,
                  ),
                  SizedBox(height: Responsive.h(2)),
                  CustomText.title(
                    !enabled && disabledHint != null ? disabledHint! : subtitle,
                    fontSize: 12,
                    color: !enabled && disabledHint != null
                        ? Colors.red.shade400
                        : Colors.grey.shade500,
                  ),
                ],
              ),
            ),
            if (isProcessing)
              SizedBox(
                width: Responsive.w(18),
                height: Responsive.w(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: Responsive.w(14),
                color: canTap ? AppColors.primary : Colors.grey.shade300,
              ),
          ],
        ),
      ),
    );
  }
}
