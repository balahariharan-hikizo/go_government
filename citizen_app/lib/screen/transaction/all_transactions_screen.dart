import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../bloc/transaction/transaction_state.dart';
import '../../constants/route_constants.dart';

class AllTransactionsScreen extends StatelessWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              onTap: () => Navigator.pop(context),
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
          ),
        ),
        title: CustomText.header(
          'Transactions',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: false,
      ),
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<TransactionBloc, TransactionState>(
            builder: (context, state) {
              final transactions = state.transactions;
              if (transactions.isEmpty) {
                return _buildEmptyState(context);
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(20),
                  vertical: Responsive.h(16),
                ),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: Responsive.h(12)),
                    child: _buildTransactionCard(context, tx),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: Responsive.w(90),
              height: Responsive.w(90),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2EC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.outliner,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: Responsive.w(44),
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(height: Responsive.h(20)),
            CustomText.title(
              'No Transactions Yet',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: Responsive.h(8)),
            CustomText.subtitle(
              'Your transaction and order history will appear here once you make a purchase or wallet payment.',
              fontSize: 13,
              color: AppColors.grayFont,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.h(24)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(24),
                  vertical: Responsive.h(12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Responsive.w(20)),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).pushNamed(RouteConstants.nearStores);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, color: Colors.white, size: 18),
                  SizedBox(width: Responsive.w(8)),
                  CustomText.title(
                    'Explore Stores',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> tx) {
    final bool isPositive = tx['isPositive'] as bool? ?? false;
    final String amountStr = tx['amount']?.toString() ?? '₹0';
    final String paymentMethod = (tx['paymentMethod'] ?? tx['paymentTag'] ?? '').toString().toLowerCase();
    final String category = tx['category']?.toString().toLowerCase() ?? '';
    final String status = tx['status']?.toString().toLowerCase() ?? '';

    final bool isRefund = isPositive || category == 'order_refund' || tx['title'].toString().toLowerCase().contains('refund');
    final bool isCod = paymentMethod.contains('cash') || paymentMethod.contains('cod');
    final bool isUpi = paymentMethod.contains('upi') || paymentMethod.contains('online') || paymentMethod.contains('bank');
    final bool isCancelled = status.contains('cancel') || tx['subtitle'].toString().toLowerCase().contains('cancel');

    Color iconBg;
    Color iconColor;
    IconData iconData;
    Color amountColor;
    String badgeText;
    Color badgeBg;
    Color badgeColor;

    if (isRefund) {
      iconBg = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF2E7D32);
      iconData = Icons.assignment_return_rounded;
      amountColor = const Color(0xFF2E7D32);
      badgeText = isUpi ? 'Bank Refund' : 'Wallet Refund';
      badgeBg = const Color(0xFFE8F5E9);
      badgeColor = const Color(0xFF2E7D32);
    } else if (isCod) {
      if (isCancelled) {
        iconBg = const Color(0xFFF1F5F9);
        iconColor = Colors.grey.shade600;
        iconData = Icons.money_off_rounded;
        amountColor = Colors.grey.shade600;
        badgeText = 'COD · Cancelled';
        badgeBg = const Color(0xFFF1F5F9);
        badgeColor = Colors.grey.shade700;
      } else {
        iconBg = const Color(0xFFFFF8E1);
        iconColor = const Color(0xFFE65100);
        iconData = Icons.payments_outlined;
        amountColor = Colors.blueGrey.shade900;
        badgeText = 'Cash on Delivery';
        badgeBg = const Color(0xFFFFF3E0);
        badgeColor = const Color(0xFFE65100);
      }
    } else if (isUpi) {
      iconBg = const Color(0xFFE3F2FD);
      iconColor = const Color(0xFF1565C0);
      iconData = Icons.account_balance_outlined;
      amountColor = const Color(0xFFFF5252);
      badgeText = 'Paid via UPI';
      badgeBg = const Color(0xFFE3F2FD);
      badgeColor = const Color(0xFF1565C0);
    } else {
      // Wallet
      iconBg = isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF2EC);
      iconColor = isPositive ? const Color(0xFF4CAF50) : AppColors.primary;
      iconData = isPositive ? Icons.arrow_downward : Icons.account_balance_wallet_outlined;
      amountColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
      badgeText = isPositive ? 'Wallet Top-up' : 'Paid from Wallet';
      badgeBg = isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF2EC);
      badgeColor = isPositive ? const Color(0xFF2E7D32) : AppColors.primary;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteConstants.transactionDetails,
          arguments: {
            'title': tx['title']?.toString() ?? 'Order Details',
            'transaction': tx,
          },
        );
      },
      child: Container(
        padding: EdgeInsets.all(Responsive.w(16)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(
            color: AppColors.outliner,
            width: Responsive.w(1.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: Responsive.w(44),
              height: Responsive.w(44),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(Responsive.w(12)),
              ),
              child: Center(
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: Responsive.w(22),
                ),
              ),
            ),
            SizedBox(width: Responsive.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText.title(
                    tx['title'],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    maxLines: 1,
                  ),
                  SizedBox(height: Responsive.h(3)),
                  CustomText.subtitle(
                    tx['subtitle'],
                    fontSize: 11,
                    color: AppColors.grayFont,
                    maxLines: 1,
                  ),
                  Container(
                    margin: EdgeInsets.only(top: Responsive.h(4)),
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(6),
                      vertical: Responsive.h(2),
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.w(10)),
            CustomText.title(
              amountStr,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ],
        ),
      ),
    );
  }
}
