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
              width: Responsive.w(42),
              height: Responsive.w(42),
              decoration: BoxDecoration(
                color: isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF2EC),
                borderRadius: BorderRadius.circular(Responsive.w(12)),
              ),
              child: Center(
                child: Icon(
                  isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isPositive ? const Color(0xFF4CAF50) : AppColors.primary,
                  size: Responsive.w(20),
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
                  SizedBox(height: Responsive.h(4)),
                  CustomText.subtitle(
                    tx['subtitle'],
                    fontSize: 11,
                    color: AppColors.grayFont,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.w(10)),
            CustomText.title(
              tx['amount'],
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
            ),
          ],
        ),
      ),
    );
  }
}
