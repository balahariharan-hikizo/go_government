import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../../utils/responsive.dart';
import '../common/dashboard_ui_helpers.dart';
import 'store_detail_dialog.dart';

class StoresTabView extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onStatsUpdated;

  const StoresTabView({
    super.key,
    this.onStatsUpdated,
  });

  @override
  State<StoresTabView> createState() => StoresTabViewState();
}

class StoresTabViewState extends State<StoresTabView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stores = [];
  Map<String, dynamic> _stats = {'total': 0, 'pending': 0, 'approved': 0, 'rejected': 0};
  String _selectedTab = 'pending';
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
    final res = await AdminApiService.getAllStores();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true && res['data'] != null) {
      final data = res['data'];
      setState(() {
        _stores = List<Map<String, dynamic>>.from(data['stores'] ?? []);
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
      });
      widget.onStatsUpdated?.call(_stats);
    }
  }

  List<Map<String, dynamic>> get _filteredStores {
    return _stores.where((s) {
      if (_selectedTab != 'all' && s['status'] != _selectedTab) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
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

  Future<void> _quickApproveStore(Map<String, dynamic> store) async {
    final res = await AdminApiService.updateStoreStatus(
      storeId: store['storeId'],
      status: 'approved',
    );

    if (res['success'] == true) {
      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Approved "${store['name']}"! It is now live in the User App.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  void _openDetail(Map<String, dynamic> store) {
    showDialog(
      context: context,
      builder: (_) => StoreDetailDialog(
        store: store,
        onActionCompleted: reload,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildStatsRow() {
    return buildResponsiveKpiGrid([
      buildKpiCard(
        title: 'Pending Verification',
        count: '${_stats['pending'] ?? 0}',
        subtitle: 'Stores awaiting review',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        isAlert: (_stats['pending'] ?? 0) > 0,
      ),
      buildKpiCard(
        title: 'Approved Outlets',
        count: '${_stats['approved'] ?? 0}',
        subtitle: 'Live on citizen app',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
      ),
      buildKpiCard(
        title: 'Rejected Applications',
        count: '${_stats['rejected'] ?? 0}',
        subtitle: 'Returned for corrections',
        icon: Icons.highlight_off_rounded,
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
      ),
      buildKpiCard(
        title: 'Total Applications',
        count: '${_stats['total'] ?? 0}',
        subtitle: 'All-time registrations',
        icon: Icons.storefront_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
    ]);
  }

  Widget _buildFilterBar() {
    final tabs = [
      buildFilterTab(
        label: 'Pending Verification',
        tabKey: 'pending',
        badgeCount: _stats['pending'] ?? 0,
        activeColor: const Color(0xFFD97706),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'pending'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'Approved Stores',
        tabKey: 'approved',
        badgeCount: _stats['approved'] ?? 0,
        activeColor: const Color(0xFF16A34A),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'approved'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'Rejected',
        tabKey: 'rejected',
        badgeCount: _stats['rejected'] ?? 0,
        activeColor: const Color(0xFFDC2626),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'rejected'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'All Registrations',
        tabKey: 'all',
        badgeCount: _stats['total'] ?? 0,
        activeColor: const Color(0xFF2563EB),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'all'),
      ),
    ];

    final searchField = SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
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

  Widget _buildTable() {
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
                0: FlexColumnWidth(2.5),
                1: FlexColumnWidth(1.8),
                2: FlexColumnWidth(2.0),
                3: FlexColumnWidth(2.5),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(2.2),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    tableHeader('STORE & CATEGORY'),
                    tableHeader('BANK ACCOUNT'),
                    tableHeader('MERCHANT CONTACT'),
                    tableHeader('LOCATION ADDRESS'),
                    tableHeader('STATUS'),
                    tableHeader('ACTIONS'),
                  ],
                ),
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
                        child: _buildStatusBadge(store['status'] ?? 'pending'),
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
                              onPressed: () => _openDetail(store),
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
              ] else if (_filteredStores.isEmpty) ...[
                buildEmptyState('stores', _selectedTab),
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
