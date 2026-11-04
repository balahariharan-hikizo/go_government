import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';
import '../utils/responsive.dart';
import '../widgets/navbar/dashboard_header.dart';
import '../widgets/complaints/complaints_tab_view.dart';
import '../widgets/stores/stores_tab_view.dart';
import '../widgets/feedback/feedback_tab_view.dart';
import '../widgets/dispatch/dispatch_tab_view.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Navigation: 'complaints', 'stores', 'feedback', 'monitoring'
  String _activeSection = 'complaints';

  // Global Keys to trigger reloads from top navbar
  final GlobalKey<ComplaintsTabViewState> _complaintsKey = GlobalKey<ComplaintsTabViewState>();
  final GlobalKey<StoresTabViewState> _storesKey = GlobalKey<StoresTabViewState>();
  final GlobalKey<FeedbackTabViewState> _feedbackKey = GlobalKey<FeedbackTabViewState>();

  // Live badge counts
  int _complaintCount = 0;
  int _storePendingCount = 0;
  int _feedbackCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialBadgeCounts();
    AdminApiService.onUnauthorized = () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    };
  }

  Future<void> _fetchInitialBadgeCounts() async {
    try {
      final compStats = await AdminApiService.getComplaintStats();
      final storeRes = await AdminApiService.getAllStores();
      final fbStats = await AdminApiService.getFeedbackStats();

      if (!mounted) return;
      setState(() {
        if (compStats['success'] == true) {
          _complaintCount = compStats['stats']?['total'] ?? 0;
        }
        if (storeRes['success'] == true && storeRes['data'] != null) {
          _storePendingCount = storeRes['data']?['stats']?['pending'] ?? 0;
        }
        if (fbStats['success'] == true) {
          _feedbackCount = fbStats['stats']?['total'] ?? 0;
        }
      });
    } catch (e) {
      debugPrint('⚠️ [Dashboard] Error fetching initial badge counts: $e');
    }
  }

  void _handleRefresh() {
    if (_activeSection == 'complaints') {
      _complaintsKey.currentState?.reload();
    } else if (_activeSection == 'stores') {
      _storesKey.currentState?.reload();
    } else if (_activeSection == 'feedback') {
      _feedbackKey.currentState?.reload();
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text('Are you sure you want to end your administrative session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AdminApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildActiveTabContent() {
    switch (_activeSection) {
      case 'stores':
        return StoresTabView(
          key: _storesKey,
          onStatsUpdated: (stats) {
            if (mounted) setState(() => _storePendingCount = stats['pending'] ?? 0);
          },
        );
      case 'feedback':
        return FeedbackTabView(
          key: _feedbackKey,
          onStatsUpdated: (stats) {
            if (mounted) setState(() => _feedbackCount = stats['total'] ?? 0);
          },
        );
      case 'complaints':
      default:
        return ComplaintsTabView(
          key: _complaintsKey,
          onStatsUpdated: (stats) {
            if (mounted) setState(() => _complaintCount = stats['total'] ?? 0);
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: DashboardHeader.buildMobileDrawer(
        context,
        activeSection: _activeSection,
        onSectionChanged: (sec) => setState(() => _activeSection = sec),
        complaintCount: _complaintCount,
        storePendingCount: _storePendingCount,
        feedbackCount: _feedbackCount,
        onLogout: _confirmLogout,
      ),
      body: Column(
        children: [
          // 1. Top Navbar Header
          DashboardHeader(
            activeSection: _activeSection,
            onSectionChanged: (sec) => setState(() => _activeSection = sec),
            onRefresh: _handleRefresh,
            complaintCount: _complaintCount,
            storePendingCount: _storePendingCount,
            feedbackCount: _feedbackCount,
            onLogout: _confirmLogout,
          ),

          // 2. Main Workspace
          Expanded(
            child: _activeSection == 'monitoring'
                ? const DispatchTabView()
                : SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14 : (context.isTablet ? 20 : 36),
                      vertical: isMobile ? 16 : 24,
                    ),
                    child: _buildActiveTabContent(),
                  ),
          ),
        ],
      ),
    );
  }
}
