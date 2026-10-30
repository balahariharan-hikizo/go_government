import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../bloc/transaction/transaction_event.dart';
import '../../bloc/transaction/transaction_state.dart';
import '../../service/cart_manager.dart';
import '../../network/api_client.dart';
import '../../constants/route_constants.dart';
import '../../utils/call_launcher.dart';
import '../../network/order_api_service.dart';
import '../../hive/hive_service.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? transaction;

  const TransactionDetailsScreen({
    super.key,
    required this.title,
    this.transaction,
  });

  @override
  State<TransactionDetailsScreen> createState() => _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  void _showCitizenReturnBottomSheet(BuildContext context, String orderId) {
    String selectedReason = 'Defective / Damaged Item';
    final notesController = TextEditingController();
    final reasons = [
      'Defective / Damaged Item',
      'Expired Product Delivered',
      'Wrong Item / Missing Quantity',
      'Poor Quality / Not as Described',
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
                        color: Color(0xFFFFF3E0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFE65100), size: 24),
                    ),
                    SizedBox(width: Responsive.w(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.title('Return Request', fontSize: 18, fontWeight: FontWeight.bold),
                          CustomText.subtitle('Order #$orderId', color: AppColors.grayFont, fontSize: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(18)),
                CustomText.subtitle('SELECT REASON FOR RETURN', fontWeight: FontWeight.bold, color: AppColors.grayFont, fontSize: 11),
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
                    hintText: 'Additional details about the issue (optional)',
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          padding: EdgeInsets.symmetric(vertical: Responsive.h(14)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                        ),
                        onPressed: () async {
                          final userId = HiveService.citizenId.isNotEmpty ? HiveService.citizenId : HiveService.userId;
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          final res = await OrderApiService.requestReturn(
                            orderId: orderId,
                            userId: userId,
                            reason: selectedReason,
                            notes: notesController.text.trim(),
                          );
                          if (!mounted) return;
                          if (res['success'] == true) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('✅ Return request submitted! Store merchant will review it.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            setState(() {
                              if (widget.transaction != null) {
                                widget.transaction!['status'] = 'return_requested';
                              }
                            });
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message']?.toString() ?? 'Failed to submit return request'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                        child: const Text('Submit Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        final bool showReorderScreen = state.showReorderScreen;
        final List<bool> watermelonReturned = state.watermelonReturned;

        final tx = widget.transaction != null
            ? Map<String, dynamic>.from(widget.transaction!)
            : <String, dynamic>{};
        final String orderId = tx['id']?.toString() ?? 'TX-ERTYUIOP09876';
        final String title = tx['title']?.toString() ?? 'Transaction';
        final String amount = tx['amount']?.toString() ?? '0';
        final List items = (tx['items'] as List?) ?? [];
        final String listingPrice = tx['listingPrice']?.toString() ?? '₹225.00';
        final String sellingPrice = tx['sellingPrice']?.toString() ?? '₹99.50';
        final String grandTotal = tx['grandTotal']?.toString() ?? '₹99.50';
        final String paid = tx['paid']?.toString() ?? '₹100.00';

        final bool isRefund = title.toLowerCase().contains('refund') || (tx['category']?.toString() == 'order_refund');
        final bool isStoreOrder = (items.isNotEmpty || orderId.startsWith('ORD-')) && !isRefund;
        final bool isCoinsReward = !isRefund && (title.toLowerCase().contains('coin') ||
            title.toLowerCase().contains('bonus') ||
            title.toLowerCase().contains('reward') ||
            title.toLowerCase().contains('complaint') ||
            title.toLowerCase().contains('survey') ||
            !amount.contains('₹'));
        final bool isWalletTx = title.toLowerCase().contains('wallet');

        String screenTitle = 'Order Details';
        if (showReorderScreen) {
          screenTitle = 'Reorder Items';
        } else if (!isStoreOrder) {
          if (isRefund) {
            screenTitle = 'Refund Details';
          } else if (isCoinsReward) {
            screenTitle = 'Reward Details';
          } else if (isWalletTx) {
            screenTitle = 'Wallet Details';
          } else {
            screenTitle = 'Transaction Details';
          }
        }

        return Scaffold(
          backgroundColor: AppColors.screenColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: Responsive.w(70),
            leading: Padding(
              padding: EdgeInsets.only(left: Responsive.w(20)),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (showReorderScreen) {
                      context.read<TransactionBloc>().add(ToggleReorderScreenEvent(false));
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: Responsive.w(44),
                    height: Responsive.w(44),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(Responsive.w(12)),
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
              ),
            ),
            title: CustomText.header(
              screenTitle,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            centerTitle: false,
          ),
          body: CommonBackground(
            child: SafeArea(
              bottom: false,
              child: !isStoreOrder
                  ? _buildRewardOrWalletDetailsView(context, tx)
                  : (showReorderScreen
                      ? _buildReorderView(context)
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.w(20),
                              vertical: Responsive.h(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Order ID
                                CustomText.subtitle(
                                  'Order ID - $orderId',
                                  fontSize: 13,
                                  color: AppColors.grayFont,
                                ),
                                SizedBox(height: Responsive.h(14)),

                                // Store Details & Call Card
                                if (isStoreOrder) ...[
                                  Builder(builder: (context) {
                                    final storeDetails = tx['storeDetails'] as Map? ?? {};
                                    final String storeName = storeDetails['name']?.toString() ??
                                        (isStoreOrder ? title : 'Government Store');
                                    final String storePhone = storeDetails['phone']?.toString() ??
                                        tx['storePhone']?.toString() ?? '';
                                    final String storeAddress = storeDetails['address']?.toString() ??
                                        tx['storeAddress']?.toString() ?? '';

                                    return Container(
                                      padding: EdgeInsets.all(Responsive.w(14)),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(Responsive.w(18)),
                                        border: Border.all(color: AppColors.outliner, width: 1.2),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: Responsive.w(38),
                                            height: Responsive.w(38),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF2EC),
                                              borderRadius: BorderRadius.circular(Responsive.w(10)),
                                            ),
                                            child: Icon(Icons.storefront, color: AppColors.primary, size: Responsive.w(20)),
                                          ),
                                          SizedBox(width: Responsive.w(12)),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                CustomText.title(
                                                  storeName,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (storePhone.isNotEmpty) ...[
                                                  SizedBox(height: Responsive.h(2)),
                                                  Text(
                                                    'Contact: $storePhone',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF2E7D32),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ] else if (storeAddress.isNotEmpty) ...[
                                                  SizedBox(height: Responsive.h(2)),
                                                  Text(
                                                    storeAddress,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.grayFont,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (storePhone.isNotEmpty) ...[
                                            SizedBox(width: Responsive.w(8)),
                                            ElevatedButton.icon(
                                              onPressed: () => CallLauncher.launchCall(context, phone: storePhone, name: storeName),
                                              icon: const Icon(Icons.phone, size: 12, color: Colors.white),
                                              label: const Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2E7D32),
                                                elevation: 0,
                                                padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(6)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                  SizedBox(height: Responsive.h(14)),
                                ],

                                // Items card — orange border
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(Responsive.w(20)),
                                    border: Border.all(
                                      color: AppColors.outliner,
                                      width: Responsive.w(1.5),
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(16),
                                    vertical: Responsive.h(8),
                                  ),
                                  child: Column(
                                    children: items.asMap().entries.map((e) {
                                      final int idx = e.key;
                                      final it = Map<String, dynamic>.from(e.value as Map);
                                      final isRet = idx < watermelonReturned.length ? watermelonReturned[idx] : false;
                                      return _buildItemRow(
                                        context,
                                        idx,
                                        it['title'] ?? 'Product',
                                        '${it['price'] ?? '₹ 99.0'} x ${it['qty'] ?? 1}',
                                        (it['image'] ?? it['imageUrl'] ?? '').toString(),
                                        isRet,
                                      );
                                    }).toList(),
                                  ),
                                ),
                                SizedBox(height: Responsive.h(16)),

                                // Bill Summary card — orange border
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(Responsive.w(20)),
                                    border: Border.all(
                                      color: AppColors.outliner,
                                      width: Responsive.w(1.5),
                                    ),
                                  ),
                                  padding: EdgeInsets.all(Responsive.w(16)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: Responsive.w(36),
                                                height: Responsive.w(36),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF2EC),
                                                  borderRadius: BorderRadius.circular(Responsive.w(10)),
                                                ),
                                                child: Icon(
                                                  Icons.receipt_long_outlined,
                                                  color: AppColors.primary,
                                                  size: Responsive.w(20),
                                                ),
                                              ),
                                              SizedBox(width: Responsive.w(10)),
                                              CustomText.title(
                                                'Bill Summary',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ],
                                          ),
                                          Container(
                                            width: Responsive.w(36),
                                            height: Responsive.w(36),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE8F5E9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.download_outlined,
                                              color: Colors.green,
                                              size: Responsive.w(18),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: Responsive.h(14)),
                                      _buildPriceRow('Listing price', listingPrice, isGray: true),
                                      SizedBox(height: Responsive.h(8)),
                                      _buildPriceRow('Selling price', sellingPrice, isGray: true),
                                      SizedBox(height: Responsive.h(10)),
                                      _buildDivider(),
                                      SizedBox(height: Responsive.h(10)),
                                      _buildPriceRow('Grand total', grandTotal),
                                      SizedBox(height: Responsive.h(8)),
                                      _buildPriceRow('Coupon applied', '₹00.00', isGray: true),
                                      SizedBox(height: Responsive.h(8)),
                                      _buildPriceRow('Cash round off', '₹00.01', isGray: true),
                                      SizedBox(height: Responsive.h(8)),
                                      _buildPriceRow('Paid', paid, isBold: true),
                                    ],
                                  ),
                                ),
                                SizedBox(height: Responsive.h(24)),

                                // Reorder + Invoice buttons
                                _buildBottomButtons(context),
                                SizedBox(height: Responsive.h(40)),
                              ],
                            ),
                          ),
                        )),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardOrWalletDetailsView(BuildContext context, Map<String, dynamic> tx) {
    final String id = tx['id']?.toString() ?? 'TX-0000';
    final String title = tx['title']?.toString() ?? 'Transaction';
    final String subtitle = tx['subtitle']?.toString() ?? '';
    final String amount = tx['amount']?.toString() ?? '+100';
    final bool isPositive = tx['isPositive'] == true;
    final String status = tx['status']?.toString() ?? 'Credited';
    final String date = tx['date']?.toString() ?? 'Today';
    final String? orderId = tx['orderId']?.toString();
    final String category = tx['category']?.toString() ?? '';
    final String payMethod = tx['paymentMethod']?.toString() ?? 'Wallet Account';

    final bool isRefund = category == 'order_refund' || title.toLowerCase().contains('refund');
    final bool isTopup = category == 'topup' || title.toLowerCase().contains('top-up') || title.toLowerCase().contains('topup');
    final bool isCoins = category == 'civic_reward' ||
        (!isRefund && !isTopup && (
          title.toLowerCase().contains('coin') ||
          title.toLowerCase().contains('bonus') ||
          title.toLowerCase().contains('reward') ||
          title.toLowerCase().contains('complaint') ||
          title.toLowerCase().contains('survey') ||
          amount.toLowerCase().contains('coin') ||
          !amount.contains('₹')
        ));

    String formattedAmount = amount;
    if (isCoins) {
      final String cleanAmt = amount.replaceAll('+', '').replaceAll('-', '').replaceAll('Coins', '').replaceAll('🪙', '').trim();
      // If cleanAmt was 0 (from legacy backend amount: 0), try to extract from subtitle (e.g. "+200")
      String coinNum = cleanAmt;
      if (coinNum.isEmpty || coinNum == '0') {
        final match = RegExp(r'[+]?(\d+)\s*coins', caseSensitive: false).firstMatch(subtitle);
        if (match != null) {
          coinNum = match.group(1) ?? '100';
        }
      }
      formattedAmount = isPositive ? '+$coinNum Coins' : '-$coinNum Coins';
    } else {
      if (!formattedAmount.contains('₹')) {
        formattedAmount = isPositive ? '+₹$formattedAmount' : '-₹$formattedAmount';
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(20),
        vertical: Responsive.h(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Large Hero Credit Receipt Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(20),
              vertical: Responsive.h(24),
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(Responsive.w(24)),
              border: Border.all(
                color: AppColors.outliner,
                width: Responsive.w(1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Icon badge
                Container(
                  width: Responsive.w(64),
                  height: Responsive.w(64),
                  decoration: BoxDecoration(
                    color: isCoins ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRefund
                        ? Icons.replay_rounded
                        : (isCoins ? Icons.currency_rupee_rounded : Icons.account_balance_wallet_rounded),
                    color: isCoins ? const Color(0xFFFFB300) : const Color(0xFF43A047),
                    size: Responsive.w(36),
                  ),
                ),
                SizedBox(height: Responsive.h(16)),

                // Amount Text
                CustomText.header(
                  formattedAmount,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? const Color(0xFF2E7D32) : AppColors.black,
                ),
                SizedBox(height: Responsive.h(6)),

                // Subtitle
                CustomText.title(
                  title,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
                SizedBox(height: Responsive.h(4)),
                CustomText.subtitle(
                  subtitle,
                  fontSize: 12,
                  color: AppColors.grayFont,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: Responsive.h(14)),

                // Status chip
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(14),
                    vertical: Responsive.h(5),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 14),
                      SizedBox(width: Responsive.w(6)),
                      CustomText.title(
                        status,
                        color: const Color(0xFF2E7D32),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(16)),

          // 2. Transaction Details Breakdown Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.w(16)),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(Responsive.w(20)),
              border: Border.all(
                color: AppColors.outliner,
                width: Responsive.w(1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: Responsive.w(18)),
                    SizedBox(width: Responsive.w(8)),
                    CustomText.title(
                      isRefund ? 'Refund Information' : 'Transaction Information',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(14)),
                _buildPriceRow('Transaction ID', id, isGray: true),
                SizedBox(height: Responsive.h(10)),
                _buildPriceRow(
                  'Activity Type',
                  isRefund
                      ? 'Order Refund'
                      : (isTopup ? 'Wallet Top-up' : (isCoins ? 'Civic Reward' : (isPositive ? 'Wallet Credit' : 'Wallet Debit'))),
                  isGray: true,
                ),
                if (isRefund && orderId != null && orderId.isNotEmpty) ...[
                  SizedBox(height: Responsive.h(10)),
                  _buildPriceRow('Associated Order', '#$orderId', isGray: true),
                ],
                SizedBox(height: Responsive.h(10)),
                _buildPriceRow('Date & Time', date, isGray: true),
                SizedBox(height: Responsive.h(10)),
                if (isRefund) ...[
                  _buildPriceRow('Reason', 'Order Cancellation', isGray: true),
                  SizedBox(height: Responsive.h(10)),
                  _buildPriceRow('Refund Mode', 'Original Payment (Wallet)', isGray: true),
                ] else if (isTopup) ...[
                  _buildPriceRow('Payment Mode', payMethod, isGray: true),
                ] else if (isCoins) ...[
                  _buildPriceRow('Program', 'GoGovernment Civic Rewards', isGray: true),
                ] else ...[
                  _buildPriceRow('Payment Mode', payMethod, isGray: true),
                ],
                SizedBox(height: Responsive.h(12)),
                _buildDivider(),
                SizedBox(height: Responsive.h(12)),
                _buildPriceRow(
                  isRefund ? 'Refunded To' : 'Credited Account',
                  isCoins ? 'Complaint Coins Balance' : 'GoGov Wallet Balance',
                  isBold: true,
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(16)),

          // 3. Helpful Info Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.w(14)),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(Responsive.w(16)),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isRefund ? Icons.verified_outlined : Icons.lightbulb_outline,
                  color: const Color(0xFF2E7D32),
                  size: 18,
                ),
                SizedBox(width: Responsive.w(10)),
                Expanded(
                  child: CustomText.subtitle(
                    isRefund
                        ? 'The refunded amount of $formattedAmount has been credited directly to your GoGov Wallet and is ready for use on future orders.'
                        : (isCoins
                            ? 'Complaint Coins can be redeemed directly for real wallet cash anytime (100 Coins = ₹1, min 100 coins) or applied during store checkout for extra savings.'
                            : 'Your GoGov Wallet balance can be used directly for seamless 1-click purchases in local stores.'),
                    fontSize: 11,
                    color: const Color(0xFF2E7D32),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(24)),

          // 4. Return to Transactions button
          SizedBox(
            width: double.infinity,
            height: Responsive.h(48),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.w(24)),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: CustomText.title(
                'Back to Transactions',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: Responsive.h(20)),
        ],
      ),
    );
  }

  Widget _buildReorderView(BuildContext context) {
    final List items = widget.transaction?['items'] as List? ?? [];
    final hasItems = items.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(20),
        vertical: Responsive.h(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.title(
            'Reorder products from this transaction. Select items to add back to your active cart.',
            fontSize: 13,
            color: AppColors.grayFont,
          ),
          SizedBox(height: Responsive.h(20)),
          if (hasItems) ...[
            ...items.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final String title = item['title'] ?? 'Product';
              final String price = item['price'] ?? '₹99';
              final int qty = (item['qty'] as num?)?.toInt() ?? 1;
              return Padding(
                padding: EdgeInsets.only(bottom: Responsive.h(12)),
                child: _buildReorderCard(
                  context,
                  title,
                  '$price x $qty qty',
                  '$qty items will be added to cart',
                  true,
                  item: item,
                ),
              );
            }),
          ] else ...[
            _buildReorderCard(context, 'Watermelon striped', '₹99 x 3 qty', '3 items will be added to cart', true),
            SizedBox(height: Responsive.h(12)),
            _buildReorderCard(context, 'Fresh Apple Red', '₹150 x 1 qty', 'Item is temporarily out of stock', false),
            SizedBox(height: Responsive.h(12)),
            _buildReorderCard(context, 'Fresh Spinach bunch', '₹25 x 2 qty', '2 items will be added to cart', true),
          ],
          SizedBox(height: Responsive.h(16)),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(48),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.w(24)),
                ),
                elevation: 0,
              ),
              onPressed: () => _reorderAllAndGoToCart(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                  SizedBox(width: Responsive.w(8)),
                  CustomText.title(
                    'Reorder All & Go to Cart',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.h(20)),
        ],
      ),
    );
  }

  Future<void> _reorderAllAndGoToCart(BuildContext context) async {
    final storeDetails = (widget.transaction?['storeDetails'] as Map?) ?? {};
    String storeId = (widget.transaction?['storeId'] ?? storeDetails['storeId'] ?? '').toString().trim();
    String storeName = (widget.transaction?['storeName'] ?? storeDetails['name'] ?? widget.title).toString().trim();
    final String orderId = (widget.transaction?['id'] ?? widget.transaction?['orderId'] ?? '').toString().trim();

    List resolvedItems = List.from((widget.transaction?['items'] as List?) ?? []);

    // If storeId is missing OR items is empty OR any item has dummy/missing productId:
    final bool needsLiveFetch = storeId.isEmpty ||
        resolvedItems.isEmpty ||
        resolvedItems.any((it) {
          if (it is! Map) return true;
          final pid = (it['productId'] ?? it['id'] ?? '').toString();
          return pid.isEmpty || pid.startsWith('prod_') || pid.startsWith('reorder_');
        });

    if (needsLiveFetch && orderId.isNotEmpty) {
      try {
        final liveDetails = await OrderApiService.fetchOrderDetails(orderId);
        if (liveDetails != null) {
          final liveStoreDetails = (liveDetails['storeDetails'] as Map?) ?? {};
          final sId = (liveDetails['storeId'] ?? liveStoreDetails['storeId'] ?? '').toString().trim();
          final sName = (liveStoreDetails['name'] ?? liveDetails['storeName'] ?? '').toString().trim();
          if (sId.isNotEmpty) storeId = sId;
          if (sName.isNotEmpty) storeName = sName;

          final liveItems = liveDetails['items'] as List?;
          if (liveItems != null && liveItems.isNotEmpty) {
            resolvedItems = List.from(liveItems);
          }
        }
      } catch (_) {}
    }

    // Clear previous cart to prevent cross-store item mixing
    CartManager.instance.clear();

    if (resolvedItems.isNotEmpty) {
      for (final raw in resolvedItems) {
        if (raw is Map) {
          final item = Map<String, dynamic>.from(raw);
          final rawPid = (item['productId'] ?? item['id'] ?? '').toString().trim();
          final vId = (item['variantId'] ?? (rawPid.contains(':') ? rawPid.split(':').last : '')).toString().trim();
          final basePid = rawPid.contains(':') ? rawPid.split(':').first : rawPid;
          final cartKey = vId.isNotEmpty ? '$basePid:$vId' : basePid;

          final rawPrice = item['price'];
          num parsedPrice = 99;
          if (rawPrice is num) {
            parsedPrice = rawPrice;
          } else if (rawPrice != null) {
            parsedPrice = num.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 99;
          }

          final rawOrig = item['originalPrice'];
          num parsedOrig = parsedPrice;
          if (rawOrig is num) {
            parsedOrig = rawOrig;
          } else if (rawOrig != null) {
            parsedOrig = num.tryParse(rawOrig.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? parsedPrice;
          }

          final prodData = {
            ...item,
            'id': cartKey,
            'productId': basePid,
            'variantId': vId,
            if (storeId.isNotEmpty) 'storeId': storeId,
            if (storeName.isNotEmpty) 'storeName': storeName,
            'title': item['title'] ?? item['name'] ?? 'Product',
            'price': parsedPrice,
            'originalPrice': parsedOrig,
            'image': (item['image'] ?? item['imageUrl'] ?? '').toString(),
            'unit': item['unit'] ?? '1 Units',
            'stock': 100,
          };
          final qty = ((item['qty'] ?? item['quantity'] ?? 1) as num).toInt();
          CartManager.instance.addToCart(prodData, qty: qty, productId: cartKey);
        }
      }
    } else {
      CartManager.instance.addToCart({
        'id': 'reorder_${DateTime.now().millisecondsSinceEpoch}',
        if (storeId.isNotEmpty) 'storeId': storeId,
        if (storeName.isNotEmpty) 'storeName': storeName,
        'title': widget.title,
        'price': 99,
        'originalPrice': 150,
        'image': '',
        'stock': 10,
      }, qty: 1);
    }

    if (context.mounted) {
      context.read<TransactionBloc>().add(ToggleReorderScreenEvent(false));
      Navigator.of(context).pushNamed(RouteConstants.cart);
    }
  }

  Widget _buildReorderCard(
    BuildContext context,
    String title,
    String qtyText,
    String summary,
    bool isAvailable, {
    Map<String, dynamic>? item,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(24)),
        border: Border.all(
          color: AppColors.outliner,
          width: Responsive.w(1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Responsive.w(8)),
                child: _buildProductImage(
                  item?['image'],
                  width: Responsive.w(48),
                  height: Responsive.w(48),
                ),
              ),
              SizedBox(width: Responsive.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title(
                      title,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: Responsive.h(2)),
                    CustomText.subtitle(
                      qtyText,
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(6)),
          CustomText.subtitle(
            summary,
            fontSize: 11,
            color: AppColors.grayFont,
          ),
          SizedBox(height: Responsive.h(12)),

          // Reorder or Not Available Action Button
          GestureDetector(
            onTap: isAvailable
                ? () {
                    final storeDetails = (widget.transaction?['storeDetails'] as Map?) ?? {};
                    final String storeId = (widget.transaction?['storeId'] ?? storeDetails['storeId'] ?? '').toString();
                    final String storeName = (widget.transaction?['storeName'] ?? storeDetails['name'] ?? widget.title).toString();

                    final rawPid = (item?['productId'] ?? item?['id'] ?? '').toString().trim();
                    final vId = (item?['variantId'] ?? (rawPid.contains(':') ? rawPid.split(':').last : '')).toString().trim();
                    final basePid = rawPid.contains(':') ? rawPid.split(':').first : rawPid;
                    final cartKey = vId.isNotEmpty ? '$basePid:$vId' : basePid;

                    final pTitle = item?['title'] ?? item?['name'] ?? title;
                    final rawPrice = item?['price'];
                    num parsedPrice = 99;
                    if (rawPrice is num) {
                      parsedPrice = rawPrice;
                    } else if (rawPrice != null) {
                      parsedPrice = num.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 99;
                    }

                    final rawOrig = item?['originalPrice'];
                    num parsedOrig = parsedPrice;
                    if (rawOrig is num) {
                      parsedOrig = rawOrig;
                    } else if (rawOrig != null) {
                      parsedOrig = num.tryParse(rawOrig.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? parsedPrice;
                    }

                    final pQty = ((item?['qty'] ?? item?['quantity'] ?? 1) as num).toInt();

                    final prodData = {
                      ...?item,
                      'id': cartKey,
                      'productId': basePid,
                      'variantId': vId,
                      if (storeId.isNotEmpty) 'storeId': storeId,
                      if (storeName.isNotEmpty) 'storeName': storeName,
                      'title': pTitle,
                      'price': parsedPrice,
                      'originalPrice': parsedOrig,
                      'image': (item?['image'] ?? item?['imageUrl'] ?? '').toString(),
                      'unit': item?['unit'] ?? '1 Units',
                      'stock': 100,
                    };

                    CartManager.instance.addToCart(prodData, qty: pQty, productId: cartKey);

                    if (context.mounted) {
                      context.read<TransactionBloc>().add(ToggleReorderScreenEvent(false));
                      Navigator.of(context).pushNamed(RouteConstants.cart);
                    }
                  }
                : null,
            child: Container(
              height: Responsive.h(40),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.transparent : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(Responsive.w(20)),
                border: Border.all(
                  color: isAvailable ? AppColors.primary : Colors.grey.shade300,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAvailable) ...[
                      Icon(Icons.refresh, color: AppColors.primary, size: Responsive.w(16)),
                      SizedBox(width: Responsive.w(6)),
                    ] else ...[
                      Icon(Icons.block, color: Colors.grey.shade400, size: Responsive.w(16)),
                      SizedBox(width: Responsive.w(6)),
                    ],
                    CustomText.title(
                      isAvailable ? 'Reorder' : 'Not Available',
                      color: isAvailable ? AppColors.primary : Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String? imagePath, {required double width, required double height}) {
    Widget buildPlaceholder() {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(Responsive.w(8)),
          border: Border.all(color: Colors.grey.shade200, width: 0.8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: (width >= 40) ? Responsive.w(18) : Responsive.w(14),
                color: Colors.grey.shade400,
              ),
              if (height >= 38) ...[
                SizedBox(height: Responsive.h(1)),
                Text(
                  'No img',
                  style: TextStyle(
                    fontSize: Responsive.sp(7.5),
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final raw = (imagePath ?? '').trim();
    if (raw.isEmpty || raw == 'assets/images/product1.png') {
      return buildPlaceholder();
    }
    final normalized = ApiClient.normalizeImageUrl(raw);
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Image.network(
        normalized,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => buildPlaceholder(),
      );
    }
    return Image.asset(
      normalized,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => buildPlaceholder(),
    );
  }

  Widget _buildItemRow(BuildContext context, int index, String name, String price, String assetPath, bool isReturned) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Responsive.w(8)),
                child: _buildProductImage(
                  assetPath,
                  width: Responsive.w(42),
                  height: Responsive.w(42),
                ),
              ),
              SizedBox(width: Responsive.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title(
                      name,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isReturned ? Colors.grey : Colors.black,
                    ),
                    CustomText.subtitle(
                      price,
                      fontSize: 12,
                      color: AppColors.grayFont,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(10)),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildReturnStatusBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(14)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 22),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText.title(title, fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                SizedBox(height: Responsive.h(4)),
                CustomText.subtitle(subtitle, fontSize: 11, color: textColor.withValues(alpha: 0.9), height: 1.3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    final tx = widget.transaction != null ? Map<String, dynamic>.from(widget.transaction!) : <String, dynamic>{};
    final String orderId = (tx['id'] ?? tx['orderId'] ?? '').toString();
    final String status = (tx['status'] ?? tx['orderStatus'] ?? '').toString().toLowerCase();

    final bool isDelivered = status == 'delivered' || status == 'completed';
    final bool isReturnRequested = status == 'return_requested';
    final bool isReturnApproved = status == 'return_pickup_pending';
    final bool isReturnAssigned = status == 'return_pickup_assigned';
    final bool isReturned = status == 'returned_to_store';
    final bool isReturnRejected = status == 'return_rejected';

    return Column(
      children: [
        // 1. Live Return Status Tracking Banner (If in return lifecycle)
        if (isReturnRequested) ...[
          _buildReturnStatusBanner(
            icon: Icons.hourglass_top_rounded,
            title: 'Return Request Under Review',
            subtitle: 'Store merchant is reviewing your return request. A delivery partner will be dispatched upon approval.',
            bgColor: const Color(0xFFFFF3E0),
            borderColor: const Color(0xFFFFB74D),
            textColor: const Color(0xFFE65100),
          ),
          SizedBox(height: Responsive.h(16)),
        ] else if (isReturnApproved) ...[
          _buildReturnStatusBanner(
            icon: Icons.moped_rounded,
            title: 'Return Approved · Rider Dispatched',
            subtitle: 'Store approved your return request! A delivery partner is being assigned for doorstep collection.',
            bgColor: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFD54F),
            textColor: const Color(0xFFF57F17),
          ),
          SizedBox(height: Responsive.h(16)),
        ] else if (isReturnAssigned) ...[
          _buildReturnStatusBanner(
            icon: Icons.two_wheeler_rounded,
            title: 'Delivery Partner Assigned',
            subtitle: 'A delivery partner is heading to your doorstep to collect the return parcel.',
            bgColor: const Color(0xFFE3F2FD),
            borderColor: const Color(0xFF90CAF9),
            textColor: const Color(0xFF1565C0),
          ),
          SizedBox(height: Responsive.h(16)),
        ] else if (isReturned) ...[
          _buildReturnStatusBanner(
            icon: Icons.check_circle_rounded,
            title: 'Returned & 100% Refunded',
            subtitle: 'Order items returned to store. Full refund has been credited directly to your GoGov Wallet.',
            bgColor: const Color(0xFFE8F5E9),
            borderColor: const Color(0xFFA5D6A7),
            textColor: const Color(0xFF2E7D32),
          ),
          SizedBox(height: Responsive.h(16)),
        ] else if (isReturnRejected) ...[
          _buildReturnStatusBanner(
            icon: Icons.cancel_outlined,
            title: 'Return Request Rejected',
            subtitle: 'Store merchant was unable to accept the return request for this order.',
            bgColor: const Color(0xFFFFEBEE),
            borderColor: const Color(0xFFEF9A9A),
            textColor: const Color(0xFFC62828),
          ),
          SizedBox(height: Responsive.h(16)),
        ],

        // 2. Action Buttons (Reorder + Invoice)
        Row(
          children: [
            Expanded(
              child: Container(
                height: Responsive.h(48),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(Responsive.w(24)),
                  border: Border.all(
                    color: AppColors.primary,
                    width: Responsive.w(1.5),
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    _reorderAllAndGoToCart(context);
                  },
                  borderRadius: BorderRadius.circular(Responsive.w(24)),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.replay,
                          color: AppColors.primary,
                          size: Responsive.w(18),
                        ),
                        SizedBox(width: Responsive.w(6)),
                        CustomText.title(
                          'Reorder',
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: Responsive.w(16)),
            Expanded(
              child: Container(
                height: Responsive.h(48),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(Responsive.w(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: Responsive.w(6),
                      offset: Offset(0, Responsive.h(3)),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Downloading invoice...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(Responsive.w(24)),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download_outlined,
                          color: AppColors.black,
                          size: Responsive.w(18),
                        ),
                        SizedBox(width: Responsive.w(6)),
                        CustomText.title(
                          'Invoice',
                          color: AppColors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // 3. Return Action Button (ONLY AND ONLY FOR DELIVERED ORDERS!)
        if (isDelivered) ...[
          SizedBox(height: Responsive.h(14)),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(48),
            child: OutlinedButton.icon(
              onPressed: () => _showCitizenReturnBottomSheet(context, orderId),
              icon: const Icon(Icons.assignment_return_outlined, color: Color(0xFFE65100), size: 18),
              label: const Text(
                'Request Return / Exchange',
                style: TextStyle(
                  color: Color(0xFFE65100),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF9800), width: 1.5),
                backgroundColor: const Color(0xFFFFF8F3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.w(24)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceRow(String label, String val, {bool isBold = false, bool isGray = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomText.title(
          label,
          fontSize: 13,
          color: isGray ? AppColors.grayFont : AppColors.black,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        ),
        CustomText.title(
          val,
          fontSize: 13,
          color: isGray ? AppColors.grayFont : AppColors.black,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey.shade200,
      height: 1,
      thickness: 1,
    );
  }
}
