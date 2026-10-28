import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../bloc/feedback/feedback_bloc.dart';
import '../../../bloc/feedback/feedback_event.dart';
import '../../../bloc/feedback/feedback_state.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../bloc/transaction/transaction_event.dart';
import '../../../hive/hive_service.dart';
import '../../../network/feedback_api_service.dart';

class FeedbackSurveyScreen extends StatefulWidget {
  const FeedbackSurveyScreen({super.key});

  @override
  State<FeedbackSurveyScreen> createState() => _FeedbackSurveyScreenState();
}

class _FeedbackSurveyScreenState extends State<FeedbackSurveyScreen> {
  final List<Map<String, dynamic>> _surveyData = [
    {
      'question': '1. How would you rate the road condition near your home?',
      'options': ['Excellent', 'Good', 'Poor', 'Very Poor'],
    },
    {
      'question': '2. How often is garbage collected in your area?',
      'options': ['Daily', 'Alternate Days', 'Weekly', 'Rarely'],
    },
    {
      'question': '3. Are streetlights working properly in your locality?',
      'options': ['All Working', 'Most Working', 'Few Working', 'Not Working'],
    },
    {
      'question': '4. How clean are the streets near your home?',
      'options': ['Very Clean', 'Clean', 'Average', 'Dirty'],
    },
  ];

  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

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
          'Feedback Survey',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: false,
      ),
      body: BlocBuilder<FeedbackBloc, FeedbackState>(
        builder: (context, state) {
          final int q1Selected = state.q1Selected;
          final int q2Selected = state.q2Selected;
          final int q3Selected = state.q3Selected;
          final int q4Selected = state.q4Selected;

          int getSelectedOption(int questionIndex) {
            if (questionIndex == 0) return q1Selected;
            if (questionIndex == 1) return q2Selected;
            if (questionIndex == 2) return q3Selected;
            if (questionIndex == 3) return q4Selected;
            return -1;
          }

          return CommonBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.fromLTRB(
                        Responsive.w(16),
                        Responsive.h(8),
                        Responsive.w(16),
                        Responsive.h(16),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(24)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Responsive.w(24)),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(18),
                            vertical: Responsive.h(18),
                          ),
                          itemCount: _surveyData.length + 2, // Add 2 for Remarks box and Submit button
                          itemBuilder: (context, index) {
                            if (index == _surveyData.length) {
                              return _buildRemarksBox();
                            }
                            if (index == _surveyData.length + 1) {
                              return _buildSubmitButton(context, q1Selected, q2Selected, q3Selected, q4Selected);
                            }

                            final questionItem = _surveyData[index];
                            final String questionText = questionItem['question'];
                            final List<String> options = questionItem['options'];
                            final int selectedIndex = getSelectedOption(index);

                            return Padding(
                              padding: EdgeInsets.only(bottom: Responsive.h(24)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText.title(
                                    questionText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.black,
                                    height: 1.35,
                                  ),
                                  SizedBox(height: Responsive.h(14)),
                                  Column(
                                    children: List.generate(options.length, (optIdx) {
                                      final bool isSelected = selectedIndex == optIdx;
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          context.read<FeedbackBloc>().add(
                                                SelectOptionEvent(index, optIdx),
                                              );
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.only(bottom: Responsive.h(12)),
                                          child: Row(
                                            children: [
                                              // Custom radio selector indicator
                                              Container(
                                                width: Responsive.w(18),
                                                height: Responsive.w(18),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : const Color(0xFFF5F5F5),
                                                ),
                                              ),
                                              SizedBox(width: Responsive.w(12)),
                                              Expanded(
                                                child: CustomText.body(
                                                  options[optIdx],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRemarksBox() {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.title(
            '5. Additional Remarks or Area Issues (Optional)',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
            height: 1.35,
          ),
          SizedBox(height: Responsive.h(10)),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(Responsive.w(14)),
              border: Border.all(color: AppColors.outliner, width: 1.2),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(14),
              vertical: Responsive.h(8),
            ),
            child: TextField(
              controller: _remarksController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, color: AppColors.black),
              decoration: const InputDecoration(
                hintText: 'Share any specific civic problem or suggestions for your ward...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, int q1, int q2, int q3, int q4) {
    return Padding(
      padding: EdgeInsets.only(top: Responsive.h(6), bottom: Responsive.h(20)),
      child: GestureDetector(
        onTap: _isSubmitting
            ? null
            : () async {
                if (q1 == -1 || q2 == -1 || q3 == -1 || q4 == -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please answer all 4 survey questions before submitting.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                      ),
                    ),
                  );
                  return;
                }

                setState(() => _isSubmitting = true);

                final answers = <Map<String, String>>[
                  {
                    'question': _surveyData[0]['question'] as String,
                    'answer': (_surveyData[0]['options'] as List<String>)[q1],
                  },
                  {
                    'question': _surveyData[1]['question'] as String,
                    'answer': (_surveyData[1]['options'] as List<String>)[q2],
                  },
                  {
                    'question': _surveyData[2]['question'] as String,
                    'answer': (_surveyData[2]['options'] as List<String>)[q3],
                  },
                  {
                    'question': _surveyData[3]['question'] as String,
                    'answer': (_surveyData[3]['options'] as List<String>)[q4],
                  },
                ];

                // Calculate satisfaction score (5.0 down to 2.0 based on positive choices)
                double score = 5.0;
                final negativePoints = (q1 > 1 ? 0.75 : 0.0) +
                    (q2 > 1 ? 0.75 : 0.0) +
                    (q3 > 1 ? 0.75 : 0.0) +
                    (q4 > 1 ? 0.75 : 0.0);
                score = (score - negativePoints).clamp(2.0, 5.0);

                await FeedbackApiService.submitFeedback(
                  userId: HiveService.userId,
                  userName: HiveService.userName.isNotEmpty ? HiveService.userName : 'Citizen',
                  phone: HiveService.userPhone,
                  type: 'survey',
                  rating: double.parse(score.toStringAsFixed(1)),
                  comments: _remarksController.text.trim(),
                  surveyAnswers: answers,
                );

                if (!context.mounted) return;

                // Reward citizen feedback bonus
                final rewardTx = {
                  'id': 'REW-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                  'title': 'Feedback Survey Reward',
                  'subtitle': 'Earned through survey · ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  'amount': '+50',
                  'isPositive': true,
                  'status': 'Credited',
                  'date': 'Today',
                  'items': [],
                  'address': 'Citizen Participation Survey',
                  'listingPrice': '₹0.00',
                  'sellingPrice': '₹50.00',
                  'grandTotal': '₹50.00',
                  'paid': '₹50.00',
                };
                context.read<TransactionBloc>().add(AddCoinsEvent(50));
                context.read<TransactionBloc>().add(AddTransactionEvent(rewardTx));

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Feedback submitted & 50 Coins Earned!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Responsive.w(12)),
                    ),
                  ),
                );
                context.read<FeedbackBloc>().add(SubmitFeedbackEvent());
                Navigator.pop(context);
              },
        child: Container(
          width: double.infinity,
          height: Responsive.h(50),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(Responsive.w(25)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : CustomText.title(
                    'Submit Feedback',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
          ),
        ),
      ),
    );
  }
}
