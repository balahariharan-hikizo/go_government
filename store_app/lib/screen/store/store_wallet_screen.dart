import 'package:flutter/material.dart';
import '../../model/store_model.dart';
import '../../network/store_wallet_api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class StoreWalletScreen extends StatefulWidget {
  final StoreModel store;

  const StoreWalletScreen({
    super.key,
    required this.store,
  });

  @override
  State<StoreWalletScreen> createState() => _StoreWalletScreenState();
}

class _StoreWalletScreenState extends State<StoreWalletScreen> {
  Map<String, dynamic>? _walletData;
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'credit', 'debit'

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    final res = await StoreWalletApiService.fetchStoreWallet(widget.store.storeId);
    if (mounted) {
      setState(() {
        _walletData = res;
        _isLoading = false;
      });
    }
  }

  void _showSettlementInfoModal() {
    final bank = _walletData?['storeSummary']?['bankDetails'] as Map<String, dynamic>? ?? {};
    final bankName = (bank['bankName']?.toString().isNotEmpty ?? false)
        ? bank['bankName'].toString()
        : (widget.store.bankDetails.bankName.isNotEmpty ? widget.store.bankDetails.bankName : 'State Bank of India');
    final rawAcc = (bank['accountNumber']?.toString().isNotEmpty ?? false)
        ? bank['accountNumber'].toString()
        : widget.store.bankDetails.accountNumber;
    final accNumber = rawAcc.isNotEmpty
        ? '•••• •••• ${rawAcc.length > 4 ? rawAcc.substring(rawAcc.length - 4) : rawAcc}'
        : '•••• •••• 4821';
    final ifsc = (bank['ifscCode']?.toString().isNotEmpty ?? false)
        ? bank['ifscCode'].toString()
        : (widget.store.bankDetails.ifscCode.isNotEmpty ? widget.store.bankDetails.ifscCode : 'SBIN0001234');
    final holder = (bank['accountHolderName']?.toString().isNotEmpty ?? false)
        ? bank['accountHolderName'].toString()
        : (widget.store.bankDetails.accountHolderName.isNotEmpty ? widget.store.bankDetails.accountHolderName : widget.store.ownerName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(Responsive.w(20)),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: Responsive.w(40),
                height: Responsive.h(4),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 24),
                ),
                SizedBox(width: Responsive.w(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.header('Direct Bank Transfer (DBT)', fontSize: 16, color: AppColors.black),
                      CustomText.body('Automated municipal vendor settlement', fontSize: 11, color: AppColors.grayFont),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(18)),
            const Divider(height: 1),
            SizedBox(height: Responsive.h(14)),
            _buildModalInfoRow('Settlement Bank', bankName),
            _buildModalInfoRow('Account Number', accNumber),
            _buildModalInfoRow('IFSC Code', ifsc),
            _buildModalInfoRow('Account Beneficiary', holder),
            _buildModalInfoRow('Payout Schedule', 'Weekly every Friday (100% Automated DBT)', valueColor: const Color(0xFF16A34A)),
            _buildModalInfoRow('Transfer Type', 'NEFT / RTGS Merchant Clearing', valueColor: AppColors.black),
            SizedBox(height: Responsive.h(20)),
            SizedBox(
              width: double.infinity,
              height: Responsive.h(44),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            SizedBox(height: Responsive.h(8)),
          ],
        ),
      ),
    );
  }

  Widget _buildModalInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grayFont)),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.black)),
        ],
      ),
    );
  }

  void _showRequestPayoutDialog(double currentBalance) {
    if (currentBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unsettled balance available for instant withdrawal.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: Responsive.w(8)),
            const Text('Request Express Payout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available for Express Settlement: ₹${currentBalance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
            ),
            SizedBox(height: Responsive.h(8)),
            const Text(
              'Standard payouts are credited weekly every Friday. By requesting an express settlement, funds will be dispatched to your linked bank account within 2-4 business hours.',
              style: TextStyle(fontSize: 12, color: AppColors.grayFont, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Express payout request of ₹${currentBalance.toStringAsFixed(2)} submitted to Municipal Treasury.'),
                  backgroundColor: const Color(0xFF16A34A),
                ),
              );
            },
            child: const Text('Confirm Payout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    final rawBalance = _walletData?['walletBalance'];
    final currentBalance = (rawBalance is num) ? rawBalance.toDouble() : (widget.store.walletBalance.toDouble());

    final summary = _walletData?['storeSummary'] as Map<String, dynamic>? ?? {};
    final netProductEarnings = (summary['netProductEarnings'] as num?)?.toDouble() ?? 0.0;
    final totalRevenue = netProductEarnings;
    final grossCustomerSales = (summary['grossCustomerSales'] as num?)?.toDouble() ?? 0.0;
    final riderDeliveryCharges = (summary['riderDeliveryCharges'] as num?)?.toDouble() ?? 0.0;
    final deliveredOrders = (summary['deliveredOrdersCount'] as num?)?.toInt() ?? 0;
    final returnedOrders = (summary['returnedOrdersCount'] as num?)?.toInt() ?? 0;
    final totalRefunds = (summary['totalRefunds'] as num?)?.toDouble() ?? 0.0;

    final rawTxList = (_walletData?['transactions'] as List?) ?? [];
    final allTransactions = rawTxList.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

    final filteredTransactions = allTransactions.where((tx) {
      final type = tx['type']?.toString().toLowerCase() ?? '';
      if (_selectedFilter == 'credit') return type == 'credit';
      if (_selectedFilter == 'debit') return type == 'debit';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: CustomText.title('Store Revenue & Wallet', fontWeight: FontWeight.bold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.black),
            onPressed: _isLoading ? null : _fetchWalletData,
          ),
        ],
      ),
      body: CommonBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchWalletData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. LIVE STORE WALLET HERO CARD
                  _buildHeroWalletCard(currentBalance),
                  SizedBox(height: Responsive.h(16)),

                  // 2. STORE SALES & PERFORMANCE METRICS (3-COLUMN KPI)
                  _buildPerformanceKpiRow(totalRevenue, deliveredOrders, returnedOrders),
                  SizedBox(height: Responsive.h(16)),

                  // 3. SETTLEMENT & REVENUE ACCOUNTING BREAKDOWN CARD
                  _buildAccountingBreakdownCard(
                    grossSales: grossCustomerSales,
                    riderFees: riderDeliveryCharges,
                    netEarnings: netProductEarnings,
                    totalRefunds: totalRefunds,
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // 4. LINKED BANK & DBT SETTLEMENT CARD
                  _buildBankSettlementCard(),
                  SizedBox(height: Responsive.h(20)),

                  // 4. TRANSACTION & SETTLEMENT HISTORY HEADER WITH FILTER CHIPS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: Responsive.w(6)),
                          CustomText.title('Revenue Ledger', fontSize: 15, color: AppColors.black),
                        ],
                      ),
                      Text(
                        '${filteredTransactions.length} Settlements',
                        style: const TextStyle(fontSize: 11, color: AppColors.grayFont, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(10)),

                  // Filter Row (All / Credits / Debits)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        SizedBox(width: Responsive.w(8)),
                        _buildFilterChip('Sales Credits', 'credit'),
                        SizedBox(width: Responsive.w(8)),
                        _buildFilterChip('Returns & Debits', 'debit'),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.h(12)),

                  // 5. SETTLEMENT TRANSACTION LIST
                  if (_isLoading && allTransactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (filteredTransactions.isEmpty)
                    _buildEmptyTransactions()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTransactions.length,
                      separatorBuilder: (_, _) => SizedBox(height: Responsive.h(8)),
                      itemBuilder: (ctx, i) {
                        return _buildTransactionCard(filteredTransactions[i]);
                      },
                    ),

                  SizedBox(height: Responsive.h(20)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroWalletCard(double balance) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(18)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                    ),
                    SizedBox(width: Responsive.w(8)),
                    Expanded(
                      child: Text(
                        widget.store.name,
                        style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(8)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: Responsive.w(5)),
                    const Text(
                      'Live Settlement',
                      style: TextStyle(fontSize: 10, color: Color(0xFF86EFAC), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(16)),
          const Text(
            'Current Unsettled Balance',
            style: TextStyle(fontSize: 11.5, color: Colors.white60),
          ),
          SizedBox(height: Responsive.h(4)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: Responsive.w(6)),
              const Text(
                'INR',
                style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(14)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(6)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.white70),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Automatic DBT settlement every Friday to linked bank account.',
                    style: TextStyle(fontSize: 10.5, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(14)),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text('Express Payout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showRequestPayoutDialog(balance),
                ),
              ),
              SizedBox(width: Responsive.w(10)),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    padding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.account_balance_rounded, size: 15),
                  label: const Text('Bank Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showSettlementInfoModal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceKpiRow(double totalRevenue, int deliveredOrders, int returnedOrders) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: 'Net Sales',
            value: '₹${totalRevenue.toInt()}',
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
          ),
        ),
        SizedBox(width: Responsive.w(10)),
        Expanded(
          child: _buildKpiCard(
            title: 'Settled Orders',
            value: '$deliveredOrders',
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
        SizedBox(width: Responsive.w(10)),
        Expanded(
          child: _buildKpiCard(
            title: 'Returns Handled',
            value: '$returnedOrders',
            icon: Icons.assignment_return_rounded,
            iconColor: const Color(0xFFE65100),
            bgColor: const Color(0xFFFFF3E0),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(14)),
        border: Border.all(color: AppColors.outliner.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          SizedBox(height: Responsive.h(8)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.black),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: Responsive.h(2)),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppColors.grayFont, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBankSettlementCard() {
    final bank = _walletData?['storeSummary']?['bankDetails'] as Map<String, dynamic>? ?? {};
    final bankName = (bank['bankName']?.toString().isNotEmpty ?? false)
        ? bank['bankName'].toString()
        : (widget.store.bankDetails.bankName.isNotEmpty ? widget.store.bankDetails.bankName : 'State Bank of India');
    final rawAcc = (bank['accountNumber']?.toString().isNotEmpty ?? false)
        ? bank['accountNumber'].toString()
        : widget.store.bankDetails.accountNumber;
    final accNumber = rawAcc.isNotEmpty
        ? '•••• •••• ${rawAcc.length > 4 ? rawAcc.substring(rawAcc.length - 4) : rawAcc}'
        : '•••• •••• 4821';
    final ifsc = (bank['ifscCode']?.toString().isNotEmpty ?? false)
        ? bank['ifscCode'].toString()
        : (widget.store.bankDetails.ifscCode.isNotEmpty ? widget.store.bankDetails.ifscCode : 'SBIN0001234');

    return GestureDetector(
      onTap: _showSettlementInfoModal,
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFFD97706), size: 22),
            ),
            SizedBox(width: Responsive.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        bankName,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.black),
                      ),
                      SizedBox(width: Responsive.w(6)),
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                    ],
                  ),
                  SizedBox(height: Responsive.h(2)),
                  Text(
                    'Acc: $accNumber • IFSC: $ifsc',
                    style: const TextStyle(fontSize: 11, color: AppColors.grayFont),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.grayFont),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(6)),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final isCredit = (tx['type']?.toString().toLowerCase() ?? '') == 'credit';
    final orderId = tx['orderId']?.toString() ?? '';
    final title = tx['title']?.toString() ?? 'Order Settlement';
    final subtitle = tx['subtitle']?.toString() ?? '';
    final balanceAfter = (tx['balanceAfter'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: EdgeInsets.all(Responsive.w(13)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(14)),
        border: Border.all(color: AppColors.outliner.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isCredit ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? const Color(0xFF16A34A) : Colors.red,
              size: 18,
            ),
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title.isNotEmpty ? title : (orderId.isNotEmpty ? 'Order #$orderId' : 'Wallet Transaction'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCredit) ...[
                      SizedBox(width: Responsive.w(4)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('CREDIT', style: TextStyle(fontSize: 8, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      SizedBox(width: Responsive.w(4)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          title.toLowerCase().contains('return') ? 'RETURN' : 'DEBIT',
                          style: const TextStyle(fontSize: 8, color: Color(0xFFE65100), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: Responsive.h(2)),
                Text(
                  subtitle.isNotEmpty ? subtitle : 'Delivered order credit',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.grayFont),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: Responsive.h(2)),
                Text(
                  'Post-Balance: ₹${balanceAfter.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'} ₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isCredit ? const Color(0xFF16A34A) : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: Responsive.h(30), horizontal: Responsive.w(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: AppColors.outliner.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
          SizedBox(height: Responsive.h(10)),
          const Text(
            'No Settlement Transactions Yet',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.black),
          ),
          SizedBox(height: Responsive.h(4)),
          const Text(
            'Delivered citizen orders will automatically credit your store wallet here.',
            style: TextStyle(fontSize: 11, color: AppColors.grayFont),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountingBreakdownCard({
    required double grossSales,
    required double riderFees,
    required double netEarnings,
    double totalRefunds = 0.0,
  }) {
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF2563EB)),
                  ),
                  SizedBox(width: Responsive.w(8)),
                  CustomText.title('Settlement Accounting Breakdown', fontSize: 13.5, color: AppColors.black),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Verified', style: TextStyle(fontSize: 9.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),
          _buildAccountingRow(
            label: 'Delivered Customer Billing (Citizens Paid)',
            value: '₹${grossSales.toStringAsFixed(2)}',
            valueColor: AppColors.black,
            icon: Icons.add_circle_outline_rounded,
            iconColor: const Color(0xFF16A34A),
          ),
          SizedBox(height: Responsive.h(8)),
          _buildAccountingRow(
            label: 'Less: Rider Delivery Charges (Paid to Riders)',
            value: '- ₹${riderFees.toStringAsFixed(2)}',
            valueColor: Colors.red.shade700,
            icon: Icons.remove_circle_outline_rounded,
            iconColor: Colors.red.shade600,
          ),
          if (totalRefunds > 0) ...[
            SizedBox(height: Responsive.h(8)),
            _buildAccountingRow(
              label: 'Customer Returns Restocked & Refunded',
              value: '₹${totalRefunds.toStringAsFixed(2)}',
              valueColor: const Color(0xFFE65100),
              icon: Icons.assignment_return_rounded,
              iconColor: const Color(0xFFE65100),
            ),
          ],
          SizedBox(height: Responsive.h(10)),
          const Divider(height: 1),
          SizedBox(height: Responsive.h(10)),
          _buildAccountingRow(
            label: 'Net Store Product Sales',
            value: '₹${netEarnings.toStringAsFixed(2)}',
            valueColor: const Color(0xFF16A34A),
            isBold: true,
            icon: Icons.shopping_bag_rounded,
            iconColor: const Color(0xFF16A34A),
          ),
          SizedBox(height: Responsive.h(12)),
          Container(
            padding: EdgeInsets.all(Responsive.w(10)),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: AppColors.grayFont),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Citizen billing includes delivery charges which are paid directly to Delivery Riders. 100% of product sales revenue is credited to your store wallet.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.grayFont, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountingRow({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        SizedBox(width: Responsive.w(6)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? AppColors.black : AppColors.grayFont,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 13.5 : 12,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
