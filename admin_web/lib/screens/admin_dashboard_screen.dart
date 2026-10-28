import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';
import '../utils/responsive.dart';
import '../widgets/store_detail_dialog.dart';
import '../widgets/complaint_detail_dialog.dart';
import '../widgets/feedback_detail_dialog.dart';
import '../widgets/live_monitoring_view.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Navigation: 'complaints', 'stores', or 'feedback'
  String _activeSection = 'complaints';

  // Feedback State
  bool _isLoadingFeedback = true;
  List<Map<String, dynamic>> _feedbacks = [];
  Map<String, dynamic> _feedbackStats = {
    'total': 0,
    'avgRating': 5.0,
    'surveyCount': 0,
    'appRatingCount': 0,
    'ratingBreakdown': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
  };
  String _selectedFeedbackTab = 'all'; // 'all', 'survey', 'app_rating', '5', '4', '3', '1-2'
  String _feedbackSearchQuery = '';
  final TextEditingController _feedbackSearchController = TextEditingController();

  // Stores State
  bool _isLoadingStores = true;
  List<Map<String, dynamic>> _stores = [];
  Map<String, dynamic> _storeStats = {'total': 0, 'pending': 0, 'approved': 0, 'rejected': 0};
  String _selectedStoreTab = 'pending'; // 'pending', 'approved', 'rejected', 'all'
  String _storeSearchQuery = '';
  final TextEditingController _storeSearchController = TextEditingController();

  // Complaints State
  bool _isLoadingComplaints = true;
  List<Map<String, dynamic>> _complaints = [];
  Map<String, dynamic> _complaintStats = {'total': 0, 'underReview': 0, 'inProgress': 0, 'resolved': 0, 'rejected': 0};
  String _selectedComplaintTab = 'all'; // 'all', 'Under Review', 'In Progress', 'Resolved', 'Rejected'
  String _complaintSearchQuery = '';
  final TextEditingController _complaintSearchController = TextEditingController();

  final List<String> _statusOptions = [
    'Under Review',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadStores();
    _loadComplaints();
    _loadFeedback();
  }

  @override
  void dispose() {
    _storeSearchController.dispose();
    _complaintSearchController.dispose();
    _feedbackSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeedback() async {
    setState(() => _isLoadingFeedback = true);
    final statsRes = await AdminApiService.getFeedbackStats();
    final listRes = await AdminApiService.getAllFeedback();

    if (!mounted) return;
    setState(() => _isLoadingFeedback = false);

    if (statsRes['success'] == true && statsRes['stats'] != null) {
      setState(() {
        _feedbackStats = Map<String, dynamic>.from(statsRes['stats']);
      });
    }

    if (listRes['success'] == true && listRes['data'] != null) {
      final data = listRes['data'];
      setState(() {
        _feedbacks = List<Map<String, dynamic>>.from(data['feedbacks'] ?? []);
      });
    }
  }

  Future<void> _loadStores() async {
    setState(() => _isLoadingStores = true);
    final res = await AdminApiService.getAllStores();

    if (!mounted) return;
    setState(() => _isLoadingStores = false);

    if (res['success'] == true && res['data'] != null) {
      final data = res['data'];
      setState(() {
        _stores = List<Map<String, dynamic>>.from(data['stores'] ?? []);
        _storeStats = Map<String, dynamic>.from(data['stats'] ?? {});
      });
    }
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoadingComplaints = true);
    final compRes = await AdminApiService.getAllComplaints();
    final statsRes = await AdminApiService.getComplaintStats();

    if (!mounted) return;
    setState(() => _isLoadingComplaints = false);

    if (compRes['success'] == true && compRes['complaints'] != null) {
      setState(() {
        _complaints = List<Map<String, dynamic>>.from(compRes['complaints']);
      });
    }
    if (statsRes['success'] == true && statsRes['stats'] != null) {
      setState(() {
        _complaintStats = Map<String, dynamic>.from(statsRes['stats']);
      });
    }
  }

  Future<void> _updateComplaintStatus(String complaintId, String newStatus) async {
    final res = await AdminApiService.updateComplaintStatus(
      complaintId: complaintId,
      status: newStatus,
      updatedBy: 'Chief Municipal Officer',
    );

    if (res['success'] == true) {
      _loadComplaints();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Status for $complaintId updated to "$newStatus"'),
          backgroundColor: _getComplaintStatusColor(newStatus),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to update status: ${res['error']}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredStores {
    return _stores.where((s) {
      final status = s['status'] ?? 'pending';
      if (_selectedStoreTab != 'all' && status != _selectedStoreTab) return false;

      if (_storeSearchQuery.isNotEmpty) {
        final query = _storeSearchQuery.toLowerCase();
        final name = (s['name'] ?? '').toString().toLowerCase();
        final owner = (s['ownerName'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();
        final lic = (s['licenseNumber'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !owner.contains(query) && !phone.contains(query) && !lic.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredComplaints {
    return _complaints.where((c) {
      final status = (c['status'] ?? 'Under Review').toString();
      if (_selectedComplaintTab != 'all' &&
          status.toLowerCase() != _selectedComplaintTab.toLowerCase()) {
        return false;
      }

      if (_complaintSearchQuery.isNotEmpty) {
        final query = _complaintSearchQuery.toLowerCase();
        final id = (c['complaintId'] ?? c['id'] ?? '').toString().toLowerCase();
        final citizen = (c['userName'] ?? '').toString().toLowerCase();
        final category = (c['category'] ?? '').toString().toLowerCase();
        final address = (c['userAddress'] ?? '').toString().toLowerCase();
        final desc = (c['description'] ?? '').toString().toLowerCase();
        if (!id.contains(query) &&
            !citizen.contains(query) &&
            !category.contains(query) &&
            !address.contains(query) &&
            !desc.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredFeedback {
    return _feedbacks.where((fb) {
      if (_selectedFeedbackTab == 'survey' && fb['type'] != 'survey') return false;
      if (_selectedFeedbackTab == 'app_rating' && fb['type'] != 'app_rating') return false;
      final double r = double.tryParse(fb['rating']?.toString() ?? '5') ?? 5.0;
      if (_selectedFeedbackTab == '5' && r < 4.5) return false;
      if (_selectedFeedbackTab == '4' && (r < 3.5 || r >= 4.5)) return false;
      if (_selectedFeedbackTab == '3' && (r < 2.5 || r >= 3.5)) return false;
      if (_selectedFeedbackTab == '1-2' && r >= 2.5) return false;

      if (_feedbackSearchQuery.isNotEmpty) {
        final q = _feedbackSearchQuery.toLowerCase();
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

  void _openFeedbackDetail(Map<String, dynamic> feedback) {
    showDialog(
      context: context,
      builder: (_) => FeedbackDetailDialog(feedback: feedback),
    );
  }

  void _openStoreDetail(Map<String, dynamic> store) {
    showDialog(
      context: context,
      builder: (_) => StoreDetailDialog(
        store: store,
        onActionCompleted: _loadStores,
      ),
    );
  }

  void _openComplaintDetail(Map<String, dynamic> complaint) {
    showDialog(
      context: context,
      builder: (_) => ComplaintDetailDialog(
        complaint: complaint,
        onActionCompleted: _loadComplaints,
      ),
    );
  }

  Future<void> _quickApproveStore(Map<String, dynamic> store) async {
    final res = await AdminApiService.updateStoreStatus(
      storeId: store['storeId'],
      status: 'approved',
      verifiedBy: 'Chief Municipal Officer',
    );

    if (res['success'] == true) {
      _loadStores();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Approved "${store['name']}"! It is now live in the User App.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  Color _getComplaintStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF16A34A);
      case 'in progress':
        return const Color(0xFFD97706);
      case 'rejected':
        return const Color(0xFF64748B);
      case 'under review':
      default:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: isDesktop ? null : _buildMobileDrawer(),
      body: Column(
        children: [
          // Top Navigation Header
          _buildTopNavbar(),

          // Main Workspace
          Expanded(
            child: _activeSection == 'monitoring'
                ? const LiveMonitoringView()
                : SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14 : (context.isTablet ? 20 : 36),
                      vertical: isMobile ? 16 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // KPI Overview Cards
                  if (_activeSection == 'complaints')
                    _buildComplaintStatsRow()
                  else if (_activeSection == 'stores')
                    _buildStoreStatsRow()
                  else
                    _buildFeedbackStatsRow(),

                  const SizedBox(height: 28),

                  // Data Table Card
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
                        // Tabs & Search Bar Header
                        if (_activeSection == 'complaints')
                          _buildComplaintFilterBar()
                        else if (_activeSection == 'stores')
                          _buildStoreFilterBar()
                        else
                          _buildFeedbackFilterBar(),

                        const SizedBox(height: 20),

                        // Table Content
                        if (_activeSection == 'complaints') ...[
                          if (_isLoadingComplaints) ...[
                            const SizedBox(height: 80),
                            const Center(child: CircularProgressIndicator()),
                            const SizedBox(height: 80),
                          ] else if (_filteredComplaints.isEmpty) ...[
                            _buildEmptyState('complaints', _selectedComplaintTab),
                          ] else ...[
                            _buildComplaintsTable(),
                          ],
                        ] else if (_activeSection == 'stores') ...[
                          if (_isLoadingStores) ...[
                            const SizedBox(height: 80),
                            const Center(child: CircularProgressIndicator()),
                            const SizedBox(height: 80),
                          ] else if (_filteredStores.isEmpty) ...[
                            _buildEmptyState('stores', _selectedStoreTab),
                          ] else ...[
                            _buildStoreTable(),
                          ],
                        ] else ...[
                          if (_isLoadingFeedback) ...[
                            const SizedBox(height: 80),
                            const Center(child: CircularProgressIndicator()),
                            const SizedBox(height: 80),
                          ] else if (_filteredFeedback.isEmpty) ...[
                            _buildEmptyState('feedback', _selectedFeedbackTab),
                          ] else ...[
                            _buildFeedbackTable(),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavbar() {
    final isDesktop = context.isDesktop;
    final isMobile = context.isMobile;

    if (!isDesktop) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
        ),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Navigation Menu',
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMobile ? 'GoGov Admin' : 'GoGovernment Administration',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getSectionTitle(_activeSection),
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              tooltip: 'Refresh',
              onPressed: () {
                if (_activeSection == 'complaints') {
                  _loadComplaints();
                } else if (_activeSection == 'stores') {
                  _loadStores();
                } else {
                  _loadFeedback();
                }
              },
            ),
            const SizedBox(width: 4),
            const CircleAvatar(
              backgroundColor: Color(0xFF38BDF8),
              radius: 16,
              child: Text('AD', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    final screenW = context.screenWidth;
    final isCompactDesktop = screenW < 1350;

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: isCompactDesktop ? 18 : 36),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 24),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GoGovernment Portal',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Grievances, Stores & Dispatch',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Segmented Switcher between Complaints, Stores, Feedback & Monitoring
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSectionButton(
                      title: 'Citizen Complaints',
                      icon: Icons.campaign_rounded,
                      sectionKey: 'complaints',
                      count: _complaintStats['total'] ?? 0,
                    ),
                    const SizedBox(width: 4),
                    _buildSectionButton(
                      title: 'Store Approvals',
                      icon: Icons.storefront_rounded,
                      sectionKey: 'stores',
                      count: _storeStats['pending'] ?? 0,
                    ),
                    const SizedBox(width: 4),
                    _buildSectionButton(
                      title: 'Citizen Feedback',
                      icon: Icons.rate_review_rounded,
                      sectionKey: 'feedback',
                      count: _feedbackStats['total'] ?? 0,
                    ),
                    const SizedBox(width: 4),
                    _buildSectionButton(
                      title: 'Live Dispatch',
                      icon: Icons.radar_rounded,
                      sectionKey: 'monitoring',
                      count: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: () {
              if (_activeSection == 'complaints') {
                _loadComplaints();
              } else if (_activeSection == 'stores') {
                _loadStores();
              } else {
                _loadFeedback();
              }
            },
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            backgroundColor: Color(0xFF38BDF8),
            radius: 17,
            child: Text('AD', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          if (!isCompactDesktop) ...[
            const SizedBox(width: 10),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chief Officer', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('Municipal Corporation', style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GoGovernment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Chief Municipal Officer', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDrawerTile('Citizen Complaints', Icons.campaign_rounded, 'complaints', _complaintStats['total'] ?? 0),
            _buildDrawerTile('Store Approvals', Icons.storefront_rounded, 'stores', _storeStats['pending'] ?? 0),
            _buildDrawerTile('Citizen Feedback', Icons.rate_review_rounded, 'feedback', _feedbackStats['total'] ?? 0),
            _buildDrawerTile('Live Dispatch & Riders', Icons.radar_rounded, 'monitoring', 0),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Admin Portal Online\nMunicipal Operations Active', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(String title, IconData icon, String sectionKey, int count) {
    final isSelected = _activeSection == sectionKey;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF38BDF8) : Colors.grey.shade400, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade300,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      trailing: count > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            )
          : null,
      selected: isSelected,
      onTap: () {
        setState(() => _activeSection = sectionKey);
        Navigator.pop(context);
      },
    );
  }

  String _getSectionTitle(String key) {
    switch (key) {
      case 'stores':
        return 'Store Approvals';
      case 'feedback':
        return 'Citizen Feedback';
      case 'monitoring':
        return 'Live Dispatch & Logistics';
      case 'complaints':
      default:
        return 'Citizen Complaints';
    }
  }

  Widget _buildResponsiveKpiGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxW = constraints.maxWidth;
        if (maxW <= 0) return const SizedBox.shrink();

        int cols;
        if (maxW >= 1200) {
          cols = 4;
        } else if (maxW >= 650) {
          cols = 2;
        } else {
          cols = 1;
        }

        const double gap = 16.0;
        final double cardW = cols == 1
            ? maxW
            : ((maxW - ((cols - 1) * gap)) / cols).clamp(100.0, maxW);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildSectionButton({
    required String title,
    required IconData icon,
    required String sectionKey,
    required int count,
  }) {
    final isSelected = _activeSection == sectionKey;
    return InkWell(
      onTap: () => setState(() => _activeSection = sectionKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // COMPLAINTS SECTION
  // -------------------------------------------------------------

  Widget _buildComplaintStatsRow() {
    return _buildResponsiveKpiGrid([
      _buildKpiCard(
        title: 'Under Review',
        count: '${_complaintStats['underReview'] ?? 0}',
        subtitle: 'New grievances pending action',
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        isAlert: (_complaintStats['underReview'] ?? 0) > 0,
      ),
      _buildKpiCard(
        title: 'In Progress',
        count: '${_complaintStats['inProgress'] ?? 0}',
        subtitle: 'Department crews dispatched',
        icon: Icons.pending_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
      ),
      _buildKpiCard(
        title: 'Resolved',
        count: '${_complaintStats['resolved'] ?? 0}',
        subtitle: 'Fixed and closed grievances',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
      ),
      _buildKpiCard(
        title: 'Total Grievances',
        count: '${_complaintStats['total'] ?? 0}',
        subtitle: 'All-time citizen reports',
        icon: Icons.assignment_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
    ]);
  }

  Widget _buildComplaintFilterBar() {
    final tabs = [
      _buildFilterTab(
        label: 'All Grievances',
        tabKey: 'all',
        badgeCount: _complaintStats['total'] ?? 0,
        activeColor: const Color(0xFF2563EB),
        currentSelected: _selectedComplaintTab,
        onTap: () => setState(() => _selectedComplaintTab = 'all'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'Under Review',
        tabKey: 'Under Review',
        badgeCount: _complaintStats['underReview'] ?? 0,
        activeColor: const Color(0xFFDC2626),
        currentSelected: _selectedComplaintTab,
        onTap: () => setState(() => _selectedComplaintTab = 'Under Review'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'In Progress',
        tabKey: 'In Progress',
        badgeCount: _complaintStats['inProgress'] ?? 0,
        activeColor: const Color(0xFFD97706),
        currentSelected: _selectedComplaintTab,
        onTap: () => setState(() => _selectedComplaintTab = 'In Progress'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'Resolved',
        tabKey: 'Resolved',
        badgeCount: _complaintStats['resolved'] ?? 0,
        activeColor: const Color(0xFF16A34A),
        currentSelected: _selectedComplaintTab,
        onTap: () => setState(() => _selectedComplaintTab = 'Resolved'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'Rejected',
        tabKey: 'Rejected',
        badgeCount: _complaintStats['rejected'] ?? 0,
        activeColor: const Color(0xFF64748B),
        currentSelected: _selectedComplaintTab,
        onTap: () => setState(() => _selectedComplaintTab = 'Rejected'),
      ),
    ];

    final searchField = SizedBox(
      height: 42,
      child: TextField(
        controller: _complaintSearchController,
        onChanged: (v) => setState(() => _complaintSearchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: 'Search by ID, citizen, category, address...',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );

    if (context.isDesktop) {
      return Row(
        children: [
          ...tabs,
          const Spacer(),
          SizedBox(width: 320, child: searchField),
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

  Widget _buildComplaintsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 950),
            child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.8), // ID & Date
            1: FlexColumnWidth(1.8), // Citizen Info
            2: FlexColumnWidth(2.0), // Category & Description
            3: FlexColumnWidth(1.4), // Photo Evidence
            4: FlexColumnWidth(2.4), // Status Selection
            5: FlexColumnWidth(1.6), // Action
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Table Header
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              children: [
                _tableHeader('COMPLAINT ID & DATE'),
                _tableHeader('CITIZEN / USER'),
                _tableHeader('CATEGORY & DESCRIPTION'),
                _tableHeader('PHOTO EVIDENCE'),
                _tableHeader('STATUS SELECTION'),
                _tableHeader('ACTION'),
              ],
            ),
            // Table Rows
            ..._filteredComplaints.map((c) {
              final complaintId = c['complaintId'] ?? c['id'] ?? 'CMP';
              final citizen = c['userName'] ?? 'Citizen';
              final userId = c['userId'] ?? '';
              final category = c['category'] ?? 'General';
              final desc = c['description'] ?? '';
              final date = c['date'] ?? '';
              final status = (c['status'] ?? 'Under Review').toString();
              final rawImage = c['imagePath']?.toString();
              final imageUrl = AdminApiService.normalizeImageUrl(rawImage);
              final statusColor = _getComplaintStatusColor(status);

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                children: [
                  // Col 0: ID & Date
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            complaintId,
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),

                  // Col 1: Citizen
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            citizen.isNotEmpty ? citizen[0].toUpperCase() : 'C',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(citizen, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              if (userId.isNotEmpty)
                                Text(userId, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Col 2: Category & Description
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          desc.isNotEmpty ? desc : 'No description provided.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),

                  // Col 3: Photo Evidence Thumbnail
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: InkWell(
                      onTap: () => _openComplaintDetail(c),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (imageUrl.isNotEmpty && imageUrl.startsWith('http'))
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.image_outlined, color: Colors.grey, size: 24);
                                },
                              )
                            : const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 22),
                      ),
                    ),
                  ),

                  // Col 4: Status Selection Dropdown (Requested Feature!)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusOptions.firstWhere(
                            (opt) => opt.toLowerCase() == status.toLowerCase(),
                            orElse: () => 'Under Review',
                          ),
                          icon: Icon(Icons.arrow_drop_down_rounded, color: statusColor, size: 20),
                          isDense: true,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onChanged: (String? newStatus) {
                            if (newStatus != null && newStatus != status) {
                              _updateComplaintStatus(complaintId, newStatus);
                            }
                          },
                          items: _statusOptions.map<DropdownMenuItem<String>>((String val) {
                            final itemColor = _getComplaintStatusColor(val);
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: itemColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    val,
                                    style: TextStyle(
                                      color: itemColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // Col 5: Action Button
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openComplaintDetail(c),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    ),
  ),
);
}

  // -------------------------------------------------------------
  // STORES SECTION
  // -------------------------------------------------------------

  Widget _buildStoreStatsRow() {
    return _buildResponsiveKpiGrid([
      _buildKpiCard(
        title: 'Pending Verification',
        count: '${_storeStats['pending'] ?? 0}',
        subtitle: 'Stores awaiting review',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        isAlert: (_storeStats['pending'] ?? 0) > 0,
      ),
      _buildKpiCard(
        title: 'Approved Outlets',
        count: '${_storeStats['approved'] ?? 0}',
        subtitle: 'Live on citizen app',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
      ),
      _buildKpiCard(
        title: 'Rejected Applications',
        count: '${_storeStats['rejected'] ?? 0}',
        subtitle: 'Returned for corrections',
        icon: Icons.highlight_off_rounded,
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
      ),
      _buildKpiCard(
        title: 'Total Applications',
        count: '${_storeStats['total'] ?? 0}',
        subtitle: 'All-time registrations',
        icon: Icons.storefront_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
    ]);
  }

  Widget _buildStoreFilterBar() {
    final tabs = [
      _buildFilterTab(
        label: 'Pending Verification',
        tabKey: 'pending',
        badgeCount: _storeStats['pending'] ?? 0,
        activeColor: const Color(0xFFD97706),
        currentSelected: _selectedStoreTab,
        onTap: () => setState(() => _selectedStoreTab = 'pending'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'Approved Stores',
        tabKey: 'approved',
        badgeCount: _storeStats['approved'] ?? 0,
        activeColor: const Color(0xFF16A34A),
        currentSelected: _selectedStoreTab,
        onTap: () => setState(() => _selectedStoreTab = 'approved'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'Rejected',
        tabKey: 'rejected',
        badgeCount: _storeStats['rejected'] ?? 0,
        activeColor: const Color(0xFFDC2626),
        currentSelected: _selectedStoreTab,
        onTap: () => setState(() => _selectedStoreTab = 'rejected'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'All Registrations',
        tabKey: 'all',
        badgeCount: _storeStats['total'] ?? 0,
        activeColor: const Color(0xFF2563EB),
        currentSelected: _selectedStoreTab,
        onTap: () => setState(() => _selectedStoreTab = 'all'),
      ),
    ];

    final searchField = SizedBox(
      height: 42,
      child: TextField(
        controller: _storeSearchController,
        onChanged: (v) => setState(() => _storeSearchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: 'Search by name, license...',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );

    if (context.isDesktop) {
      return Row(
        children: [
          ...tabs,
          const Spacer(),
          SizedBox(width: 280, child: searchField),
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

  Widget _buildStoreTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 950),
            child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5), // Store & Category
            1: FlexColumnWidth(1.8), // Bank Info
            2: FlexColumnWidth(2.0), // Owner & Phone
            3: FlexColumnWidth(2.5), // Address
            4: FlexColumnWidth(1.5), // Status
            5: FlexColumnWidth(2.2), // Actions
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Table Header
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              children: [
                _tableHeader('STORE & CATEGORY'),
                _tableHeader('BANK ACCOUNT'),
                _tableHeader('MERCHANT CONTACT'),
                _tableHeader('LOCATION ADDRESS'),
                _tableHeader('STATUS'),
                _tableHeader('ACTIONS'),
              ],
            ),
            // Table Rows
            ..._filteredStores.map((store) {
              final bank = store['bankDetails'] ?? {};
              final bankName = bank['bankName'] ?? '';
              final accNo = bank['accountNumber'] ?? '';

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                children: [
                  // Store & Category
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            (store['category'] ?? 'GENERAL').toString().toUpperCase(),
                            style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bank Details
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bankName.isNotEmpty ? bankName : 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (accNo.isNotEmpty)
                          Text(accNo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  // Owner & Phone
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store['ownerName'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(store['phone'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  // Address
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      store['address'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
                  // Status
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: _buildStoreStatusBadge(store['status'] ?? 'pending'),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: Color(0xFF0D47A1)),
                          ),
                          onPressed: () => _openStoreDetail(store),
                          child: const Text('Review', style: TextStyle(fontSize: 12, color: Color(0xFF0D47A1))),
                        ),
                        if (store['status'] == 'pending') ...[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              elevation: 0,
                            ),
                            onPressed: () => _quickApproveStore(store),
                            child: const Text('Approve', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    ),
  ),
);
}

  // -------------------------------------------------------------
  // REUSABLE UI HELPERS
  // -------------------------------------------------------------

  Widget _buildKpiCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isAlert ? color : const Color(0xFFE2E8F0), width: isAlert ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  count,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required String tabKey,
    required int badgeCount,
    required Color activeColor,
    required String currentSelected,
    required VoidCallback onTap,
  }) {
    final isSelected = currentSelected == tabKey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? activeColor : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmptyState(String type, String selectedTab) {
    String title = 'No records found in "$selectedTab" category';
    if (type == 'complaints') {
      title = 'No grievances found in "$selectedTab" category';
    } else if (type == 'stores') {
      title = 'No stores found in "$selectedTab" queue';
    } else if (type == 'feedback') {
      title = 'No citizen feedback found in "$selectedTab" filter';
    }

    return Padding(
      padding: const EdgeInsets.all(60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Text(
              'All citizen records in this category have been processed.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    if (status == 'approved') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'APPROVED';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      label = 'REJECTED';
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // -------------------------------------------------------------
  // FEEDBACK SECTION
  // -------------------------------------------------------------

  Widget _buildFeedbackStatsRow() {
    return _buildResponsiveKpiGrid([
      _buildKpiCard(
        title: 'Total Submissions',
        count: '${_feedbackStats['total'] ?? 0}',
        subtitle: 'All-time citizen feedback',
        icon: Icons.rate_review_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
      _buildKpiCard(
        title: 'Satisfaction Score',
        count: '${_feedbackStats['avgRating'] ?? 5.0} ★',
        subtitle: 'Average citizen rating',
        icon: Icons.star_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
      ),
      _buildKpiCard(
        title: 'Civic Surveys',
        count: '${_feedbackStats['surveyCount'] ?? 0}',
        subtitle: '4-point locality surveys',
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
      ),
      _buildKpiCard(
        title: 'App Reviews',
        count: '${_feedbackStats['appRatingCount'] ?? 0}',
        subtitle: 'Ratings & suggestions',
        icon: Icons.thumb_up_rounded,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
      ),
    ]);
  }

  Widget _buildFeedbackFilterBar() {
    final breakdown = _feedbackStats['ratingBreakdown'] as Map<String, dynamic>? ?? {};
    final int star5 = int.tryParse(breakdown['5']?.toString() ?? '0') ?? 0;
    final int star4 = int.tryParse(breakdown['4']?.toString() ?? '0') ?? 0;
    final int star3 = int.tryParse(breakdown['3']?.toString() ?? '0') ?? 0;
    final int star12 = (int.tryParse(breakdown['2']?.toString() ?? '0') ?? 0) + (int.tryParse(breakdown['1']?.toString() ?? '0') ?? 0);

    final tabs = [
      _buildFilterTab(
        label: 'All Feedback',
        tabKey: 'all',
        badgeCount: _feedbackStats['total'] ?? 0,
        activeColor: const Color(0xFF2563EB),
        currentSelected: _selectedFeedbackTab,
        onTap: () => setState(() => _selectedFeedbackTab = 'all'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'Surveys',
        tabKey: 'survey',
        badgeCount: _feedbackStats['surveyCount'] ?? 0,
        activeColor: const Color(0xFF16A34A),
        currentSelected: _selectedFeedbackTab,
        onTap: () => setState(() => _selectedFeedbackTab = 'survey'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: 'App Reviews',
        tabKey: 'app_rating',
        badgeCount: _feedbackStats['appRatingCount'] ?? 0,
        activeColor: const Color(0xFF0284C7),
        currentSelected: _selectedFeedbackTab,
        onTap: () => setState(() => _selectedFeedbackTab = 'app_rating'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: '5 Stars ★',
        tabKey: '5',
        badgeCount: star5,
        activeColor: const Color(0xFF16A34A),
        currentSelected: _selectedFeedbackTab,
        onTap: () => setState(() => _selectedFeedbackTab = '5'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: '4 Stars ★',
        tabKey: '4',
        badgeCount: star4,
        activeColor: const Color(0xFF0284C7),
        currentSelected: _selectedFeedbackTab,
        onTap: () => setState(() => _selectedFeedbackTab = '4'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: '3 Stars ★',
        tabKey: '3',
        badgeCount: star3,
        activeColor: const Color(0xFFD97706),
        currentSelected: _selectedFeedbackTab,
        onTap: () => setState(() => _selectedFeedbackTab = '3'),
      ),
      const SizedBox(width: 8),
      _buildFilterTab(
        label: '1-2 Stars ★',
        tabKey: '1-2',
        badgeCount: star12,
        activeColor: const Color(0xFFDC2626),
        currentSelected: _selectedFeedbackTab,
        onTap: () => setState(() => _selectedFeedbackTab = '1-2'),
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
        controller: _feedbackSearchController,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Search citizen, phone, remarks...',
          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (val) => setState(() => _feedbackSearchQuery = val),
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

  Widget _buildFeedbackTable() {
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
          0: FixedColumnWidth(160), // ID & Date
          1: FlexColumnWidth(1.4),  // Citizen Profile
          2: FixedColumnWidth(140), // Feedback Type
          3: FixedColumnWidth(130), // Rating
          4: FlexColumnWidth(2.0),  // Remarks / Answers
          5: FixedColumnWidth(120), // Action
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Table Header
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [
              _tableHeader('ID & DATE'),
              _tableHeader('CITIZEN INFO'),
              _tableHeader('FEEDBACK TYPE'),
              _tableHeader('RATING'),
              _tableHeader('REMARKS / ANSWERS'),
              _tableHeader('ACTION'),
            ],
          ),

          // Table Rows
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
                    onPressed: () => _openFeedbackDetail(fb),
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
}
