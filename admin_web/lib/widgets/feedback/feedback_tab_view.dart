import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../../utils/responsive.dart';
import '../common/dashboard_ui_helpers.dart';
import 'feedback_detail_dialog.dart';

class FeedbackTabView extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onStatsUpdated;

  const FeedbackTabView({
    super.key,
    this.onStatsUpdated,
  });

  @override
  State<FeedbackTabView> createState() => FeedbackTabViewState();
}

class FeedbackTabViewState extends State<FeedbackTabView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _feedbacks = [];
  Map<String, dynamic> _stats = {
    'total': 0,
    'avgRating': 5.0,
    'surveyCount': 0,
    'appRatingCount': 0,
    'ratingBreakdown': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
  };

  String _selectedTab = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() => _isLoading = true);
    final fbRes = await AdminApiService.getAllFeedback();
    final statsRes = await AdminApiService.getFeedbackStats();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (fbRes['success'] == true && fbRes['feedbacks'] != null) {
      setState(() {
        _feedbacks = List<Map<String, dynamic>>.from(fbRes['feedbacks']);
      });
    }
    if (statsRes['success'] == true && statsRes['stats'] != null) {
      setState(() {
        _stats = Map<String, dynamic>.from(statsRes['stats']);
      });
      widget.onStatsUpdated?.call(_stats);
    }
  }

  List<Map<String, dynamic>> get _filteredFeedback {
    return _feedbacks.where((fb) {
      if (_selectedTab == 'survey' && fb['type'] != 'survey') return false;
      if (_selectedTab == 'app_rating' && fb['type'] != 'app_rating') return false;
      final double r = double.tryParse(fb['rating']?.toString() ?? '5') ?? 5.0;
      if (_selectedTab == '5' && r < 4.5) return false;
      if (_selectedTab == '4' && (r < 3.5 || r >= 4.5)) return false;
      if (_selectedTab == '3' && (r < 2.5 || r >= 3.5)) return false;
      if (_selectedTab == '1-2' && r >= 2.5) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (fb['userName'] ?? '').toString().toLowerCase();
        final phone = (fb['phone'] ?? '').toString().toLowerCase();
        final comments = (fb['comments'] ?? '').toString().toLowerCase();
        final id = (fb['feedbackId'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !phone.contains(q) && !comments.contains(q) && !id.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openDetail(Map<String, dynamic> feedback) {
    showDialog(
      context: context,
      builder: (_) => FeedbackDetailDialog(feedback: feedback),
    );
  }

  Widget _buildStatsRow() {
    return buildResponsiveKpiGrid([
      buildKpiCard(
        title: 'Total Submissions',
        count: '${_stats['total'] ?? 0}',
        subtitle: 'All-time citizen feedback',
        icon: Icons.rate_review_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
      buildKpiCard(
        title: 'Satisfaction Score',
        count: '${_stats['avgRating'] ?? 5.0} ★',
        subtitle: 'Average citizen rating',
        icon: Icons.star_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
      ),
      buildKpiCard(
        title: 'Civic Surveys',
        count: '${_stats['surveyCount'] ?? 0}',
        subtitle: '4-point locality surveys',
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
      ),
      buildKpiCard(
        title: 'App Reviews',
        count: '${_stats['appRatingCount'] ?? 0}',
        subtitle: 'Ratings & suggestions',
        icon: Icons.thumb_up_rounded,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
      ),
    ]);
  }

  Widget _buildFilterBar() {
    final breakdown = _stats['ratingBreakdown'] as Map<String, dynamic>? ?? {};
    final int star5 = int.tryParse(breakdown['5']?.toString() ?? '0') ?? 0;
    final int star4 = int.tryParse(breakdown['4']?.toString() ?? '0') ?? 0;
    final int star3 = int.tryParse(breakdown['3']?.toString() ?? '0') ?? 0;
    final int star12 = (int.tryParse(breakdown['2']?.toString() ?? '0') ?? 0) + (int.tryParse(breakdown['1']?.toString() ?? '0') ?? 0);

    final tabs = [
      buildFilterTab(
        label: 'All Feedback',
        tabKey: 'all',
        badgeCount: _stats['total'] ?? 0,
        activeColor: const Color(0xFF2563EB),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'all'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'Surveys',
        tabKey: 'survey',
        badgeCount: _stats['surveyCount'] ?? 0,
        activeColor: const Color(0xFF16A34A),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'survey'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'App Reviews',
        tabKey: 'app_rating',
        badgeCount: _stats['appRatingCount'] ?? 0,
        activeColor: const Color(0xFF0284C7),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'app_rating'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: '5 Stars ★',
        tabKey: '5',
        badgeCount: star5,
        activeColor: const Color(0xFF16A34A),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = '5'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: '4 Stars ★',
        tabKey: '4',
        badgeCount: star4,
        activeColor: const Color(0xFF0284C7),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = '4'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: '3 Stars ★',
        tabKey: '3',
        badgeCount: star3,
        activeColor: const Color(0xFFD97706),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = '3'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: '1-2 Stars ★',
        tabKey: '1-2',
        badgeCount: star12,
        activeColor: const Color(0xFFDC2626),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = '1-2'),
      ),
    ];

    final searchField = Container(
      width: 260,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Search citizen, phone, remarks...',
          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
      ),
    );

    if (context.isDesktop) {
      return Row(
        children: [
          ...tabs,
          const Spacer(),
          searchField,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: tabs),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: searchField),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 900),
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(160),
              1: FlexColumnWidth(1.4),
              2: FixedColumnWidth(140),
              3: FixedColumnWidth(130),
              4: FlexColumnWidth(2.0),
              5: FixedColumnWidth(120),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                children: [
                  tableHeader('ID & DATE'),
                  tableHeader('CITIZEN INFO'),
                  tableHeader('FEEDBACK TYPE'),
                  tableHeader('RATING'),
                  tableHeader('REMARKS / ANSWERS'),
                  tableHeader('ACTION'),
                ],
              ),
              ..._filteredFeedback.map((fb) {
                final id = fb['feedbackId']?.toString() ?? 'FB-000';
                final name = fb['userName']?.toString() ?? 'Citizen';
                final phone = fb['phone']?.toString() ?? 'N/A';
                final type = fb['type']?.toString() ?? 'survey';
                final double rating = double.tryParse(fb['rating']?.toString() ?? '5') ?? 5.0;
                final comments = fb['comments']?.toString() ?? '';
                final answers = fb['surveyAnswers'] as List<dynamic>? ?? [];
                final createdAt = fb['createdAt']?.toString() ?? '';

                String formattedDate = 'Recent';
                if (createdAt.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(createdAt).toLocal();
                    formattedDate = '${dt.day}/${dt.month}/${dt.year}';
                  } catch (_) {
                    formattedDate = createdAt;
                  }
                }

                final isSurvey = type == 'survey';

                return TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  children: [
                    // Col 1: ID & Date
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            id,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),

                    // Col 2: Citizen
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'C',
                              style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                                ),
                                Text(
                                  phone.isNotEmpty ? phone : 'No phone linked',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Col 3: Type Badge
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSurvey ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isSurvey ? 'Civic Survey' : 'App Review',
                          style: TextStyle(
                            color: isSurvey ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Col 4: Rating
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          const Text(
                            ' / 5',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),

                    // Col 5: Remarks / Answers Summary
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (comments.isNotEmpty)
                            Text(
                              comments,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                            )
                          else if (isSurvey && answers.isNotEmpty)
                            Text(
                              '${answers.length} Assessment questions answered',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                            )
                          else
                            const Text(
                              'No comments provided',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                            ),
                        ],
                      ),
                    ),

                    // Col 6: Actions
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.visibility_rounded, size: 14),
                        label: const Text('View', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => _openDetail(fb),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsRow(),
        const SizedBox(height: 28),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterBar(),
              const SizedBox(height: 20),
              if (_isLoading) ...[
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 80),
              ] else if (_filteredFeedback.isEmpty) ...[
                buildEmptyState('feedback', _selectedTab),
              ] else ...[
                _buildTable(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
