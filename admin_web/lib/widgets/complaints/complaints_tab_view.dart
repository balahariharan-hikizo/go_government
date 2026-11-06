import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../../utils/responsive.dart';
import '../common/dashboard_ui_helpers.dart';
import 'complaint_detail_dialog.dart';

class ComplaintsTabView extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onStatsUpdated;
  final void Function(Map<String, dynamic> complaint)? onViewOnMap;

  const ComplaintsTabView({
    super.key,
    this.onStatsUpdated,
    this.onViewOnMap,
  });

  @override
  State<ComplaintsTabView> createState() => ComplaintsTabViewState();
}

class ComplaintsTabViewState extends State<ComplaintsTabView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _complaints = [];
  Map<String, dynamic> _stats = {
    'total': 0,
    'underReview': 0,
    'inProgress': 0,
    'resolved': 0,
    'rejected': 0,
  };

  String _selectedTab = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _statusOptions = [
    'Under Review',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

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
    final compRes = await AdminApiService.getAllComplaints();
    final statsRes = await AdminApiService.getComplaintStats();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (compRes['success'] == true && compRes['complaints'] != null) {
      setState(() {
        _complaints = List<Map<String, dynamic>>.from(compRes['complaints']);
      });
    }
    if (statsRes['success'] == true && statsRes['stats'] != null) {
      setState(() {
        _stats = Map<String, dynamic>.from(statsRes['stats']);
      });
      widget.onStatsUpdated?.call(_stats);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'under review':
        return const Color(0xFFDC2626);
      case 'in progress':
        return const Color(0xFFD97706);
      case 'resolved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF2563EB);
    }
  }

  List<Map<String, dynamic>> get _filteredComplaints {
    return _complaints.where((c) {
      final status = (c['status'] ?? 'Under Review').toString();
      if (_selectedTab != 'all' && status.toLowerCase() != _selectedTab.toLowerCase()) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
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

  Future<void> _updateStatus(String complaintId, String newStatus) async {
    final res = await AdminApiService.updateComplaintStatus(
      complaintId: complaintId,
      status: newStatus,
    );

    if (res['success'] == true) {
      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Status for $complaintId updated to "$newStatus"'),
          backgroundColor: _getStatusColor(newStatus),
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

  void _openDetail(Map<String, dynamic> complaint) {
    showDialog(
      context: context,
      builder: (_) => ComplaintDetailDialog(
        complaint: complaint,
        onActionCompleted: reload,
        onViewOnMap: widget.onViewOnMap != null ? () => widget.onViewOnMap!(complaint) : null,
      ),
    );
  }

  Widget _buildStatsRow() {
    return buildResponsiveKpiGrid([
      buildKpiCard(
        title: 'Under Review',
        count: '${_stats['underReview'] ?? 0}',
        subtitle: 'New grievances pending action',
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        isAlert: (_stats['underReview'] ?? 0) > 0,
      ),
      buildKpiCard(
        title: 'In Progress',
        count: '${_stats['inProgress'] ?? 0}',
        subtitle: 'Department crews dispatched',
        icon: Icons.pending_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
      ),
      buildKpiCard(
        title: 'Resolved',
        count: '${_stats['resolved'] ?? 0}',
        subtitle: 'Fixed and closed grievances',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
      ),
      buildKpiCard(
        title: 'Total Grievances',
        count: '${_stats['total'] ?? 0}',
        subtitle: 'All-time citizen reports',
        icon: Icons.assignment_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
    ]);
  }

  Widget _buildFilterBar() {
    final tabs = [
      buildFilterTab(
        label: 'All Grievances',
        tabKey: 'all',
        badgeCount: _stats['total'] ?? 0,
        activeColor: const Color(0xFF2563EB),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'all'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'Under Review',
        tabKey: 'Under Review',
        badgeCount: _stats['underReview'] ?? 0,
        activeColor: const Color(0xFFDC2626),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'Under Review'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'In Progress',
        tabKey: 'In Progress',
        badgeCount: _stats['inProgress'] ?? 0,
        activeColor: const Color(0xFFD97706),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'In Progress'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'Resolved',
        tabKey: 'Resolved',
        badgeCount: _stats['resolved'] ?? 0,
        activeColor: const Color(0xFF16A34A),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'Resolved'),
      ),
      const SizedBox(width: 8),
      buildFilterTab(
        label: 'Rejected',
        tabKey: 'Rejected',
        badgeCount: _stats['rejected'] ?? 0,
        activeColor: const Color(0xFF64748B),
        currentSelected: _selectedTab,
        onTap: () => setState(() => _selectedTab = 'Rejected'),
      ),
    ];

    final searchField = SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
            constraints: const BoxConstraints(minWidth: 1060),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.6),
                1: FlexColumnWidth(1.6),
                2: FlexColumnWidth(2.0),
                3: FlexColumnWidth(1.3),
                4: FlexColumnWidth(2.2),
                5: FlexColumnWidth(2.3),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    tableHeader('COMPLAINT ID & DATE'),
                    tableHeader('CITIZEN / USER'),
                    tableHeader('CATEGORY & DESCRIPTION'),
                    tableHeader('PHOTO EVIDENCE'),
                    tableHeader('STATUS SELECTION'),
                    tableHeader('ACTION'),
                  ],
                ),
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
                  final statusColor = _getStatusColor(status);

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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF354155),
                                ),
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
                          onTap: () => _openDetail(c),
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
                                      return const Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.image_outlined, color: Colors.grey, size: 24);
                                    },
                                  )
                                : const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 22),
                          ),
                        ),
                      ),

                      // Col 4: Status Selection Dropdown
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
                                  _updateStatus(complaintId, newStatus);
                                }
                              },
                              items: _statusOptions.map<DropdownMenuItem<String>>((String val) {
                                final itemColor = _getStatusColor(val);
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              label: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _openDetail(c),
                            ),
                            if (widget.onViewOnMap != null)
                              IconButton(
                                icon: const Icon(Icons.pin_drop_rounded, size: 18, color: Color(0xFF0284C7)),
                                tooltip: 'View on City Map 📍',
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => widget.onViewOnMap!(c),
                              ),
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
              ] else if (_filteredComplaints.isEmpty) ...[
                buildEmptyState('complaints', _selectedTab),
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

