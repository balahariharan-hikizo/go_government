import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/custom_text.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../bloc/transaction/transaction_event.dart';
import '../../bloc/transaction/transaction_state.dart';
import '../../constants/route_constants.dart';
import '../../hive/hive_service.dart';
import '../../widget/motion/bouncing_button.dart';
import '../../widget/motion/fade_slide_transition.dart';
import '../../widget/motion/tilt_3d_card.dart';
import '../../widget/motion/spinning_3d_coin.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TransactionBloc>().add(LoadTransactionsEvent());
      }
    });
  }

  Future<void> _handleRefresh() async {
    context.read<TransactionBloc>().add(LoadTransactionsEvent());
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _showAddMoneyBottomSheet(BuildContext context) {
    final amountController = TextEditingController();
    String selectedMethod = 'UPI (GPay / PhonePe)';
    final quickAmounts = [100, 500, 1000, 2000];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: Responsive.w(20),
                right: Responsive.w(20),
                top: Responsive.h(24),
                bottom: MediaQuery.of(context).viewInsets.bottom + Responsive.h(24),
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(28))),
              ),
              child: SingleChildScrollView(
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
                          borderRadius: BorderRadius.circular(Responsive.w(2)),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomText.header(
                          'Add Money to Wallet',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(16)),

                    // Amount input field
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: Responsive.w(16), right: Responsive.w(8)),
                          child: Center(
                            widthFactor: 0.0,
                            child: CustomText.header('₹', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        hintText: 'Enter amount (e.g. 500)',
                        filled: true,
                        fillColor: const Color(0xFFFFF2EC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(14)),

                    // Quick select chips
                    Wrap(
                      spacing: Responsive.w(8),
                      children: quickAmounts.map((amt) {
                        return ActionChip(
                          backgroundColor: const Color(0xFFFFF7F2),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                          label: CustomText.title('+₹$amt', fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                          onPressed: () {
                            setModalState(() {
                              amountController.text = amt.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: Responsive.h(20)),

                    CustomText.title('Select Payment Method', fontSize: 14, fontWeight: FontWeight.bold),
                    SizedBox(height: Responsive.h(10)),

                    // Payment Method Tiles
                    ...[
                      'UPI (GPay / PhonePe / Paytm)',
                      'Credit / Debit Card',
                      'Net Banking',
                    ].map((method) {
                      final isSelected = selectedMethod == method;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedMethod = method;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: Responsive.h(8)),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(14),
                            vertical: Responsive.h(12),
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFF2EC) : Colors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(14)),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.outliner,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CustomText.title(method, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? AppColors.primary : Colors.grey,
                                size: Responsive.w(20),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: Responsive.h(20)),

                    // Add Money Button
                    SizedBox(
                      width: double.infinity,
                      height: Responsive.h(48),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Responsive.w(24)),
                          ),
                        ),
                        onPressed: () {
                          final double? amt = double.tryParse(amountController.text.trim());
                          if (amt == null || amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid amount'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          context.read<TransactionBloc>().add(
                            AddWalletMoneyEvent(amt, paymentMethod: selectedMethod),
                          );

                          Navigator.pop(modalCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('₹${amt.toInt()} added to wallet successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        child: CustomText.title(
                          'Add Money to Wallet',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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

  void _showRedeemCoinsDialog(BuildContext context, int coinsBalance) {
    if (coinsBalance < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum 50 coins required to redeem! Earn more by reporting issues.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final coinsController = TextEditingController(text: coinsBalance.toString());

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
              Icon(Icons.currency_rupee_rounded, color: const Color(0xFFFFB300), size: Responsive.w(26)),
              SizedBox(width: Responsive.w(8)),
              CustomText.header('Redeem Coins', fontSize: 18, fontWeight: FontWeight.bold),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.subtitle(
                'Convert your earned grievance reward coins into real wallet cash balance (Min 100 coins required).',
                fontSize: 13,
                color: AppColors.grayFont,
              ),
              SizedBox(height: Responsive.h(12)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(12),
                  vertical: Responsive.h(10),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F2),
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: CustomText.title(
                        'Rate: 100 Coins = ₹1',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: Responsive.w(6)),
                    CustomText.title(
                      '🪙 $coinsBalance',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.grayFont,
                    ),
                  ],
                ),
              ),
              if (coinsBalance < 100) ...[
                SizedBox(height: Responsive.h(8)),
                CustomText.subtitle(
                  '⚠️ You need at least 100 coins to redeem.',
                  fontSize: 11,
                  color: AppColors.error,
                ),
              ],
              SizedBox(height: Responsive.h(14)),
              TextField(
                controller: coinsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Coins to redeem (Min 100)',
                  hintText: 'e.g. 100, 200, 500',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: CustomText.title('Cancel', color: AppColors.grayFont, fontSize: 14),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
              ),
              onPressed: () {
                if (coinsBalance < 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You need at least 100 coins to redeem into wallet cash!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final int? coinsToRedeem = int.tryParse(coinsController.text.trim());
                if (coinsToRedeem == null || coinsToRedeem < 100 || coinsToRedeem > coinsBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter at least 100 coins (100 coins = ₹1)!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final double cash = (coinsToRedeem / 100).floorToDouble();
                final int actualCoins = (cash * 100).toInt();

                context.read<TransactionBloc>().add(RedeemCoinsEvent(actualCoins));
                Navigator.pop(dialogCtx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Redeemed $actualCoins Coins for ₹${cash.toInt()} into Wallet!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: CustomText.title('Redeem to Wallet', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }

  void _showInviteShareDialog(BuildContext context) {
    const String referralCode = 'GOV-CITIZEN-98';
    const String shareText =
        'Join Go Government to improve your city, report civic issues, and earn rewards! Use my referral code: $referralCode to receive 100 bonus civic coins!';

    bool isClaimed = HiveService.isReferralClaimed();

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
                      color: Color(0xFFFFF2EC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.share, color: AppColors.primary, size: Responsive.w(20)),
                  ),
                  SizedBox(width: Responsive.w(10)),
                  CustomText.header('Invite Friends', fontSize: 18, fontWeight: FontWeight.bold),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText.subtitle(
                    'Share your referral code with friends and family to help improve civic governance. Earn 100 coins on their first complaint or survey!',
                    fontSize: 13,
                    color: AppColors.grayFont,
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // Clickable Referral Code Container
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: referralCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Referral code "$referralCode" copied to clipboard!'),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(12)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2EC),
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Referral Code (Tap to Copy)',
                                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: Responsive.h(2)),
                              CustomText.header(
                                referralCode,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.all(Responsive.w(6)),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.copy, color: AppColors.primary, size: Responsive.w(18)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // Claim +100 Coins Button (credits 100 coins and removes itself once claimed)
                  if (!isClaimed) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Responsive.w(12)),
                          ),
                          padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFFFD54F), size: 20),
                        label: const Text(
                          'Claim +100 Coins',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () async {
                          // 1. Credit 100 Civic Coins
                          context.read<TransactionBloc>().add(AddCoinsEvent(100));

                          // 2. Add transaction history entry
                          final now = DateTime.now();
                          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          final dateStr =
                              '${months[now.month - 1]} ${now.day} - ${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'pm' : 'am'}';

                          final rewardTx = {
                            'id': 'CLM-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                            'title': 'Referral Welcome Bonus',
                            'subtitle': '100 Civic Coins credited · $dateStr',
                            'amount': '+100 Coins',
                            'isPositive': true,
                            'status': 'Credited',
                            'date': dateStr,
                            'items': [],
                            'address': 'Citizen Referral Program',
                            'listingPrice': '₹0.00',
                            'sellingPrice': '100 Coins',
                            'grandTotal': '100 Coins',
                            'paid': '100 Coins',
                          };
                          context.read<TransactionBloc>().add(AddTransactionEvent(rewardTx));

                          // 3. Mark as claimed in persistent storage
                          await HiveService.setReferralClaimed(true);

                          // 4. Remove it immediately from the UI
                          setDialogState(() {
                            isClaimed = true;
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '100 Civic Coins credited to your wallet balance!',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    SizedBox(height: Responsive.h(12)),
                  ],

                  // Quick Action Share Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final String encoded = Uri.encodeComponent(shareText);
                            final Uri whatsappNativeUri = Uri.parse("whatsapp://send?text=$encoded");
                            final Uri whatsappApiUri = Uri.parse("https://api.whatsapp.com/send?text=$encoded");
                            final Uri waMeUri = Uri.parse("https://wa.me/?text=$encoded");

                            bool launched = false;
                            // 1. Try whatsapp://send with externalApplication
                            try {
                              launched = await launchUrl(whatsappNativeUri, mode: LaunchMode.externalApplication);
                            } catch (_) {}

                            // 2. Try api.whatsapp.com with externalApplication (intercepted by WhatsApp app)
                            if (!launched) {
                              try {
                                launched = await launchUrl(whatsappApiUri, mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            }

                            // 3. Try api.whatsapp.com with platformDefault (lets OS handle URL)
                            if (!launched) {
                              try {
                                launched = await launchUrl(whatsappApiUri, mode: LaunchMode.platformDefault);
                              } catch (_) {}
                            }

                            // 4. Try wa.me
                            if (!launched) {
                              try {
                                launched = await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            }

                            // 5. Fallback: Copy to clipboard with user notification
                            if (!launched) {
                              Clipboard.setData(ClipboardData(text: shareText));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Could not open WhatsApp. Invite message copied to clipboard!'),
                                    backgroundColor: AppColors.primary,
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                                  ),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                            padding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
                          ),
                          icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 16),
                          label: const Text(
                            'WhatsApp',
                            style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.w(8)),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: shareText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Invite message & link copied to clipboard!'),
                                backgroundColor: AppColors.primary,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                            padding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
                          ),
                          icon: Icon(Icons.link, color: AppColors.primary, size: 16),
                          label: Text(
                            'Copy Link',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: CustomText.title('Close', color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        final double walletBalance = state.walletBalance;
        final int coinsBalance = state.coinsBalance;
        final transactions = state.transactions;

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Account Balance Card (Interactive 3D Perspective Tilt Card with Specular Glare)
              FadeSlideTransitionWidget(
                index: 0,
                child: Tilt3DCard(
                  borderRadius: BorderRadius.circular(Responsive.w(26)),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Responsive.w(26)),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF7A50),
                          Color(0xFFE64A19),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE64A19).withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(Responsive.w(22)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CustomText.title(
                              'Account Balance',
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                            BouncingButton(
                              scaleFactor: 0.9,
                              onTap: () {
                                Navigator.of(context).pushNamed(RouteConstants.qrScanPay);
                              },
                              child: Container(
                                width: Responsive.w(40),
                                height: Responsive.w(40),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: AppColors.primary,
                                  size: Responsive.w(22),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.h(6)),
                        CustomText.header(
                          '₹ ${walletBalance.toStringAsFixed(walletBalance.truncateToDouble() == walletBalance ? 0 : 2)}',
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        SizedBox(height: Responsive.h(18)),

                        // Action Buttons Row
                        Row(
                          children: [
                            Expanded(
                              child: BouncingButton(
                                scaleFactor: 0.92,
                                onTap: () => _showAddMoneyBottomSheet(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(8),
                                    vertical: Responsive.h(9),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(Responsive.w(22)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_circle,
                                        color: const Color(0xFFE64A19),
                                        size: Responsive.w(18),
                                      ),
                                      SizedBox(width: Responsive.w(6)),
                                      Flexible(
                                        child: CustomText.title(
                                          'Add Money',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFE64A19),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: Responsive.w(10)),
                            Expanded(
                              child: BouncingButton(
                                scaleFactor: 0.92,
                                onTap: () => _showRedeemCoinsDialog(context, coinsBalance),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(8),
                                    vertical: Responsive.h(9),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(Responsive.w(22)),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.redeem_rounded,
                                        color: Colors.white,
                                        size: Responsive.w(18),
                                      ),
                                      SizedBox(width: Responsive.w(6)),
                                      Flexible(
                                        child: CustomText.title(
                                          'Redeem Coins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          overflow: TextOverflow.ellipsis,
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
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(20)),

              // 2. Complaint Coins & Rewards Card
              FadeSlideTransitionWidget(
                index: 1,
                child: BouncingButton(
                  scaleFactor: 0.97,
                  onTap: () => _showInviteShareDialog(context),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Responsive.w(24)),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFB74D), // Light gold
                          Color(0xFFE65100), // Dark orange
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE65100).withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(Responsive.w(16)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(3)),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(Responsive.w(8)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.currency_rupee_rounded, color: Colors.white, size: Responsive.w(14)),
                                        SizedBox(width: Responsive.w(4)),
                                        CustomText.title('$coinsBalance Coins', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.h(6)),
                              CustomText.title(
                                'Invite a friend & get\n100 coins',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.25,
                              ),
                              SizedBox(height: Responsive.h(10)),
                              Container(
                                height: Responsive.h(32),
                                width: Responsive.w(120),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(Responsive.w(16)),
                                ),
                                child: Center(
                                  child: CustomText.title(
                                    'Share invite',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFE65100),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spinning3DCoin(
                          size: Responsive.w(86),
                          onTap: () => _showInviteShareDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(24)),

              // 3. Transactions List Header (View All)
              FadeSlideTransitionWidget(
                index: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: CustomText.header(
                        'Transactions',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: Responsive.w(8)),
                    BouncingButton(
                      scaleFactor: 0.92,
                      onTap: () {
                        Navigator.of(context).pushNamed(RouteConstants.allTransactions);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(14),
                          vertical: Responsive.h(6),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                          border: Border.all(
                            color: AppColors.primary,
                            width: Responsive.w(1.2),
                          ),
                        ),
                        child: CustomText.title(
                          'View All',
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.h(16)),

              // 4. Dynamic Recent Transactions List
              if (transactions.isEmpty)
                FadeSlideTransitionWidget(
                  index: 3,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.h(28),
                      horizontal: Responsive.w(24),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(Responsive.w(20)),
                      border: Border.all(color: AppColors.outliner.withValues(alpha: 0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: Responsive.w(52),
                          height: Responsive.w(52),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: Responsive.w(26),
                            color: AppColors.grayFont.withValues(alpha: 0.6),
                          ),
                        ),
                        SizedBox(height: Responsive.h(10)),
                        CustomText.title(
                          'No Transactions Yet',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        SizedBox(height: Responsive.h(4)),
                        CustomText.subtitle(
                          'Earn coins by reporting issues or redeeming rewards!',
                          textAlign: TextAlign.center,
                          fontSize: 12,
                          color: AppColors.grayFont,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...transactions.take(4).toList().asMap().entries.map((entry) {
                  final int idx = entry.key;
                  final tx = entry.value;
                  final String title = tx['title']?.toString() ?? 'Transaction';
                  final String subtitle = tx['subtitle']?.toString() ?? 'Recent';
                  final String amount = tx['amount']?.toString() ?? '₹0';
                  final bool isPositive = tx['isPositive'] as bool? ?? false;

                  return FadeSlideTransitionWidget(
                    index: 3 + idx,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: Responsive.h(12)),
                      child: _buildQuickTransactionRow(
                        context,
                        title,
                        subtitle,
                        amount,
                        isPositive,
                        transaction: tx,
                      ),
                    ),
                  );
                }),
              SizedBox(height: Responsive.h(30)),
            ],
          ),
        ),
      );
    },
    );
  }

  Widget _buildQuickTransactionRow(
    BuildContext context,
    String title,
    String subtitle,
    String amount,
    bool isPositive, {
    Map<String, dynamic>? transaction,
  }) {
    return BouncingButton(
      scaleFactor: 0.98,
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteConstants.transactionDetails,
          arguments: {
            'title': title,
            'transaction': transaction,
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
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
                          title,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: Responsive.h(4)),
                        CustomText.subtitle(
                          subtitle,
                          fontSize: 11,
                          color: AppColors.grayFont,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            CustomText.title(
              amount,
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
