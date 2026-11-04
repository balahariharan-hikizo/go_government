import 'package:flutter/material.dart';

class FeedbackDetailDialog extends StatelessWidget {
  final Map<String, dynamic> feedback;

  const FeedbackDetailDialog({
    super.key,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final String feedbackId = feedback['feedbackId']?.toString() ?? 'FB-000000';
    final String userName = feedback['userName']?.toString() ?? 'Anonymous Citizen';
    final String phone = feedback['phone']?.toString() ?? 'N/A';
    final String type = feedback['type']?.toString() ?? 'survey';
    final double rating = double.tryParse(feedback['rating']?.toString() ?? '5') ?? 5.0;
    final String comments = feedback['comments']?.toString() ?? '';
    final String createdAt = feedback['createdAt']?.toString() ?? '';
    final List<dynamic> surveyAnswers = feedback['surveyAnswers'] as List<dynamic>? ?? [];

    String formattedDate = 'Recent';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedDate = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    final bool isSurvey = type == 'survey';

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isMobile = screenW < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: isMobile ? 16 : 30),
      child: Container(
        width: isMobile ? screenW * 0.95 : 720,
        constraints: BoxConstraints(maxHeight: screenH * 0.9, maxWidth: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSurvey ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSurvey ? Icons.assignment_rounded : Icons.star_rounded,
                      color: isSurvey ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              isSurvey ? 'Civic Survey Feedback' : 'Citizen App Review',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 15 : 18,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Text(
                                feedbackId,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submitted on $formattedDate',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    hoverColor: Colors.white10,
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Citizen Info & Score Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone.isNotEmpty ? phone : 'Phone Not Linked',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Rating Stars
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
                                const SizedBox(width: 6),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Text(
                                  ' / 5.0',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Survey Questions & Answers
                    if (surveyAnswers.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.quiz_rounded, size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          const Text(
                            'Civic Assessment Responses',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${surveyAnswers.length} Questions',
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: surveyAnswers.map((item) {
                          final q = item['question']?.toString() ?? '';
                          final a = item['answer']?.toString() ?? '';

                          Color badgeBg = const Color(0xFFF1F5F9);
                          Color badgeText = const Color(0xFF334155);
                          final lowerA = a.toLowerCase();

                          if (lowerA.contains('excellent') || lowerA.contains('daily') || lowerA.contains('all working') || lowerA.contains('very clean')) {
                            badgeBg = const Color(0xFFDCFCE7);
                            badgeText = const Color(0xFF166534);
                          } else if (lowerA.contains('good') || lowerA.contains('alternate') || lowerA.contains('most working') || lowerA.contains('clean')) {
                            badgeBg = const Color(0xFFE0F2FE);
                            badgeText = const Color(0xFF0369A1);
                          } else if (lowerA.contains('poor') || lowerA.contains('weekly') || lowerA.contains('few working') || lowerA.contains('average')) {
                            badgeBg = const Color(0xFFFEF3C7);
                            badgeText = const Color(0xFFB45309);
                          } else if (lowerA.contains('very poor') || lowerA.contains('rarely') || lowerA.contains('not working') || lowerA.contains('dirty')) {
                            badgeBg = const Color(0xFFFEE2E2);
                            badgeText = const Color(0xFF991B1B);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    q,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    a,
                                    style: TextStyle(
                                      color: badgeText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 4. Remarks & Comments
                    Row(
                      children: [
                        const Icon(Icons.comment_rounded, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        const Text(
                          'Citizen Remarks & Observations',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: comments.isNotEmpty ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        comments.isNotEmpty ? comments : 'No additional remarks provided by the citizen.',
                        style: TextStyle(
                          fontSize: 13,
                          color: comments.isNotEmpty ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                          fontStyle: comments.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
